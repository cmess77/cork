import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'journal_codec.dart';

/// Document rows in journal.db. Private to [JournalStore]: it stores and
/// returns raw JSON docs and knows nothing of the domain.
final class JournalDb {
  JournalDb._(this._db);

  /// Ordered table-shape scripts. Index i takes `user_version` i to i+1.
  static const _schema = [
    '''
    CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    CREATE TABLE wines (id TEXT PRIMARY KEY, doc TEXT NOT NULL);
    CREATE TABLE tastings (
      id TEXT PRIMARY KEY,
      wine_id TEXT NOT NULL REFERENCES wines(id),
      doc TEXT NOT NULL
    );
    CREATE INDEX tastings_wine ON tastings(wine_id);
    CREATE TABLE wishlist (
      wine_id TEXT PRIMARY KEY REFERENCES wines(id),
      doc TEXT NOT NULL
    );
    ''',
  ];

  static JournalDb open(String path) {
    final db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA foreign_keys = ON');
    final at = db.select('PRAGMA user_version').first.values.first as int;
    for (var v = at; v < _schema.length; v++) {
      db.execute('BEGIN');
      db.execute(_schema[v]);
      db.execute('PRAGMA user_version = ${v + 1}');
      if (v == 0) {
        db.execute("INSERT INTO meta VALUES ('doc_version', ?)", [
          '$currentDocVersion',
        ]);
      }
      db.execute('COMMIT');
    }
    return JournalDb._(db);
  }

  final Database _db;

  int get docVersion => int.parse(
    _db
            .select("SELECT value FROM meta WHERE key = 'doc_version'")
            .first['value']
        as String,
  );

  RawDocs readAll() {
    List<Doc> docs(String table) => [
      for (final row in _db.select('SELECT doc FROM $table'))
        (jsonDecode(row['doc'] as String) as Map).cast<String, Object?>(),
    ];
    return (
      wines: docs('wines'),
      tastings: docs('tastings'),
      wishlist: docs('wishlist'),
    );
  }

  /// Applies every row change in one transaction: all of them or none.
  void write(RowChanges c) => _transaction(() {
    for (final (id, doc) in c.putWines) {
      _db.execute('INSERT OR REPLACE INTO wines VALUES (?, ?)', [
        id,
        jsonEncode(doc),
      ]);
    }
    for (final (id, wineId, doc) in c.putTastings) {
      _db.execute('INSERT OR REPLACE INTO tastings VALUES (?, ?, ?)', [
        id,
        wineId,
        jsonEncode(doc),
      ]);
    }
    for (final id in c.deleteTastings) {
      _db.execute('DELETE FROM tastings WHERE id = ?', [id]);
    }
    for (final (wineId, doc) in c.putWishlist) {
      _db.execute('INSERT OR REPLACE INTO wishlist VALUES (?, ?)', [
        wineId,
        jsonEncode(doc),
      ]);
    }
    for (final wineId in c.deleteWishlist) {
      _db.execute('DELETE FROM wishlist WHERE wine_id = ?', [wineId]);
    }
  });

  /// Deletes every row and inserts [rows] at the current doc version.
  void replaceAll(RowChanges rows) => _transaction(() {
    _db.execute('DELETE FROM tastings');
    _db.execute('DELETE FROM wishlist');
    _db.execute('DELETE FROM wines');
    _db.execute("UPDATE meta SET value = ? WHERE key = 'doc_version'", [
      '$currentDocVersion',
    ]);
    write(rows);
  });

  void _transaction(void Function() body) {
    if (_db.autocommit) {
      _db.execute('BEGIN IMMEDIATE');
      try {
        body();
        _db.execute('COMMIT');
      } catch (_) {
        _db.execute('ROLLBACK');
        rethrow;
      }
    } else {
      body();
    }
  }

  void close() => _db.close();
}

/// Rows to write, keyed as the tables are.
final class RowChanges {
  RowChanges({
    this.putWines = const [],
    this.putTastings = const [],
    this.deleteTastings = const [],
    this.putWishlist = const [],
    this.deleteWishlist = const [],
  });

  final List<(String id, Doc doc)> putWines;
  final List<(String id, String wineId, Doc doc)> putTastings;
  final List<String> deleteTastings;
  final List<(String wineId, Doc doc)> putWishlist;
  final List<String> deleteWishlist;

  bool get isEmpty =>
      putWines.isEmpty &&
      putTastings.isEmpty &&
      deleteTastings.isEmpty &&
      putWishlist.isEmpty &&
      deleteWishlist.isEmpty;
}
