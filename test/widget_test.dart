import 'package:cork/ui/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_harness.dart';

void main() {
  testWidgets('the shell offers the five destinations', (tester) async {
    final h = Harness.create();
    await tester.pumpWidget(h.wrap(const Shell()));
    for (final label in [
      'Journal',
      'Wishlist',
      'Stats',
      'Badges',
      'Settings',
    ]) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(NavigationDestination, 'Badges'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Badges'), findsOneWidget);
  });
}
