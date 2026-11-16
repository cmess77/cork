import 'package:cork/domain/dimension.dart';
import 'package:cork/domain/feed.dart';
import 'package:cork/domain/wine.dart';
import 'package:cork/ui/feed/feed_screen.dart';
import 'package:cork/ui/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/builders.dart';

void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

DateTime localNoon(int year, int month, int day) =>
    DateTime(year, month, day, 12).toUtc();

final hermitage = indexWine(1, name: 'Hermitage', type: WineType.red);
final soave = indexWine(
  2,
  name: 'Soave Classico',
  type: WineType.white,
  grapes: ['Garganega'],
  winery: 'Pieropan',
  region: 'Veneto',
  country: const Country('IT', 'Italy'),
);
final crozes = indexWine(3, name: 'Crozes-Hermitage', type: WineType.red);

Harness seeded() => Harness.create(
  journal: journalOf([
    (hermitage, tasting(hermitage, at: localNoon(2026, 11, 12), tenths: 40)),
    (
      soave,
      tasting(
        soave,
        at: localNoon(2026, 11, 3),
        tenths: 30,
        place: 'Bar Brutal',
      ),
    ),
    (
      crozes,
      tasting(
        crozes,
        at: localNoon(2026, 10, 20),
        tenths: 36,
        notes: 'Smoky bacon fat',
      ),
    ),
  ]),
);

