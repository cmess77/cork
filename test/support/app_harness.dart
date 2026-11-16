import 'dart:io';

import 'package:cork/app/providers.dart';
import 'package:cork/data/backup.dart';
import 'package:cork/data/journal_store.dart';
import 'package:cork/data/photos.dart';
import 'package:cork/data/settings_store.dart';
import 'package:cork/domain/fold.dart';
import 'package:cork/domain/ids.dart';
import 'package:cork/domain/journal.dart';
import 'package:cork/domain/wine.dart';
import 'package:cork/lookup/wine_lookup.dart';
import 'package:cork/ui/theme/cork_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Answers suggest from a fixed list by folded substring; online search
/// returns [online].
final class FakeWineLookup implements WineLookup {
  FakeWineLookup(this.index, {this.online = const OnlineUnavailable()});
  final List<Wine> index;
  OnlineResult online;
  int onlineCalls = 0;

  @override
  Future<List<Wine>> suggest(String text, {int limit = 50}) async {
    final q = fold(text);
    if (q.length < 2) return const [];
    return index.where((w) => fold(w.name).contains(q)).take(limit).toList();
  }

  @override
  Future<OnlineResult> searchOnline(String text) async {
    onlineCalls++;
    return online;
  }

  @override
  Future<void> close() async {}
}

/// Real stores on a temp directory, a fake lookup, and the Cork theme.
final class Harness {
  Harness._(this.dir, this.store, this.photos, this.settings, this.lookup)
    : backup = Backup(
        store: store,
        photos: photos,
        exportsDir: p.join(dir.path, 'exports'),
        appVersion: '1.0.0',
      );

  static Harness create({List<Wine> index = const [], Journal? journal}) {
    final dir = Directory.systemTemp.createTempSync('cork_ui_');
    final store = JournalStore.open(
      p.join(dir.path, 'journal.db'),
      beforeUpgrade: (_, _) {},
    );
    if (journal != null) store.replaceAll(journal);
    final h = Harness._(
      dir,
      store,
      PhotoStore(p.join(dir.path, 'photos')),
      SettingsStore.open(
        p.join(dir.path, 'settings.json'),
        fallback: const CurrencyCode('AUD'),
      ),
      FakeWineLookup(index),
    );
    addTearDown(h.dispose);
    return h;
  }

  final Directory dir;
  final JournalStore store;
  final PhotoStore photos;
  final SettingsStore settings;
  final FakeWineLookup lookup;
  final Backup backup;

  Journal get journal => store.journal;

  List<Override> get overrides => [
    journalStoreProvider.overrideWithValue(store),
    wineLookupProvider.overrideWithValue(lookup),
    photoStoreProvider.overrideWithValue(photos),
    backupProvider.overrideWithValue(backup),
    settingsStoreProvider.overrideWithValue(settings),
  ];

  /// Pumps [child] (default: the whole app body) inside the providers.
  Widget wrap(Widget child, {ThemeData? theme}) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: theme ?? CorkTheme.dark, home: child),
  );

  void dispose() {
    store.dispose();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold the db file briefly after close.
    }
  }
}
