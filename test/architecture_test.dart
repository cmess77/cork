import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Import rules from the architecture sketch, checked over import lines.
void main() {
  final imports = RegExp(r'''^import\s+['"]([^'"]+)['"]''', multiLine: true);

  Map<String, List<String>> importsUnder(String dir) => {
    for (final f in Directory(dir).listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart'))
        f.path.replaceAll(r'\', '/'): [
          for (final m in imports.allMatches(f.readAsStringSync())) m.group(1)!,
        ],
  };

  test('domain imports only dart:core libraries and itself', () {
    for (final MapEntry(key: file, value: uris) in importsUnder(
      'lib/domain',
    ).entries) {
      for (final uri in uris) {
        final ok =
            uri == 'dart:math' ||
            uri == 'dart:collection' ||
            (!uri.contains(':') && !uri.startsWith('..'));
        expect(ok, isTrue, reason: '$file imports $uri');
      }
    }
  });

  test('ui never reaches past the facades', () {
    const private = [
      'journal_db.dart',
      'wine_index.dart',
      'open_food_facts.dart',
      'package:sqlite3',
      'package:http',
    ];
    final ui = Directory('lib/ui');
    if (!ui.existsSync()) return;
    for (final MapEntry(key: file, value: uris) in importsUnder(
      'lib/ui',
    ).entries) {
      for (final uri in uris) {
        expect(
          private.any(uri.endsWith) || private.any(uri.startsWith),
          isFalse,
          reason: '$file imports $uri',
        );
      }
    }
  });

  test('sqlite3 and http stay inside their owners', () {
    const sqliteOwners = [
      'lib/data/journal_db.dart',
      'lib/lookup/wine_index.dart',
    ];
    const httpOwners = ['lib/lookup/open_food_facts.dart'];
    for (final MapEntry(key: file, value: uris) in importsUnder(
      'lib',
    ).entries) {
      if (uris.any((u) => u.startsWith('package:sqlite3'))) {
        expect(sqliteOwners, contains(file), reason: '$file imports sqlite3');
      }
      if (uris.any((u) => u.startsWith('package:http'))) {
        expect(httpOwners, contains(file), reason: '$file imports http');
      }
    }
  });
}
