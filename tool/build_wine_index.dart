// Builds the bundled offline wine index from the X-Wines CSV.
//
//   dart run tool/build_wine_index.dart <XWines_Full_100K_wines.csv> [out.db]
//
// `out.db` defaults to assets/wine_index.db. The output file is replaced.

import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:sqlite3/sqlite3.dart';

const defaultOutput = 'assets/wine_index.db';

const _requiredColumns = [
  'WineID',
  'WineName',
  'Type',
  'Elaborate',
  'Grapes',
  'ABV',
  'Body',
  'Acidity',
  'Code',
  'Country',
  'RegionName',
  'WineryName',
];

/// Parses a Python list literal such as `['A', "B's", 3, None]`.
///
/// Items are quoted strings (with backslash escapes) or bare tokens, which
/// come back as `int`, `double`, `null` (for `None`) or the raw token string.
List<Object?> parseLiteralList(String source) {
  final s = source.trim();
  if (s.length < 2 || s[0] != '[' || s[s.length - 1] != ']') {
    throw FormatException('Not a list literal', source);
  }
  final items = <Object?>[];
  var i = 1;
  final end = s.length - 1;

  void skipSpace() {
    while (i < end && s[i].trim().isEmpty) {
      i++;
    }
  }

  skipSpace();
  while (i < end) {
    final c = s[i];
    if (c == "'" || c == '"') {
      final buf = StringBuffer();
      i++;
      while (true) {
        if (i >= end) throw FormatException('Unterminated string', source, i);
        final ch = s[i];
        if (ch == r'\') {
          if (i + 1 >= end) {
            throw FormatException('Dangling escape', source, i);
          }
          buf.write(_unescape(s[i + 1]));
          i += 2;
        } else if (ch == c) {
          i++;
          break;
        } else {
          buf.write(ch);
          i++;
        }
      }
      items.add(buf.toString());
    } else {
      final start = i;
      while (i < end && s[i] != ',') {
        i++;
      }
      items.add(_bareToken(s.substring(start, i).trim()));
    }
    skipSpace();
    if (i < end) {
      if (s[i] != ',') throw FormatException('Expected comma', source, i);
      i++;
      skipSpace();
    }
  }
  return items;
}

String _unescape(String c) => switch (c) {
      'n' => '\n',
      't' => '\t',
      'r' => '\r',
      _ => c,
    };

Object? _bareToken(String t) {
  if (t == 'None') return null;
  return int.tryParse(t) ?? double.tryParse(t) ?? t;
}

String? _text(String? v) {
  final t = v?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

class BuildResult {
  BuildResult({required this.inserted, required this.skipped});
  final int inserted;
  final int skipped;
}

/// Reads [csvPath] and writes a fresh index database at [dbPath].
BuildResult buildWineIndex(String csvPath, String dbPath) {
  final rows = csv.decode(File(csvPath).readAsStringSync());
  if (rows.isEmpty) throw FormatException('Empty CSV: $csvPath');
  final header = [for (final h in rows.first) h.toString().trim()];
  final col = {for (var i = 0; i < header.length; i++) header[i]: i};
  final missing = _requiredColumns.where((c) => !col.containsKey(c));
  if (missing.isNotEmpty) {
    throw FormatException('CSV is missing columns: ${missing.join(', ')}');
  }

  final out = File(dbPath);
  out.parent.createSync(recursive: true);
  for (final suffix in ['', '-journal', '-wal', '-shm']) {
    final f = File('$dbPath$suffix');
    if (f.existsSync()) f.deleteSync();
  }

  final db = sqlite3.open(dbPath);
  var inserted = 0;
  var skipped = 0;
  try {
    db.execute('''
      CREATE TABLE wines(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        winery TEXT,
        type TEXT,
        grapes TEXT,
        elaborate TEXT,
        abv REAL,
        body TEXT,
        acidity TEXT,
        country_code TEXT,
        country TEXT,
        region TEXT
      )
    ''');
    db.execute('''
      CREATE VIRTUAL TABLE wines_fts USING fts5(
        name, winery, grapes, region,
        content='wines', content_rowid='id',
        prefix='2 3',
        tokenize='unicode61 remove_diacritics 2'
      )
    ''');

    final insert = db.prepare(
      'INSERT INTO wines(id, name, winery, type, grapes, elaborate, abv, '
      'body, acidity, country_code, country, region) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    );
    db.execute('BEGIN');
    for (final row in rows.skip(1)) {
      if (row.length == 1 && row.first.toString().trim().isEmpty) continue;
      String? at(String name) => _text(row[col[name]!]?.toString());

      final name = at('WineName');
      final id = int.tryParse(at('WineID') ?? '');
      if (name == null || id == null) {
        skipped++;
        continue;
      }
      final grapes = [
        for (final g in parseLiteralList(at('Grapes') ?? '[]'))
          if (g != null) g.toString(),
      ];
      insert.execute([
        id,
        name,
        at('WineryName'),
        at('Type'),
        jsonEncode(grapes),
        at('Elaborate'),
        double.tryParse(at('ABV') ?? ''),
        at('Body'),
        at('Acidity'),
        at('Code'),
        at('Country'),
        at('RegionName'),
      ]);
      inserted++;
    }
    db.execute('COMMIT');
    insert.close();

    db.execute("INSERT INTO wines_fts(wines_fts) VALUES('rebuild')");
    db.execute("INSERT INTO wines_fts(wines_fts) VALUES('optimize')");
    db.execute('VACUUM');
  } finally {
    db.close();
  }
  return BuildResult(inserted: inserted, skipped: skipped);
}

void main(List<String> args) {
  if (args.isEmpty || args.length > 2) {
    stderr.writeln(
      'usage: dart run tool/build_wine_index.dart <wines.csv> [out.db]',
    );
    exit(64);
  }
  final dbPath = args.length == 2 ? args[1] : defaultOutput;
  final result = buildWineIndex(args[0], dbPath);
  final mb = File(dbPath).lengthSync() / (1024 * 1024);
  stdout.writeln(
    'wrote $dbPath: ${result.inserted} wines, ${result.skipped} skipped, '
    '${mb.toStringAsFixed(2)} MB',
  );
}
