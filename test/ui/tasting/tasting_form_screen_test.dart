import 'dart:typed_data';

import 'package:cork/domain/aroma_wheel_data.dart';
import 'package:cork/domain/glass_color.dart';
import 'package:cork/domain/journal.dart';
import 'package:cork/domain/tasting.dart';
import 'package:cork/domain/wine.dart';
import 'package:cork/ui/tasting/label_photo_picker.dart';
import 'package:cork/ui/tasting/tasting_form_screen.dart';
import 'package:cork/ui/theme/cork_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/builders.dart';

final syrah = indexWine(1, name: 'Hermitage La Chapelle');
final riesling = indexWine(
  2,
  name: 'Clare Riesling',
  type: WineType.white,
  grapes: ['Riesling'],
);

final class FakePhotoPicker implements LabelPhotoPicker {
  final sources = <ImageSource>[];

  @override
  Future<Uint8List?> pick(ImageSource source) async {
    sources.add(source);
    return Uint8List.fromList(List.generate(64, (i) => i));
  }
}

/// Opens the form from a button and records what it resolves to.
final class FormHost {
  bool? result;

  Widget widget(Wine wine, {Tasting? editing}) => Scaffold(
    body: Center(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await openTastingForm(
            context,
            wine: wine,
            editing: editing,
          ),
          child: const Text('Log'),
        ),
      ),
    ),
  );
}

