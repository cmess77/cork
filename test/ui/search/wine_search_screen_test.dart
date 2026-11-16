import 'dart:async';

import 'package:cork/app/providers.dart';
import 'package:cork/domain/fold.dart';
import 'package:cork/domain/ids.dart';
import 'package:cork/domain/journal.dart';
import 'package:cork/domain/wine.dart';
import 'package:cork/lookup/wine_lookup.dart';
import 'package:cork/ui/search/wine_search_screen.dart';
import 'package:cork/ui/theme/cork_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/builders.dart';

final hermitage = indexWine(1, name: 'Hermitage La Chapelle');
final barolo = indexWine(
  2,
  name: 'Barolo Cannubi',
  grapes: ['Nebbiolo'],
  region: 'Piedmont',
  country: const Country('IT', 'Italy'),
);
final online = Wine(
  id: WineId.forBarcode(const Barcode('3760123456789')),
  name: 'Cuvée des Amis',
  provenance: const FromOpenFoodFacts(Barcode('3760123456789')),
  winery: 'Cave Coop',
  type: WineType.rose,
);

/// Holds each suggest call open until the test answers it.
final class GatedLookup implements WineLookup {
  GatedLookup(this.index);
  final List<Wine> index;
  final _pending = <String, Completer<List<Wine>>>{};

  void answer(String text) => _pending.remove(text)!.complete([
    for (final w in index)
      if (fold(w.name).contains(fold(text))) w,
  ]);

  @override
  Future<List<Wine>> suggest(String text, {int limit = 50}) =>
      (_pending[text] = Completer()).future;

  @override
  Future<OnlineResult> searchOnline(String text) async =>
      const OnlineUnavailable();

  @override
  Future<void> close() async {}
}

/// A page that opens [screen], so tests can see search close behind itself.
class Launcher extends StatelessWidget {
  const Launcher(this.screen, {super.key});
  final Widget screen;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => screen),
        ),
        child: const Text('Start'),
      ),
    ),
  );
}

