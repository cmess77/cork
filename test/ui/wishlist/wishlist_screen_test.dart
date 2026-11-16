import 'package:cork/domain/journal.dart';
import 'package:cork/domain/tasting.dart';
import 'package:cork/domain/wine.dart';
import 'package:cork/ui/wishlist/wishlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/builders.dart';

final albarino = indexWine(
  1,
  name: 'Albariño Rías Baixas',
  type: WineType.white,
  winery: 'Pazo de Señoráns',
  region: 'Rías Baixas',
);
final zinfandel = indexWine(
  2,
  name: 'Zinfandel Lytton Springs',
  winery: 'Ridge',
  region: 'Sonoma',
);

Harness twoSaved() => Harness.create(
  journal: Journal.empty.apply([
    AdoptWine(albarino),
    AdoptWine(zinfandel),
    Wishlist(
      WishlistItem(wineId: albarino.id, addedAt: DateTime.utc(2025, 2, 1)),
    ),
    Wishlist(
      WishlistItem(
        wineId: zinfandel.id,
        addedAt: DateTime.utc(2025, 6, 1, 12),
        vintage: const VintageYear(2019),
      ),
    ),
  ]),
);

double y(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('rows show winery and region, newest first, then by name', (
    tester,
  ) async {
    final h = twoSaved();
    await tester.pumpWidget(h.wrap(const WishlistScreen()));

    expect(find.text('Pazo de Señoráns · Rías Baixas'), findsOneWidget);
    expect(find.text('Ridge · Sonoma'), findsOneWidget);
    expect(find.text('Added Jun 1, 2025'), findsOneWidget);
    expect(y(tester, zinfandel.name), lessThan(y(tester, albarino.name)));

    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();

    expect(y(tester, albarino.name), lessThan(y(tester, zinfandel.name)));
  });

  testWidgets('swiping a row removes it, and Undo puts it back', (
    tester,
  ) async {
    final h = twoSaved();
    await tester.pumpWidget(h.wrap(const WishlistScreen()));

    await tester.drag(find.text(zinfandel.name), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(h.journal.wishlist.keys, [albarino.id]);
    expect(find.text(zinfandel.name), findsNothing);
    expect(find.text('Removed from wishlist'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(h.journal.wishlist[zinfandel.id]?.vintage, const VintageYear(2019));
    expect(find.text(zinfandel.name), findsOneWidget);
  });

  testWidgets('Log opens the tasting form with the saved vintage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final h = twoSaved();
    await tester.pumpWidget(h.wrap(const WishlistScreen()));

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text(zinfandel.name),
          matching: find.byType(InkWell),
        ),
        matching: find.byTooltip('Log'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New tasting'), findsOneWidget);
    expect(find.text(zinfandel.name), findsOneWidget);
    expect(find.text('2019'), findsOneWidget);
  });

  testWidgets('tapping a row opens the wine', (tester) async {
    final h = twoSaved();
    await tester.pumpWidget(h.wrap(const WishlistScreen()));

    await tester.tap(find.text(albarino.name));
    await tester.pumpAndSettle();

    expect(
      find.text('Not tasted yet. Log a glass to give it a score.'),
      findsOne,
    );
    expect(find.byTooltip('Remove from wishlist'), findsOneWidget);
  });

  testWidgets('Add a wine opens search in wishlist mode', (tester) async {
    final h = Harness.create(index: [albarino]);
    await tester.pumpWidget(h.wrap(const WishlistScreen()));

    await tester.tap(find.text('Add a wine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'alba');
    await tester.pumpAndSettle();
    await tester.tap(find.text(albarino.name, findRichText: true));
    await tester.pumpAndSettle();

    expect(h.journal.wishlist.keys, [albarino.id]);
    expect(find.text('Added to wishlist'), findsOneWidget);
    expect(find.text('Pazo de Señoráns · Rías Baixas'), findsOneWidget);
  });

  testWidgets('an empty wishlist says how to fill it', (tester) async {
    final h = Harness.create();
    await tester.pumpWidget(h.wrap(const WishlistScreen()));

    expect(
      find.text(
        'Save wines you want to try. Tap the bookmark in search, or Add a '
        'wine.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add a wine'), findsOneWidget);
  });
}
