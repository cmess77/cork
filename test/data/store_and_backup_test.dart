import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:cork/data/backup.dart';
import 'package:cork/data/journal_store.dart';
import 'package:cork/data/photos.dart';
import 'package:cork/data/settings_store.dart';
import 'package:cork/domain/ids.dart';
import 'package:cork/domain/journal.dart';
import 'package:cork/domain/tasting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/builders.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cork_data_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  JournalStore openStore([String name = 'journal.db']) => JournalStore.open(
    p.join(tmp.path, name),
    beforeUpgrade: (_, _) => fail('a fresh db needs no upgrade'),
  );

  group('JournalStore', () {
    test('commits survive a reopen', () {
      final w = indexWine(7);
      final t = tasting(w, tenths: 44, place: 'Bar Brutal');
      final store = openStore();
      store.commit([AdoptWine(w), SaveTasting(t)]);
      store.commit([
        Wishlist(WishlistItem(wineId: w.id, addedAt: DateTime.utc(2026))),
      ]);
      store.dispose();

      final again = openStore();
      expect(again.journal.tastings[t.id]!.score.tenths, 44);
      expect(again.journal.tastings[t.id]!.place, 'Bar Brutal');
      expect(again.journal.wishlist.containsKey(w.id), isTrue);
      again.commit([DeleteTasting(t.id), Unwishlist(w.id)]);
      again.dispose();

      final third = openStore();
      expect(third.journal.tastings, isEmpty);
      expect(third.journal.wishlist, isEmpty);
      expect(third.journal.wines, hasLength(1));
      third.dispose();
    });

    test('a rejected commit writes nothing and keeps the value', () {
      final store = openStore();
      final w = indexWine(1);
      store.commit([AdoptWine(w)]);
      final before = store.journal;
      expect(
        () => store.commit([
          SaveTasting(tasting(w)),
          SaveTasting(tasting(indexWine(2))),
        ]),
        throwsStateError,
      );
      expect(identical(store.journal, before), isTrue);
      store.dispose();
      final again = openStore();
      expect(again.journal.tastings, isEmpty);
      again.dispose();
    });

    test('commit notifies listeners once', () {
      final store = openStore();
      var calls = 0;
      store.addListener(() => calls++);
      store.commit([AdoptWine(indexWine(1))]);
      expect(calls, 1);
      store.dispose();
    });
  });

  group('PhotoStore', () {
    test('is content-addressed and sweeps unreferenced files', () async {
      final photos = PhotoStore(p.join(tmp.path, 'photos'));
      final a = await photos.add(Uint8List.fromList([1, 2, 3]));
      final again = await photos.add(Uint8List.fromList([1, 2, 3]));
      final b = await photos.add(Uint8List.fromList([4, 5, 6]));
      expect(again, a);
      expect(PhotoRef.tryParse(a.fileName), isNotNull);
      expect(Directory(photos.dir).listSync(), hasLength(2));

      final w = indexWine(1);
      final keep = Journal.empty.apply([
        AdoptWine(w),
        SaveTasting(
          Tasting(
            id: const TastingId('t'),
            wineId: w.id,
            tastedAt: DateTime.utc(2026),
            score: Score.fromTenths(30),
            photo: a,
          ),
        ),
      ]);
      expect(await photos.sweep(keep), 1);
      expect(photos.has(a), isTrue);
      expect(photos.has(b), isFalse);
    });
  });

  group('Backup', () {
    Future<(Backup, JournalStore, PhotoStore)> setUpJournal(String name) async {
      final store = openStore('$name.db');
      addTearDown(store.dispose);
      final photos = PhotoStore(p.join(tmp.path, '$name-photos'));
      final backup = Backup(
        store: store,
        photos: photos,
        exportsDir: p.join(tmp.path, '$name-exports'),
        appVersion: '1.0.0',
        now: () => DateTime(2026, 11, 15, 20, 30),
      );
      return (backup, store, photos);
    }

    test(
      'a .cork export restores wines, tastings, wishlist, and photos',
      () async {
        final (backup, store, photos) = await setUpJournal('a');
        final w = indexWine(3, name: 'Château "Test", Margaux');
        final photo = await photos.add(
          Uint8List.fromList(List.filled(5000, 7)),
        );
        store.commit([
          AdoptWine(w),
          SaveTasting(
            Tasting(
              id: const TastingId('t1'),
              wineId: w.id,
              tastedAt: DateTime.utc(2026, 11, 1),
              score: Score.fromTenths(46),
              photo: photo,
            ),
          ),
          Wishlist(WishlistItem(wineId: w.id, addedAt: DateTime.utc(2026))),
        ]);
        final file = await backup.exportCork();
        expect(p.basename(file.path), 'cork-20261115-203000.cork');

        final (other, otherStore, otherPhotos) = await setUpJournal('b');
        otherStore.commit([
          AdoptWine(indexWine(99)),
          SaveTasting(tasting(indexWine(99))),
        ]);
        final preview = await other.preview(file.path);
        final incoming = (preview as ImportReady).incoming;
        expect(incoming.journal.tastings, hasLength(1));

        final safety = await other.restore(incoming);
        expect(p.basename(safety.path), startsWith('pre-import-'));
        expect(otherStore.journal.tastings.keys, [const TastingId('t1')]);
        expect(otherStore.journal.wines[w.id]!.name, w.name);
        expect(otherStore.journal.wishlist.keys, [w.id]);
        expect(otherPhotos.has(photo), isTrue);
        expect(
          otherPhotos.fileFor(photo).readAsBytesSync(),
          photos.fileFor(photo).readAsBytesSync(),
        );

        final safetyPreview = await other.preview(safety.path) as ImportReady;
        expect(safetyPreview.incoming.journal.wines.keys, [indexWine(99).id]);
      },
    );

    test('the plain JSON export is the journal without photos', () async {
      final (backup, store, _) = await setUpJournal('c');
      final w = indexWine(5);
      store.commit([AdoptWine(w), SaveTasting(tasting(w))]);
      final file = await backup.exportJson();
      final json = jsonDecode(file.readAsStringSync()) as Map;
      expect(json['format'], 'cork.journal');
      expect(json.containsKey('photos'), isFalse);
      final preview = await backup.preview(file.path) as ImportReady;
      expect(preview.incoming.journal.tastings, hasLength(1));
    });

    test('preview rejects files that are not Cork backups', () async {
      final (backup, _, _) = await setUpJournal('d');
      Future<ImportProblem> problem(String name, List<int> bytes) async {
        final f = File(p.join(tmp.path, name))..writeAsBytesSync(bytes);
        return (await backup.preview(f.path) as ImportRejected).problem;
      }

      expect(
        await problem('x.txt', utf8.encode('hello')),
        isA<NotCorkBackup>(),
      );
      expect(
        await problem(
          'y.json',
          utf8.encode('{"format":"cork.journal","version":99}'),
        ),
        isA<BackupTooNew>(),
      );
      final zip = ZipEncoder().encode(
        Archive()..addFile(ArchiveFile.string('other.txt', 'x')),
      );
      expect(await problem('z.cork', zip), isA<NotCorkBackup>());
      expect(
        await problem(
          'w.json',
          utf8.encode('{"format":"cork.journal","version":1,"tastings":[{}]}'),
        ),
        isA<BackupDamaged>(),
      );
    });

    test('CSV export has one row per tasting and escapes cells', () async {
      final (backup, store, _) = await setUpJournal('e');
      final w = indexWine(1, name: 'Say "hi", Syrah');
      store.commit([
        AdoptWine(w),
        SaveTasting(tasting(w, notes: 'line one\nline two')),
      ]);
      final csv = (await backup.exportCsv()).readAsStringSync();
      final lines = csv.split('\r\n');
      expect(lines.first, csvColumns.join(','));
      expect(csv, contains('"Say ""hi"", Syrah"'));
      expect(csv, contains('"line one\nline two"'));
    });
  });

  test('SettingsStore persists currency and theme', () {
    final path = p.join(tmp.path, 'settings.json');
    final s = SettingsStore.open(path, fallback: const CurrencyCode('USD'));
    expect(s.currency, const CurrencyCode('USD'));
    s.currency = const CurrencyCode('AUD');
    s.theme = ThemeChoice.dark;
    final again = SettingsStore.open(path, fallback: const CurrencyCode('USD'));
    expect(again.currency, const CurrencyCode('AUD'));
    expect(again.theme, ThemeChoice.dark);
  });
}
