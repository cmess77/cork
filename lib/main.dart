import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'app/app_dirs.dart';
import 'app/cork_app.dart';
import 'app/providers.dart';
import 'app/version.dart';
import 'data/backup.dart';
import 'data/journal_store.dart';
import 'data/photos.dart';
import 'data/settings_store.dart';
import 'domain/ids.dart';
import 'lookup/wine_index.dart';
import 'lookup/wine_lookup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dirs = await AppDirs.resolve();
  final settings = SettingsStore.open(
    dirs.settingsFile,
    fallback: _localeCurrency(),
  );
  final store = JournalStore.open(
    dirs.journalDb,
    beforeUpgrade: (fromVersion, docs) {
      final out = File(
        p.join(
          dirs.exportsDir,
          'pre-upgrade-v$fromVersion-${DateTime.now().millisecondsSinceEpoch}.json',
        ),
      );
      out.parent.createSync(recursive: true);
      out.writeAsStringSync(
        jsonEncode({
          'version': fromVersion,
          'wines': docs.wines,
          'tastings': docs.tastings,
          'wishlist': docs.wishlist,
        }),
        flush: true,
      );
    },
  );
  final photos = PhotoStore(dirs.photosDir);
  unawaited(photos.sweep(store.journal));
  final lookup = await BundledWineLookup.open(
    indexDir: dirs.indexDir,
    loadAsset: () => rootBundle.load(wineIndexAssetKey),
    journal: () => store.journal,
    appVersion: appVersion,
  );
  runApp(
    ProviderScope(
      overrides: [
        journalStoreProvider.overrideWithValue(store),
        wineLookupProvider.overrideWithValue(lookup),
        photoStoreProvider.overrideWithValue(photos),
        settingsStoreProvider.overrideWithValue(settings),
        backupProvider.overrideWithValue(
          Backup(
            store: store,
            photos: photos,
            exportsDir: dirs.exportsDir,
            appVersion: appVersion,
          ),
        ),
      ],
      child: const CorkApp(),
    ),
  );
}

CurrencyCode _localeCurrency() {
  try {
    final name = NumberFormat.simpleCurrency(
      locale: Platform.localeName,
    ).currencyName;
    return CurrencyCode.tryParse(name ?? '') ?? const CurrencyCode('USD');
  } on Object {
    return const CurrencyCode('USD');
  }
}
