import 'dart:io';
import 'dart:typed_data';

import 'package:cork/data/settings_store.dart';
import 'package:cork/domain/ids.dart';
import 'package:cork/ui/settings/file_dialogs.dart';
import 'package:cork/ui/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/app_harness.dart';
import '../../support/builders.dart';

typedef Saved = ({String fileName, Uint8List bytes, String mimeType});

final class FakeDialogs implements FileDialogs {
  final saves = <Saved>[];
  Uri? saveResult = Uri.parse('content://downloads/backup');
  String? pickResult;

  @override
  Future<Uri?> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    saves.add((fileName: fileName, bytes: bytes, mimeType: mimeType));
    return saveResult;
  }

  @override
  Future<String?> pickPath() async => pickResult;
}

final hermitage = indexWine(1, name: 'Hermitage');
final barolo = indexWine(2, name: 'Barolo', grapes: ['Nebbiolo']);

Future<FakeDialogs> pumpSettings(WidgetTester tester, Harness h) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final dialogs = FakeDialogs();
  await tester.pumpWidget(
    h.wrap(FileDialogsScope(dialogs: dialogs, child: const SettingsScreen())),
  );
  return dialogs;
}

/// Taps [target] in the real zone so the file IO behind it can finish, then
/// pumps frames until [done] holds.
Future<void> tapThrough(
  WidgetTester tester,
  Finder target,
  bool Function() done,
) async {
  await tester.runAsync(() => tester.tap(target));
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'timed out after tapping $target');
}

void main() {
  testWidgets('currency and theme persist in settings', (tester) async {
    final h = Harness.create();
    await pumpSettings(tester, h);

    await tester.tap(find.text('AUD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EUR').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(h.settings.currency, const CurrencyCode('EUR'));
    expect(h.settings.theme, ThemeChoice.dark);
    expect(find.text('EUR'), findsOneWidget);
  });

  testWidgets('export saves a .cork through the save dialog', (tester) async {
    final h = Harness.create(
      journal: journalOf([(hermitage, tasting(hermitage))]),
    );
    final dialogs = await pumpSettings(tester, h);

    await tapThrough(
      tester,
      find.text('Export journal'),
      () => find.text('Journal exported').evaluate().isNotEmpty,
    );

    final saved = dialogs.saves.single;
    expect(p.extension(saved.fileName), '.cork');
    expect(saved.mimeType, 'application/zip');
    expect(saved.bytes, isNotEmpty);
  });

  testWidgets('a cancelled save says nothing', (tester) async {
    final h = Harness.create();
    final dialogs = await pumpSettings(tester, h)
      ..saveResult = null;

    await tapThrough(
      tester,
      find.text('Export tastings as CSV'),
      () => dialogs.saves.isNotEmpty,
    );
    await tester.pump();

    expect(p.extension(dialogs.saves.single.fileName), '.csv');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('import replaces the journal after confirming', (tester) async {
    final source = Harness.create(
      journal: journalOf([
        (hermitage, tasting(hermitage)),
        (barolo, tasting(barolo)),
        (barolo, tasting(barolo)),
      ]),
    );
    final backup = await tester.runAsync(source.backup.exportCork);
    final h = Harness.create(
      journal: journalOf([(hermitage, tasting(hermitage))]),
    );
    (await pumpSettings(tester, h)).pickResult = backup!.path;

    await tapThrough(
      tester,
      find.text('Import journal'),
      () => find.byType(AlertDialog).evaluate().isNotEmpty,
    );
    expect(find.text('Replace your journal with this backup?'), findsOneWidget);
    expect(
      find.text('Your current 1 tasting will be replaced.'),
      findsOneWidget,
    );

    await tapThrough(
      tester,
      find.text('Replace'),
      () => find.text('Imported 3 tastings').evaluate().isNotEmpty,
    );
    expect(h.journal.tastings.keys, source.journal.tastings.keys);
  });

  testWidgets('importing a junk file names the problem', (tester) async {
    final h = Harness.create(
      journal: journalOf([(hermitage, tasting(hermitage))]),
    );
    final junk = File(p.join(h.dir.path, 'notes.txt'))
      ..writeAsStringSync('not a backup');
    final dialogs = await pumpSettings(tester, h)
      ..pickResult = junk.path;

    await tapThrough(
      tester,
      find.text('Import journal'),
      () => find.text("That file isn't a Cork backup.").evaluate().isNotEmpty,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(h.journal.tastings, hasLength(1));
    expect(dialogs.saves, isEmpty);
  });
}
