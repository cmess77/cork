import 'package:cork/domain/glass_color.dart';
import 'package:cork/domain/journal.dart';
import 'package:cork/domain/tasting.dart';
import 'package:cork/ui/format.dart';
import 'package:cork/ui/routes.dart';
import 'package:cork/ui/theme/cork_theme.dart';
import 'package:cork/ui/wine/wine_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/builders.dart';

void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

final hermitage = indexWine(
  1,
  name: 'Hermitage La Chapelle',
  winery: 'Paul Jaboulet Aîné',
  grapes: ['Syrah'],
);

final older = tasting(
  hermitage,
  at: DateTime(2026, 3, 1, 19).toUtc(),
  tenths: 30,
  vintage: const VintageYear(2016),
  color: const GlassColor(GlassHue.garnet, GlassIntensity.deep),
  notes: 'Smoked meat and violets',
  place: 'Bar Brutal',
);
final newer = tasting(
  hermitage,
  at: DateTime(2026, 9, 14, 19).toUtc(),
  tenths: 40,
  vintage: const VintageYear(2018),
  color: const GlassColor(GlassHue.ruby, GlassIntensity.medium),
);

Harness twoTastings() => Harness.create(
  journal: journalOf([(hermitage, older), (hermitage, newer)]),
);

String rowTitle(Tasting t) =>
    '${fullDate(t.tastedAt)} · ${t.vintage!.format()}';

void main() {
  for (final (name, theme) in [
    ('dark', CorkTheme.dark),
    ('light', CorkTheme.light),
  ]) {
    testWidgets('shows facts, the average, and tastings newest first ($name)', (
      tester,
    ) async {
      tallView(tester);
      final h = twoTastings();
      await tester.pumpWidget(
        h.wrap(WineDetailScreen(id: hermitage.id), theme: theme),
      );

      expect(find.text('Hermitage La Chapelle'), findsWidgets);
      expect(find.text('Paul Jaboulet Aîné'), findsWidgets);
      for (final (key, value) in [
        ('Type', 'Red'),
        ('Grapes', 'Syrah'),
        ('Region', 'Rhône'),
        ('Country', 'France'),
        ('Source', 'X-Wines'),
      ]) {
        expect(find.text(key), findsOneWidget);
        expect(find.text(value), findsOneWidget);
      }
      expect(find.text('ABV'), findsNothing);
      expect(find.text('3.5'), findsOneWidget);
      expect(find.text('from 2 tastings'), findsOneWidget);
      expect(find.text('Log again'), findsOneWidget);

      final newerY = tester.getTopLeft(find.text(rowTitle(newer))).dy;
      final olderY = tester.getTopLeft(find.text(rowTitle(older))).dy;
      expect(newerY, lessThan(olderY));
    });
  }

  testWidgets('tapping a tasting expands its details in place', (tester) async {
    tallView(tester);
    final h = twoTastings();
    await tester.pumpWidget(h.wrap(WineDetailScreen(id: hermitage.id)));

    expect(find.text('Smoked meat and violets'), findsNothing);
    await tester.tap(find.text(rowTitle(older)));
    await tester.pumpAndSettle();

    expect(find.text('Smoked meat and violets'), findsOneWidget);
    expect(find.text('Deep garnet'), findsOneWidget);
    expect(find.text('Where'), findsOneWidget);
    expect(find.bySemanticsLabel('Edit tasting'), findsOneWidget);

    await tester.tap(find.text(rowTitle(older)));
    await tester.pumpAndSettle();
    expect(find.text('Smoked meat and violets'), findsNothing);
  });

  testWidgets('Edit on an expanded tasting opens the form on it', (
    tester,
  ) async {
    tallView(tester);
    final h = twoTastings();
    await tester.pumpWidget(
      h.wrap(WineDetailScreen(id: hermitage.id, expand: older.id)),
    );

    expect(find.text('Smoked meat and violets'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit tasting'), findsOneWidget);
    expect(find.text('Bar Brutal'), findsOneWidget);
  });

  testWidgets('openWine pushes the wine with the named tasting open', (
    tester,
  ) async {
    tallView(tester);
    final h = twoTastings();
    await tester.pumpWidget(
      h.wrap(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  openWine(context, hermitage.id, expand: older.id),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Smoked meat and violets'), findsOneWidget);
  });

  testWidgets('the bookmark adds to and removes from the wishlist', (
    tester,
  ) async {
    tallView(tester);
    final h = twoTastings();
    await tester.pumpWidget(h.wrap(WineDetailScreen(id: hermitage.id)));

    await tester.tap(find.byTooltip('Add to wishlist'));
    await tester.pumpAndSettle();
    expect(h.journal.wishlist.keys, [hermitage.id]);
    expect(find.text('Added to wishlist'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pumpAndSettle();
    expect(h.journal.wishlist, isEmpty);
    expect(find.text('Removed from wishlist'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(h.journal.wishlist.keys, [hermitage.id]);
  });

  testWidgets('a wine only on the wishlist renders with no verdict yet', (
    tester,
  ) async {
    tallView(tester);
    final h = Harness.create(
      journal: Journal.empty.apply([
        AdoptWine(hermitage),
        Wishlist(
          WishlistItem(wineId: hermitage.id, addedAt: DateTime.utc(2026, 5)),
        ),
      ]),
    );
    await tester.pumpWidget(h.wrap(WineDetailScreen(id: hermitage.id)));

    expect(
      find.text('Not tasted yet. Log a glass to give it a score.'),
      findsOneWidget,
    );
    expect(find.text('TASTINGS'), findsNothing);
    expect(find.byTooltip('Remove from wishlist'), findsOneWidget);
    expect(find.text('Log a glass'), findsOneWidget);
  });

  testWidgets('Edit wine saves the new name', (tester) async {
    tallView(tester);
    final h = twoTastings();
    await tester.pumpWidget(h.wrap(WineDetailScreen(id: hermitage.id)));

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit wine'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Hermitage La Chapelle'),
      'La Chapelle',
    );
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(h.journal.wines[hermitage.id]?.name, 'La Chapelle');
    expect(find.text('La Chapelle'), findsWidgets);
  });
}
