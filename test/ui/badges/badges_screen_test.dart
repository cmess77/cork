import 'package:cork/domain/glass_color.dart';
import 'package:cork/domain/ids.dart';
import 'package:cork/domain/journal.dart';
import 'package:cork/ui/badges/badges_screen.dart';
import 'package:cork/ui/theme/cork_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/builders.dart';

void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

Finder inCard(String title, String text) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Card)),
  matching: find.text(text),
);

final hermitage = indexWine(1, name: 'Hermitage');
final barolo = indexWine(2, name: 'Barolo', grapes: ['Nebbiolo']);

final nov3 = DateTime(2026, 11, 3, 12).toUtc();

void main() {
  for (final (name, theme) in [
    ('dark', CorkTheme.dark),
    ('light', CorkTheme.light),
  ]) {
    testWidgets('earned and locked badges sit under their headings ($name)', (
      tester,
    ) async {
      tallView(tester);
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      final h = Harness.create(
        journal: journalOf([
          (hermitage, tasting(hermitage, id: 'a', at: nov3)),
        ]),
      );
      await tester.pumpWidget(h.wrap(const BadgesScreen(), theme: theme));

      expect(top('EARNED'), lessThan(top('First pour')));
      expect(top('First pour'), lessThan(top('IN PROGRESS')));
      expect(inCard('First pour', 'Earned Nov 3, 2026'), findsOneWidget);

      expect(top('Ten down'), greaterThan(top('IN PROGRESS')));
      expect(inCard('Ten down', '1 of 10'), findsOneWidget);
    });
  }

  testWidgets('deleting the only tasting moves a badge back to in progress', (
    tester,
  ) async {
    tallView(tester);
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    final h = Harness.create(
      journal: journalOf([(hermitage, tasting(hermitage, id: 'a', at: nov3))]),
    );
    await tester.pumpWidget(h.wrap(const BadgesScreen()));
    expect(inCard('First pour', 'Earned Nov 3, 2026'), findsOneWidget);

    h.store.commit([const DeleteTasting(TastingId('a'))]);
    await tester.pump();

    expect(find.text('EARNED'), findsNothing);
    expect(top('First pour'), greaterThan(top('IN PROGRESS')));
    expect(inCard('First pour', '0 of 1'), findsOneWidget);
  });

  testWidgets('tapping a card lists the tastings that count toward it', (
    tester,
  ) async {
    tallView(tester);
    const ruby = GlassColor(GlassHue.ruby, GlassIntensity.medium);
    final h = Harness.create(
      journal: journalOf([
        (hermitage, tasting(hermitage, at: nov3, color: ruby)),
        (
          barolo,
          tasting(barolo, at: nov3.add(const Duration(days: 1)), color: ruby),
        ),
      ]),
    );
    await tester.pumpWidget(h.wrap(const BadgesScreen()));
    expect(find.text('Hermitage'), findsNothing);

    await tester.tap(find.text('Ten down'));
    await tester.pumpAndSettle();

    expect(find.text('TASTINGS THAT COUNT'), findsOneWidget);
    expect(find.text('Hermitage'), findsOneWidget);
    expect(find.text('Barolo'), findsOneWidget);
  });
}
