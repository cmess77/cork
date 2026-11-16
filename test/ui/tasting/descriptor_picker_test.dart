import 'package:cork/domain/aroma_wheel.dart';
import 'package:cork/domain/aroma_wheel_data.dart';
import 'package:cork/domain/ids.dart';
import 'package:cork/ui/tasting/aroma_wheel_view.dart';
import 'package:cork/ui/tasting/descriptor_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

DescriptorId idOf(String label) =>
    aromaWheel.descriptors.firstWhere((d) => d.label == label).id;

Finder chip(String label) => find.widgetWithText(FilterChip, label);

/// Opens the picker from a button and records what it returns.
final class PickerHost {
  Set<DescriptorId>? result;
  var returned = false;

  Widget widget(Set<DescriptorId> selected) => Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result = await showDescriptorPicker(context, selected: selected);
          returned = true;
        },
        child: const Text('Add descriptors'),
      ),
    ),
  );
}

Future<PickerHost> openPicker(
  WidgetTester tester, {
  Set<DescriptorId> selected = const {},
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final host = PickerHost();
  await tester.pumpWidget(Harness.create().wrap(host.widget(selected)));
  await tester.tap(find.text('Add descriptors'));
  await tester.pumpAndSettle();
  return host;
}

void main() {
  testWidgets('shows the wheel and the Fruit chips first', (tester) async {
    await openPicker(tester);

    expect(find.byType(AromaWheelView), findsOneWidget);
    expect(find.text('CITRUS'), findsOneWidget);
    expect(chip('Lemon'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Aroma wheel, showing Fruit')),
      findsOneWidget,
    );
  });

  testWidgets('chips toggle and Done returns the selection', (tester) async {
    final host = await openPicker(tester, selected: {idOf('Pear')});

    await tester.tap(chip('Lemon'));
    await tester.tap(chip('Pear'));
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp('1 selected: 1 Fruit')),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(host.returned, isTrue);
    expect(host.result, {idOf('Lemon')});
  });

  testWidgets('search filters descriptors across categories', (tester) async {
    final host = await openPicker(tester);

    await tester.enterText(find.byType(TextField), 'vanil');
    await tester.pump();
    expect(chip('Vanilla'), findsOneWidget);
    expect(chip('Lemon'), findsNothing);

    await tester.tap(chip('Vanilla'));
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No descriptors match "zzz".'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(host.result, {idOf('Vanilla')});
  });

  testWidgets('tapping a wheel segment switches to its category', (
    tester,
  ) async {
    await openPicker(tester);
    final wheel = tester.getRect(find.byType(AromaWheelView));
    final geometry = AromaWheelGeometry(wheel.size);

    await tester.tapAt(wheel.topLeft + geometry.anchorOf(AromaFamily.oak));
    await tester.pumpAndSettle();

    expect(chip('Vanilla'), findsOneWidget);
    expect(chip('Lemon'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Aroma wheel, showing Oak')),
      findsOneWidget,
    );
  });

  testWidgets('dismissing without Done returns null', (tester) async {
    final host = await openPicker(tester, selected: {idOf('Pear')});

    await tester.tap(chip('Lemon'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(host.returned, isTrue);
    expect(host.result, isNull);
  });
}