Future<void> pumpSearch(
  WidgetTester tester,
  Harness h, {
  SearchMode mode = SearchMode.log,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(h.wrap(Launcher(WineSearchScreen(mode: mode))));
  await tester.tap(find.text('Start'));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Finder rowTitle(String name) => find.text(name, findRichText: true);

bool enabled(WidgetTester tester, String label) => tester
    .widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    )
    .enabled;

void main() {
  testWidgets('an empty query lists recent wines', (tester) async {
    final h = Harness.create(journal: journalOf([(barolo, tasting(barolo))]));
    await pumpSearch(tester, h);

    expect(find.text('RECENT'), findsOneWidget);
    expect(rowTitle('Barolo Cannubi'), findsOneWidget);
    expect(find.text('Wine, winery, grape or region'), findsOneWidget);
  });

  testWidgets('typing shows index hits and never searches online', (
    tester,
  ) async {
    final h = Harness.create(index: [hermitage, barolo]);
    await pumpSearch(tester, h);

    await type(tester, 'herm');

    expect(rowTitle('Hermitage La Chapelle'), findsOneWidget);
    expect(find.text('Domaine Exemple · Rhône, France'), findsOneWidget);
    expect(find.text('Red'), findsOneWidget);
    expect(rowTitle('Barolo Cannubi'), findsNothing);
    expect(h.lookup.onlineCalls, 0);
    expect(enabled(tester, 'Search online'), isTrue);
    expect(enabled(tester, 'Add manually'), isTrue);
  });

  testWidgets('a slow answer for an older query never replaces a newer one', (
    tester,
  ) async {
    final h = Harness.create();
    final barbaresco = indexWine(3, name: 'Barbaresco Asili');
    final lookup = GatedLookup([barolo, barbaresco]);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalStoreProvider.overrideWithValue(h.store),
          wineLookupProvider.overrideWithValue(lookup),
          photoStoreProvider.overrideWithValue(h.photos),
          settingsStoreProvider.overrideWithValue(h.settings),
        ],
        child: MaterialApp(
          theme: CorkTheme.dark,
          home: const WineSearchScreen(),
        ),
      ),
    );

    await type(tester, 'bar');
    await type(tester, 'barolo');
    lookup.answer('barolo');
    await tester.pump();
    lookup.answer('bar');
    await tester.pump();

    expect(rowTitle('Barolo Cannubi'), findsOneWidget);
    expect(rowTitle('Barbaresco Asili'), findsNothing);
  });

  testWidgets('Search online shows hits under their own heading', (
    tester,
  ) async {
    final h = Harness.create(index: [hermitage]);
    h.lookup.online = OnlineHits([online]);
    await pumpSearch(tester, h);

    await type(tester, 'amis');
    expect(find.text('FROM OPEN FOOD FACTS'), findsNothing);
    await tester.tap(find.text('Search online'));
    await tester.pumpAndSettle();

    expect(h.lookup.onlineCalls, 1);
    expect(find.text('FROM OPEN FOOD FACTS'), findsOneWidget);
    expect(rowTitle('Cuvée des Amis'), findsOneWidget);
    expect(enabled(tester, 'Search online'), isFalse);
  });

  for (final (result, message) in [
    (
      const OnlineUnavailable() as OnlineResult,
      "You're offline. Your saved wines and the built-in list still work.",
    ),
    (
      const OnlineRateLimited(Duration(seconds: 40)),
      'Online search is busy. Try again in a minute.',
    ),
    (const OnlineHits([]), "Nothing online for 'zinfandel'. Add it manually."),
  ]) {
    testWidgets('online ${result.runtimeType} says "$message"', (tester) async {
      final h = Harness.create();
      h.lookup.online = result;
      await pumpSearch(tester, h);

      await type(tester, 'zinfandel');
      await tester.tap(find.text('Search online'));
      await tester.pumpAndSettle();

      expect(find.text('FROM OPEN FOOD FACTS'), findsOneWidget);
      expect(find.text(message), findsOneWidget);
    });
  }

  testWidgets('editing the query clears online results', (tester) async {
    final h = Harness.create();
    h.lookup.online = OnlineHits([online]);
    await pumpSearch(tester, h);

    await type(tester, 'amis');
    await tester.tap(find.text('Search online'));
    await tester.pumpAndSettle();
    expect(rowTitle('Cuvée des Amis'), findsOneWidget);

    await type(tester, 'amis rosé');

    expect(find.text('FROM OPEN FOOD FACTS'), findsNothing);
    expect(rowTitle('Cuvée des Amis'), findsNothing);
    expect(enabled(tester, 'Search online'), isTrue);
    expect(h.lookup.onlineCalls, 1);
  });

  testWidgets('picking a hit opens the tasting form', (tester) async {
    final h = Harness.create(index: [hermitage]);
    await pumpSearch(tester, h);

    await type(tester, 'herm');
    await tester.tap(rowTitle('Hermitage La Chapelle'));
    await tester.pumpAndSettle();

    expect(find.text('New tasting'), findsOneWidget);
    expect(find.text('Hermitage La Chapelle'), findsOneWidget);
  });

  testWidgets('saving the tasting closes search too', (tester) async {
    final h = Harness.create(index: [hermitage]);
    await pumpSearch(tester, h);

    await type(tester, 'herm');
    await tester.tap(rowTitle('Hermitage La Chapelle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Raise score by 0.1'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
    expect(h.journal.tastings.values.single.wineId, hermitage.id);
    expect(h.journal.wines[hermitage.id], isNotNull);
  });

  testWidgets('a hit already in the journal is logged as the journal copy', (
    tester,
  ) async {
    final renamed = Wine(
      id: hermitage.id,
      name: 'My Hermitage',
      provenance: hermitage.provenance,
    );
    final h = Harness.create(
      index: [hermitage],
      journal: Journal.empty.apply([AdoptWine(renamed)]),
    );
    await pumpSearch(tester, h);

    await type(tester, 'herm');
    await tester.tap(rowTitle('Hermitage La Chapelle'));
    await tester.pumpAndSettle();

    expect(find.text('My Hermitage'), findsOneWidget);
  });

  testWidgets('wishlist mode adds the pick and returns', (tester) async {
    final h = Harness.create(index: [barolo]);
    await pumpSearch(tester, h, mode: SearchMode.wishlist);

    await type(tester, 'barolo');
    await tester.tap(rowTitle('Barolo Cannubi'));
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Added to wishlist'), findsOneWidget);
    expect(h.journal.wishlist.keys, [barolo.id]);
    expect(h.journal.tastings, isEmpty);
  });

  testWidgets('the bookmark toggles the wishlist in place', (tester) async {
    final h = Harness.create(index: [barolo]);
    await pumpSearch(tester, h);
    await type(tester, 'barolo');

    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pump();
    expect(h.journal.wishlist.keys, [barolo.id]);
    expect(find.byTooltip('Remove from wishlist'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pump();
    expect(h.journal.wishlist, isEmpty);
    expect(find.text('New tasting'), findsNothing);
  });

  testWidgets('Add manually creates a wine and continues to the form', (
    tester,
  ) async {
    final h = Harness.create();
    await pumpSearch(tester, h);

    await type(tester, 'Garage Red');
    await tester.tap(find.text('Add manually'));
    await tester.pumpAndSettle();
    expect(find.text('Add a wine'), findsOneWidget);
    expect(find.text('Garage Red'), findsOneWidget);

    await tester.tap(find.text('Save').last);
    await tester.pump();
    expect(find.text('Pick a type'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Red'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Grapes'),
      'Shiraz, Grenache',
    );
    await tester.pump();
    expect(find.widgetWithText(InputChip, 'Shiraz'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Vintage'), '2021');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(find.text('New tasting'), findsOneWidget);
    expect(find.text('2021'), findsOneWidget);
    await tester.tap(find.byTooltip('Raise score by 0.1'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
    final wine = h.journal.wines.values.single;
    expect(wine.name, 'Garage Red');
    expect(wine.provenance, isA<EnteredByHand>());
    expect(wine.type, WineType.red);
    expect(wine.grapes, ['Shiraz', 'Grenache']);
    expect(wine.id.value, startsWith('m:'));
    final saved = h.journal.tastings.values.single;
    expect(saved.wineId, wine.id);
    expect(saved.vintage?.format(), '2021');
  });

  testWidgets('a manual wine in wishlist mode goes to the wishlist', (
    tester,
  ) async {
    final h = Harness.create();
    await pumpSearch(tester, h, mode: SearchMode.wishlist);

    await type(tester, 'Garage White');
    await tester.tap(find.text('Add manually'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'White'));
    await tester.enterText(find.widgetWithText(TextField, 'Country'), 'italy');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
    final wine = h.journal.wines.values.single;
    expect(wine.country, const Country('IT', 'Italy'));
    expect(h.journal.wishlist.keys, [wine.id]);
  });
}
