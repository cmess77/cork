import 'dart:io';
import 'dart:typed_data';

import 'package:cork/domain/ids.dart';
import 'package:cork/domain/journal.dart';
import 'package:cork/domain/wine.dart';
import 'package:cork/lookup/wine_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/builders.dart';
import 'fixture_index.dart';

void main() {
  late Directory tmp;
  late String dbPath;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('wine_lookup');
    dbPath = buildFixtureIndex(tmp);
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  final handMade = Wine.manual(
    id: WineId('m:0001'),
    name: 'Garage Margaux',
    type: WineType.red,
  );
  final pavillon = indexWine(
    3,
    name: 'Pavillon Blanc (cellar bottle)',
    winery: 'Château Margaux',
    region: 'Margaux',
    type: WineType.white,
  );
  final renamed = indexWine(
    4,
    name: 'House red',
    winery: null,
    region: null,
    grapes: const [],
  );
  final unrelated = indexWine(99, name: 'Barolo', region: 'Piedmont');

  var journal = Journal.empty;

  Future<BundledWineLookup> open() async {
    final lookup = await BundledWineLookup.open(
      indexDir: '${tmp.path}/installed',
      loadAsset: () async =>
          ByteData.sublistView(File(dbPath).readAsBytesSync()),
      journal: () => journal,
      appVersion: '0.0.0-test',
    );
    addTearDown(lookup.close);
    return lookup;
  }

  setUp(() {
    journal = journalOf([
      (renamed, tasting(renamed, at: DateTime.utc(2026, 1, 1))),
      (pavillon, tasting(pavillon, at: DateTime.utc(2026, 3, 1))),
      (handMade, tasting(handMade, at: DateTime.utc(2026, 2, 1))),
      (unrelated, tasting(unrelated, at: DateTime.utc(2026, 4, 1))),
    ]);
  });

  List<String> ids(List<Wine> wines) => [for (final w in wines) w.id.value];

  test(
    'journal wines come first, most recent first, then index hits',
    () async {
      final hits = await (await open()).suggest('margaux');
      expect(ids(hits).take(2), ['xw:3', 'm:0001']);
      expect(ids(hits).skip(2), containsAll(['xw:1', 'xw:2']));
      expect(ids(hits), isNot(contains('xw:99')));
    },
  );

  test(
    'an index wine in the journal appears once, as the journal copy',
    () async {
      final hits = await (await open()).suggest('margaux');
      expect(ids(hits).toSet(), hasLength(hits.length));
      expect(
        hits.firstWhere((w) => w.id.value == 'xw:3').name,
        'Pavillon Blanc (cellar bottle)',
      );
      expect(
        hits.firstWhere((w) => w.id.value == 'xw:4').name,
        'House red',
        reason: 'matched only in the index, still shown as the journal copy',
      );
    },
  );

  test(
    'journal matching folds case and diacritics, word prefixes only',
    () async {
      final lookup = await open();
      expect(ids(await lookup.suggest('GARAGE marg')), ['m:0001']);
      expect(ids(await lookup.suggest('châ marg')), contains('xw:3'));
      expect(ids(await lookup.suggest('arage')), isEmpty);
    },
  );

  test('a trailing one-letter word keeps the previous results', () async {
    final lookup = await open();
    expect(
      ids(await lookup.suggest('chateau m')),
      ids(await lookup.suggest('chateau')),
    );
    expect(await lookup.suggest('chateau m'), isNotEmpty);
  });

  test('with no word of two letters, returns recent journal wines', () async {
    final lookup = await open();
    final recent = ['xw:99', 'xw:3', 'm:0001', 'xw:4'];
    expect(ids(await lookup.suggest('')), recent);
    expect(ids(await lookup.suggest('m')), recent);
    expect(ids(await lookup.suggest('m', limit: 2)), recent.take(2));
  });

  test('respects the limit across journal and index', () async {
    final lookup = await open();
    expect(await lookup.suggest('margaux', limit: 3), hasLength(3));
    expect(await lookup.suggest('margaux', limit: 0), isEmpty);
  });

  test('never throws on hostile input', () async {
    final lookup = await open();
    for (final text in [
      '"',
      '""*',
      'NOT',
      'ab AND cd',
      '(((',
      '*',
      '-ab',
      'col:ab',
      '^ab',
      'NEAR(ab cd, 2)',
      '́́',
      '🍷🍷',
      "'; DROP TABLE wines; --",
      'x' * 5000,
    ]) {
      await expectLater(lookup.suggest(text), completes, reason: text);
    }
  });

  test('after close, returns journal matches only', () async {
    final lookup = await open();
    await lookup.close();
    expect(ids(await lookup.suggest('margaux')), ['xw:3', 'm:0001']);
  });

  test('an installed index is not copied again', () async {
    await open();
    var loads = 0;
    final again = await BundledWineLookup.open(
      indexDir: '${tmp.path}/installed',
      loadAsset: () async {
        loads++;
        return ByteData(0);
      },
      journal: () => journal,
      appVersion: '0.0.0-test',
    );
    addTearDown(again.close);
    expect(loads, 0);
    expect(await again.suggest('sauternes'), hasLength(1));
  });
}
