import 'package:cork/domain/wine.dart';
import 'package:cork/ui/stats/stats_screen.dart';
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

DateTime daysAgo(int days) =>
    DateTime.now().toUtc().subtract(Duration(days: days));

final hermitage = indexWine(
  1,
  name: 'Hermitage',
  type: WineType.red,
  grapes: ['Syrah'],
);
final soave = indexWine(
  2,
  name: 'Soave Classico',
  type: WineType.white,
  grapes: ['Garganega'],
  region: 'Veneto',
  country: const Country('IT', 'Italy'),
);

void main() {
  for (final (name, theme) in [
    ('dark', CorkTheme.dark),
    ('light', CorkTheme.light),
  ]) {
    testWidgets('summarises a seeded journal in the $name theme', (
      tester,
    ) async {
      tallView(tester);
      final semantics = tester.ensureSemantics();
      final h = Harness.create(
        journal: journalOf([
          (hermitage, tasting(hermitage, at: daysAgo(5), tenths: 40)),
          (hermitage, tasting(hermitage, at: daysAgo(40), tenths: 30)),
          (soave, tasting(soave, at: daysAgo(80), tenths: 35)),
        ]),
      );
      await tester.pumpWidget(h.wrap(const StatsScreen(), theme: theme));

      expect(
        find.text('Average 3.5 · 3 tastings · 2 wines', findRichText: true),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('^Average over time')), findsOne);
      expect(find.text('Log a few more months to see a trend.'), findsNothing);
      expect(find.text('Soave Classico'), findsOneWidget);
      semantics.dispose();
    });
  }

  testWidgets('switching the breakdown dimension changes the rows', (
    tester,
  ) async {
    tallView(tester);
    final h = Harness.create(
      journal: journalOf([
        (hermitage, tasting(hermitage, at: daysAgo(3))),
        (soave, tasting(soave, at: daysAgo(4))),
      ]),
    );
    await tester.pumpWidget(h.wrap(const StatsScreen()));

    expect(find.text('Red'), findsOneWidget);
    expect(find.text('White'), findsOneWidget);
    expect(find.text('Italy'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Country'));
    await tester.pump();

    expect(find.text('France'), findsOneWidget);
    expect(find.text('Italy'), findsOneWidget);
    expect(find.text('Red'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Grape'));
    await tester.pump();

    expect(find.text('Syrah'), findsOneWidget);
    expect(find.text('Garganega'), findsOneWidget);
    expect(find.text('France'), findsNothing);
  });

  testWidgets('an empty journal says when stats appear', (tester) async {
    final h = Harness.create();
    await tester.pumpWidget(h.wrap(const StatsScreen()));

    expect(find.text('Stats appear after your first tasting.'), findsOne);
    expect(find.text('Average over time'.toUpperCase()), findsNothing);
  });

  testWidgets('the range excludes tastings older than it', (tester) async {
    tallView(tester);
    final h = Harness.create(
      journal: journalOf([
        (hermitage, tasting(hermitage, at: daysAgo(5), tenths: 40)),
        (soave, tasting(soave, at: daysAgo(400), tenths: 20)),
      ]),
    );
    await tester.pumpWidget(h.wrap(const StatsScreen()));

    expect(
      find.text('Average 3.0 · 2 tastings · 2 wines', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('12 months'));
    await tester.pump();
    expect(
      find.text('Average 4.0 · 1 tasting · 1 wine', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Soave Classico'), findsNothing);

    await tester.tap(find.text('30 days'));
    await tester.pump();
    expect(
      find.text('Average 4.0 · 1 tasting · 1 wine', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Log a few more months to see a trend.'), findsOneWidget);
  });
}