Future<void> openFilterSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filter'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('groups tastings by month under a summary of the slice', (
    tester,
  ) async {
    tallView(tester);
    final h = seeded();
    await tester.pumpWidget(h.wrap(const FeedScreen()));

    expect(find.text('3 tastings · 3 wines · avg 3.5'), findsOneWidget);
    final nov = tester.getTopLeft(find.text('NOVEMBER 2026')).dy;
    final oct = tester.getTopLeft(find.text('OCTOBER 2026')).dy;
    final soaveRow = tester.getTopLeft(find.text('Soave Classico')).dy;
    final crozesRow = tester.getTopLeft(find.text('Crozes-Hermitage')).dy;
    expect(nov < soaveRow && soaveRow < oct && oct < crozesRow, isTrue);
    expect(find.text('Log a glass'), findsOneWidget);
  });

  testWidgets('search matches where and notes, not just the name', (
    tester,
  ) async {
    tallView(tester);
    final h = seeded();
    await tester.pumpWidget(h.wrap(const FeedScreen()));

    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'brutal');
    await tester.pump();

    expect(find.text('Soave Classico'), findsOneWidget);
    expect(find.text('Hermitage'), findsNothing);
    expect(find.text('1 tasting · 1 wine · avg 3.0'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'smoky');
    await tester.pump();
    expect(find.text('Crozes-Hermitage'), findsOneWidget);
    expect(find.text('Soave Classico'), findsNothing);

    await tester.tap(find.byTooltip('Close search'));
    await tester.pump();
    expect(find.text('3 tastings · 3 wines · avg 3.5'), findsOneWidget);
  });

  testWidgets('a type facet narrows the rows and its chip clears it', (
    tester,
  ) async {
    tallView(tester);
    final h = seeded();
    await tester.pumpWidget(h.wrap(const FeedScreen()));

    await openFilterSheet(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'White'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'White'), findsOneWidget);
    expect(find.text('Soave Classico'), findsOneWidget);
    expect(find.text('Hermitage'), findsNothing);
    expect(find.text('Crozes-Hermitage'), findsNothing);

    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(find.byType(InputChip), findsNothing);
    expect(find.text('Hermitage'), findsOneWidget);
    expect(find.text('Crozes-Hermitage'), findsOneWidget);
  });

  testWidgets('a country chip from the journal filters, and removes alone', (
    tester,
  ) async {
    tallView(tester);
    final h = seeded();
    await tester.pumpWidget(h.wrap(const FeedScreen()));

    await openFilterSheet(tester);
    expect(find.widgetWithText(FilterChip, 'France'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Italy'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Hermitage'), findsNothing);
    await tester.tap(find.byTooltip('Remove Italy'));
    await tester.pump();
    expect(find.text('Hermitage'), findsOneWidget);
  });

  testWidgets('an empty journal invites the first glass', (tester) async {
    final h = Harness.create();
    await tester.pumpWidget(h.wrap(const FeedScreen()));

    expect(find.text('NOTHING ON THE BOARD YET'), findsOneWidget);
    expect(
      find.text('Log the first glass you taste and it shows up here.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Log a glass'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('filters that match nothing say so and clear', (tester) async {
    tallView(tester);
    final h = seeded();
    await tester.pumpWidget(h.wrap(const FeedScreen()));

    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'riesling');
    await tester.pump();

    expect(find.text('No tastings match these filters.'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();

    expect(find.text('No tastings match these filters.'), findsNothing);
    expect(find.text('Hermitage'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('long-press Delete asks, then removes the tasting', (
    tester,
  ) async {
    tallView(tester);
    final h = seeded();
    await tester.pumpWidget(h.wrap(const FeedScreen()));

    await tester.longPress(find.text('Soave Classico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this tasting?'), findsOneWidget);
    expect(find.text('Stats and badges will update.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(h.journal.tastings, hasLength(2));
    expect(h.journal.tastingsOf(soave.id), isEmpty);
    expect(find.text('Soave Classico'), findsNothing);
    expect(find.text('2 tastings · 2 wines · avg 3.8'), findsOneWidget);
  });

  testWidgets('long-press Cancel keeps the tasting', (tester) async {
    tallView(tester);
    final h = seeded();
    await tester.pumpWidget(h.wrap(const FeedScreen()));

    await tester.longPress(find.text('Soave Classico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(h.journal.tastings, hasLength(3));
  });

  testWidgets('long-press Edit opens the tasting form on that tasting', (
    tester,
  ) async {
    tallView(tester);
    final h = seeded();
    await tester.pumpWidget(h.wrap(const FeedScreen()));

    await tester.longPress(find.text('Crozes-Hermitage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit tasting'), findsOneWidget);
    expect(find.text('Smoky bacon fat'), findsOneWidget);
  });

  testWidgets('tapping a row opens the wine with that tasting expanded', (
    tester,
  ) async {
    tallView(tester);
    final h = seeded();
    await tester.pumpWidget(h.wrap(const FeedScreen()));

    await tester.tap(find.text('Crozes-Hermitage'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR VERDICT'), findsOneWidget);
    expect(find.text('Smoky bacon fat'), findsOneWidget);
  });

  testWidgets('openFilteredFeed pushes a feed narrowed to that group', (
    tester,
  ) async {
    tallView(tester);
    final h = seeded();
    await tester.pumpWidget(
      h.wrap(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openFilteredFeed(
                context,
                const FeedFilter(
                  facets: {
                    Dimension.country: {'IT'},
                  },
                ),
              ),
              child: const Text('Italy'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Italy'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Italy'), findsOneWidget);
    expect(find.text('Soave Classico'), findsOneWidget);
    expect(find.text('Hermitage'), findsNothing);
    expect(find.text('1 tasting · 1 wine · avg 3.0'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(FeedScreen), findsNothing);
  });

  Future<void> sortBy(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<FeedSort>, label),
    );
    await tester.pumpAndSettle();
  }

  double rowY(WidgetTester tester, String name) =>
      tester.getTopLeft(find.text(name).first).dy;

  testWidgets('sorts by rating, highest first, without month headings', (
    tester,
  ) async {
    tallView(tester);
    await tester.pumpWidget(seeded().wrap(const FeedScreen()));

    await sortBy(tester, 'Highest rated');

    expect(find.text('NOVEMBER 2026'), findsNothing);
    final h = rowY(tester, 'Hermitage');
    final c = rowY(tester, 'Crozes-Hermitage');
    final s = rowY(tester, 'Soave Classico');
    expect(h < c && c < s, isTrue);
  });

  testWidgets('sorts oldest first and by name', (tester) async {
    tallView(tester);
    await tester.pumpWidget(seeded().wrap(const FeedScreen()));

    await sortBy(tester, 'Oldest');
    expect(
      tester.getTopLeft(find.text('OCTOBER 2026')).dy <
          tester.getTopLeft(find.text('NOVEMBER 2026')).dy,
      isTrue,
    );

    await sortBy(tester, 'Name');
    final c = rowY(tester, 'Crozes-Hermitage');
    final h = rowY(tester, 'Hermitage');
    final s = rowY(tester, 'Soave Classico');
    expect(c < h && h < s, isTrue);
  });

  testWidgets('sorts by grape under a heading per grape, blends in each', (
    tester,
  ) async {
    tallView(tester);
    final blend = indexWine(
      4,
      name: 'Côtes du Rhône',
      grapes: ['Syrah', 'Grenache'],
    );
    final mystery = indexWine(5, name: 'Mystery Red', grapes: const []);
    final h = Harness.create(
      journal: journalOf([
        (soave, tasting(soave, at: localNoon(2026, 11, 3))),
        (blend, tasting(blend, at: localNoon(2026, 11, 5))),
        (mystery, tasting(mystery, at: localNoon(2026, 11, 6))),
      ]),
    );
    await tester.pumpWidget(h.wrap(const FeedScreen()));

    await sortBy(tester, 'Grape');

    final garganega = tester.getTopLeft(find.text('GARGANEGA')).dy;
    final grenache = tester.getTopLeft(find.text('GRENACHE')).dy;
    final syrah = tester.getTopLeft(find.text('SYRAH')).dy;
    final none = tester.getTopLeft(find.text('NOT RECORDED')).dy;
    expect(garganega < grenache && grenache < syrah && syrah < none, isTrue);
    expect(find.text('Côtes du Rhône'), findsNWidgets(2));
    expect(rowY(tester, 'Mystery Red') > none, isTrue);
  });
}
