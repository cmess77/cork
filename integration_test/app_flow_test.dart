import 'dart:io';

import 'package:cork/app/app_dirs.dart';
import 'package:cork/app/cork_app.dart';
import 'package:cork/app/providers.dart';
import 'package:cork/app/version.dart';
import 'package:cork/data/backup.dart';
import 'package:cork/data/journal_store.dart';
import 'package:cork/data/photos.dart';
import 'package:cork/data/settings_store.dart';
import 'package:cork/domain/ids.dart';
import 'package:cork/domain/journal.dart';
import 'package:cork/lookup/wine_index.dart';
import 'package:cork/lookup/wine_lookup.dart';
import 'package:cork/ui/badges/badges_screen.dart';
import 'package:cork/ui/feed/feed_screen.dart';
import 'package:cork/ui/settings/file_dialogs.dart';
import 'package:cork/ui/stats/stats_screen.dart';
import 'package:cork/ui/tasting/label_photo_picker.dart';
import 'package:cork/ui/wishlist/wishlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class TestApp {
  TestApp._(this.root, this.store, this.lookup, this.backup, this.overrides);

  static Future<TestApp> boot() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(
      p.join(support.path, 'app_flow_${DateTime.now().microsecondsSinceEpoch}'),
    )..createSync(recursive: true);
    final dirs = AppDirs(root.path);
    final settings = SettingsStore.open(
      dirs.settingsFile,
      fallback: const CurrencyCode('USD'),
    );
    final store = JournalStore.open(dirs.journalDb, beforeUpgrade: (_, _) {});
    final photos = PhotoStore(dirs.photosDir);
    final lookup = await BundledWineLookup.open(
      indexDir: dirs.indexDir,
      loadAsset: () => rootBundle.load(wineIndexAssetKey),
      journal: () => store.journal,
      appVersion: appVersion,
    );
    final backup = Backup(
      store: store,
      photos: photos,
      exportsDir: dirs.exportsDir,
      appVersion: appVersion,
    );
    return TestApp._(root, store, lookup, backup, [
      journalStoreProvider.overrideWithValue(store),
      wineLookupProvider.overrideWithValue(lookup),
      photoStoreProvider.overrideWithValue(photos),
      settingsStoreProvider.overrideWithValue(settings),
      backupProvider.overrideWithValue(backup),
    ]);
  }

  final Directory root;
  final JournalStore store;
  final BundledWineLookup lookup;
  final Backup backup;
  final List<Override> overrides;

  Widget widget({
    required LabelPhotoPicker picker,
    required FileDialogs dialogs,
  }) => ProviderScope(
    overrides: overrides,
    child: LabelPhotoPickerScope(
      picker: picker,
      child: FileDialogsScope(dialogs: dialogs, child: const CorkApp()),
    ),
  );

  Future<void> dispose() async {
    await lookup.close();
    store.dispose();
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  }
}

final class FakePhotoPicker implements LabelPhotoPicker {
  var picks = 0;

  @override
  Future<Uint8List?> pick(ImageSource source) async {
    picks++;
    return Uint8List.fromList(List.generate(256, (i) => i % 251));
  }
}

final class FakeFileDialogs implements FileDialogs {
  String? nextPick;

  @override
  Future<Uri?> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async => null;

  @override
  Future<String?> pickPath() async => nextPick;
}

Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $finder');
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Finder within<T extends Widget>(Finder finder) =>
    find.descendant(of: find.byType(T), matching: finder);

Future<void> go(WidgetTester tester, String destination) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(destination),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> pickTopHit(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  final rows = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(InkWell),
  );
  await waitFor(tester, rows);
  await tester.tap(rows.first);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('log, review, edit, delete, wishlist, and restore', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final app = await TestApp.boot();
    addTearDown(app.dispose);
    final picker = FakePhotoPicker();
    final dialogs = FakeFileDialogs();
    await tester.pumpWidget(app.widget(picker: picker, dialogs: dialogs));
    await tester.pumpAndSettle();

    expect(within<FeedScreen>(find.text('NOTHING ON THE BOARD YET')), findsOne);
    await tester.tap(within<FeedScreen>(find.text('Log a glass')));
    await tester.pumpAndSettle();

    await pickTopHit(tester, 'chateau marg');
    expect(find.text('New tasting'), findsOneWidget);

    await tapVisible(tester, find.byTooltip('Raise score by 0.1'));
    await tapVisible(tester, find.byTooltip('Raise score by 0.1'));
    await tapVisible(
      tester,
      find.bySemanticsLabel(RegExp(r'^Medium [a-z-]+$')).first,
    );
    await tapVisible(tester, find.text('Take photo'));
    await waitFor(tester, find.text('Remove'));
    expect(picker.picks, 1);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final logged = app.store.journal.feed.single;
    final name = logged.wine.name;
    expect(name, contains('Margaux'));
    expect(logged.tasting.score.format(), '3.2');
    expect(logged.tasting.color, isNotNull);
    expect(logged.tasting.photo, isNotNull);
    expect(within<FeedScreen>(find.text(name)), findsOneWidget);
    expect(find.textContaining('Badge earned: First pour'), findsOneWidget);

    await go(tester, 'Stats');
    expect(
      within<StatsScreen>(
        find.text('Average 3.2 · 1 tasting · 1 wine', findRichText: true),
      ),
      findsOneWidget,
    );

    await go(tester, 'Badges');
    expect(within<BadgesScreen>(find.textContaining('Earned ')), findsWidgets);

    await go(tester, 'Journal');
    await tester.tap(within<FeedScreen>(find.text(name)));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Edit').last);
    expect(find.text('Edit tasting'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Raise score by 0.1'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(app.store.journal.feed.single.tasting.score.format(), '3.3');

    await tapVisible(tester, find.text('Edit').last);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete tasting'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this tasting?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(app.store.journal.tastings, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(within<FeedScreen>(find.text('NOTHING ON THE BOARD YET')), findsOne);

    await go(tester, 'Badges');
    expect(within<BadgesScreen>(find.text('0 of 1')), findsOneWidget);
    expect(within<BadgesScreen>(find.textContaining('Earned ')), findsNothing);

    await go(tester, 'Wishlist');
    await tester.tap(within<WishlistScreen>(find.text('Add a wine')));
    await tester.pumpAndSettle();
    await pickTopHit(tester, 'chateau marg');
    final saved = app.store.journal.wishlist.values.single;
    final savedName = app.store.journal.wines[saved.wineId]!.name;
    expect(within<WishlistScreen>(find.text(savedName)), findsOneWidget);

    final exported = await app.backup.exportCork();
    expect(exported.existsSync(), isTrue);
    app.store.commit([Unwishlist(saved.wineId)]);
    await tester.pumpAndSettle();
    expect(app.store.journal.wishlist, isEmpty);

    final preview = await app.backup.preview(exported.path);
    expect(preview, isA<ImportReady>());

    dialogs.nextPick = exported.path;
    await go(tester, 'Settings');
    await tapVisible(tester, find.text('Import journal'));
    await waitFor(tester, find.text('Replace your journal with this backup?'));
    await tester.tap(find.text('Replace'));
    await waitFor(tester, find.text('Imported 0 tastings'));

    expect(app.store.journal.wishlist.keys, [saved.wineId]);
    await go(tester, 'Wishlist');
    expect(within<WishlistScreen>(find.text(savedName)), findsOneWidget);
    semantics.dispose();
  });
}