Future<FormHost> openForm(
  WidgetTester tester,
  Harness h,
  Wine wine, {
  Tasting? editing,
  LabelPhotoPicker? picker,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final host = FormHost();
  await tester.pumpWidget(
    ProviderScope(
      overrides: h.overrides,
      child: MaterialApp(
        theme: CorkTheme.dark,
        builder: (context, child) => picker == null
            ? child!
            : LabelPhotoPickerScope(picker: picker, child: child!),
        home: host.widget(wine, editing: editing),
      ),
    ),
  );
  await tester.tap(find.text('Log'));
  await tester.pumpAndSettle();
  return host;
}

bool enabled(WidgetTester tester, String label) => tester
    .widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    )
    .enabled;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> raiseScore(WidgetTester tester) async {
  await tapVisible(tester, find.byTooltip('Raise score by 0.1'));
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Save stays disabled until a score is set', (tester) async {
    final h = Harness.create();
    await openForm(tester, h, syrah);

    expect(find.text('New tasting'), findsOneWidget);
    expect(find.text('Set a score'), findsOneWidget);
    expect(enabled(tester, 'Save'), isFalse);
    expect(enabled(tester, 'Save tasting'), isFalse);

    await raiseScore(tester);

    expect(find.text('3.1'), findsOneWidget);
    expect(enabled(tester, 'Save'), isTrue);
    expect(enabled(tester, 'Save tasting'), isTrue);
  });

  testWidgets('saving commits the tasting and adopts the wine', (tester) async {
    final h = Harness.create();
    final host = await openForm(tester, h, syrah);

    await raiseScore(tester);
    await raiseScore(tester);
    await save(tester);

    expect(host.result, isTrue);
    expect(find.text('Log'), findsOneWidget);
    final saved = h.journal.tastings.values.single;
    expect(saved.score.format(), '3.2');
    expect(saved.wineId, syrah.id);
    expect(h.journal.wines[syrah.id]?.name, syrah.name);
    expect(
      find.text('Tasting saved · Badge earned: First pour'),
      findsOneWidget,
    );
  });

  testWidgets('a save that earns nothing just says Tasting saved', (
    tester,
  ) async {
    final h = Harness.create(journal: journalOf([(syrah, tasting(syrah))]));
    await openForm(tester, h, syrah);

    await raiseScore(tester);
    await save(tester);

    expect(h.journal.tastings, hasLength(2));
    expect(find.text('Tasting saved'), findsOneWidget);
  });

  testWidgets('a wishlisted wine leaves the wishlist on save, with Undo', (
    tester,
  ) async {
    final h = Harness.create(
      journal: Journal.empty.apply([
        AdoptWine(syrah),
        Wishlist(
          WishlistItem(
            wineId: syrah.id,
            addedAt: DateTime.utc(2026, 3, 1),
            vintage: const VintageYear(2019),
          ),
        ),
      ]),
    );
    await openForm(tester, h, syrah);

    expect(
      find.text('On your wishlist. Remove it when you save?'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('2019'), findsOneWidget);

    await raiseScore(tester);
    await save(tester);

    expect(h.journal.wishlist, isEmpty);
    expect(h.journal.tastings.values.single.vintage, const VintageYear(2019));
    expect(find.textContaining('Removed from wishlist'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(h.journal.wishlist[syrah.id]?.vintage, const VintageYear(2019));
    expect(h.journal.tastings, hasLength(1));
  });

  testWidgets('switching the wishlist line off keeps the wine wishlisted', (
    tester,
  ) async {
    final h = Harness.create(
      journal: Journal.empty.apply([
        AdoptWine(syrah),
        Wishlist(WishlistItem(wineId: syrah.id, addedAt: DateTime.utc(2026))),
      ]),
    );
    await openForm(tester, h, syrah);

    await tester.tap(find.byType(Switch));
    await raiseScore(tester);
    await save(tester);

    expect(h.journal.wishlist.keys, [syrah.id]);
    expect(find.textContaining('Removed from wishlist'), findsNothing);
  });

  testWidgets('edit mode prefills the tasting and saves in place', (
    tester,
  ) async {
    final t = tasting(
      syrah,
      tenths: 42,
      notes: 'Smoky',
      place: 'Bar Brutal',
      color: const GlassColor(GlassHue.garnet, GlassIntensity.deep),
    );
    final h = Harness.create(journal: journalOf([(syrah, t)]));
    await openForm(tester, h, syrah, editing: t);

    expect(find.text('Edit tasting'), findsOneWidget);
    expect(find.text('4.2'), findsOneWidget);
    expect(find.text('Smoky'), findsOneWidget);
    expect(find.text('Bar Brutal'), findsOneWidget);
    expect(find.text('Deep garnet'), findsOneWidget);

    await raiseScore(tester);
    await save(tester);

    final saved = h.journal.tastings.values.single;
    expect(saved.id, t.id);
    expect(saved.score.format(), '4.3');
    expect(saved.notes, 'Smoky');
  });

  testWidgets('Delete tasting asks, then removes it', (tester) async {
    final t = tasting(syrah);
    final h = Harness.create(journal: journalOf([(syrah, t)]));
    final host = await openForm(tester, h, syrah, editing: t);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete tasting'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this tasting?'), findsOneWidget);
    expect(find.text('Stats and badges will update.'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(h.journal.tastings, isEmpty);
    expect(host.result, isTrue);
    expect(find.text('Log'), findsOneWidget);
  });

  testWidgets('an untouched form closes without asking', (tester) async {
    final h = Harness.create();
    final host = await openForm(tester, h, syrah);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Discard this tasting?'), findsNothing);
    expect(host.result, isFalse);
  });

  testWidgets('the discard guard appears after a change', (tester) async {
    final h = Harness.create();
    final host = await openForm(tester, h, syrah);

    await tapVisible(tester, find.bySemanticsLabel('Aroma 3 of 5'));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this tasting?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('New tasting'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Log'), findsOneWidget);
    expect(host.result, isFalse);
    expect(h.journal.tastings, isEmpty);
  });

  testWidgets('a bad vintage names the fix and blocks the save', (
    tester,
  ) async {
    final h = Harness.create();
    await openForm(tester, h, syrah);

    await tester.enterText(find.widgetWithText(TextField, 'Vintage'), '1750');
    await raiseScore(tester);
    await save(tester);

    expect(find.text('Enter a year from 1800 to 2100'), findsOneWidget);
    expect(find.text('New tasting'), findsOneWidget);
    expect(h.journal.tastings, isEmpty);
  });

  testWidgets('glass, ratings and descriptors are saved', (tester) async {
    final h = Harness.create();
    await openForm(tester, h, riesling);

    await tapVisible(tester, find.bySemanticsLabel('Medium lemon'));
    expect(find.text('Medium lemon'), findsOneWidget);
    await tapVisible(tester, find.text('Deep'));
    expect(find.text('Deep lemon'), findsOneWidget);

    await tapVisible(tester, find.bySemanticsLabel('Flavor 4 of 5'));
    await tapVisible(tester, find.bySemanticsLabel('Finish 2 of 5'));
    await tapVisible(tester, find.bySemanticsLabel('Finish 2 of 5'));

    await tapVisible(tester, find.text('Add descriptors'));
    await tester.tap(find.widgetWithText(FilterChip, 'Lemon'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Lemon'), findsOneWidget);

    await raiseScore(tester);
    await save(tester);

    final saved = h.journal.tastings.values.single;
    expect(saved.color, const GlassColor(GlassHue.lemon, GlassIntensity.deep));
    expect(saved.flavor, Stars(4));
    expect(saved.finish, isNull);
    expect(saved.descriptors.map((d) => aromaWheel.resolve(d).label), [
      'Lemon',
    ]);
  });

  testWidgets('Change swaps the wine through search', (tester) async {
    final h = Harness.create(index: [syrah, riesling]);
    await openForm(tester, h, syrah);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'clare');
    await tester.pump();
    await tester.tap(find.text('Clare Riesling', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('New tasting'), findsOneWidget);
    expect(find.text('Clare Riesling'), findsOneWidget);
    expect(find.text('Hermitage La Chapelle'), findsNothing);

    await raiseScore(tester);
    await save(tester);
    expect(h.journal.tastings.values.single.wineId, riesling.id);
    expect(h.journal.wines.keys, [riesling.id]);
  });

  testWidgets('a label photo is stored and saved with the tasting', (
    tester,
  ) async {
    final h = Harness.create();
    final picker = FakePhotoPicker();
    await openForm(tester, h, syrah, picker: picker);

    final takePhoto = find.text('Take photo');
    await tester.ensureVisible(takePhoto);
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(takePhoto));
    for (var i = 0; i < 100 && find.text('Remove').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(picker.sources, [ImageSource.camera]);
    expect(find.text('Remove'), findsOneWidget);

    await raiseScore(tester);
    await save(tester);

    final photo = h.journal.tastings.values.single.photo;
    expect(photo, isNotNull);
    expect(h.photos.has(photo!), isTrue);
  });
}
