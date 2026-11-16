import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../domain/fold.dart';
import '../domain/ids.dart';
import '../domain/scales.dart';
import '../domain/wine.dart';

/// First 12 hex digits of the SHA-256 of `assets/wine_index.db`.
/// `test/lookup/wine_index_asset_test.dart` fails when the asset changes
/// without this changing, so a rebuilt index always reinstalls on device.
const wineIndexAssetVersion = '9cc1fb509ace';

const wineIndexAssetKey = 'assets/wine_index.db';

/// SQLite cannot open a file inside the APK, so the bundled index is copied to
/// [indexDir] once per asset version. Temp file then rename, so a crash mid-copy
/// never leaves a half-written database under the final name. Returns the path.
Future<String> installWineIndex(
  String indexDir, {
  required Future<ByteData> Function() loadAsset,
}) async {
  final dir = Directory(indexDir);
  await dir.create(recursive: true);
  final name = 'wine_index.$wineIndexAssetVersion.db';
  final target = File(p.join(indexDir, name));

  if (!target.existsSync()) {
    final data = await loadAsset();
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await temp.rename(target.path);
  }

  await for (final entry in dir.list()) {
    if (entry is File && p.basename(entry.path) != name) {
      await entry.delete();
    }
  }
  return target.path;
}

final _separators = RegExp(r'[^\p{L}\p{N}\p{M}]+', unicode: true);

/// Words of [text] after [fold], two or more characters each.
List<String> foldedWords(String text) => [
  for (final w in fold(text).split(_separators))
    if (w.runes.length >= 2) w,
];

final class FtsQuery {
  FtsQuery._(this.tokens);

  /// Null when no token has two or more characters.
  static FtsQuery? parse(String userText) {
    final tokens = [
      for (final t in userText.toLowerCase().split(_separators))
        if (t.runes.length >= 2) t,
    ];
    return tokens.isEmpty ? null : FtsQuery._(tokens);
  }

  /// Lower case but not folded: the index removes diacritics itself, and
  /// folding 'ß' to 'ss' here would stop it matching.
  final List<String> tokens;

  String get match => tokens.map((t) => '"$t"*').join(' ');
}

const _searchSql =
    'SELECT w.* FROM wines_fts f JOIN wines w ON w.id = f.rowid '
    'WHERE wines_fts MATCH ?1 '
    'ORDER BY bm25(wines_fts, 10.0, 6.0, 3.0, 2.0) '
    'LIMIT ?2';

/// bm25 scores every match regardless of LIMIT, so a wide window costs little.
const _rerankWindow = 200;

final class WineIndex {
  WineIndex._(this._db, this._search);

  factory WineIndex.open(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      return WineIndex._(db, db.prepare(_searchSql, persistent: true));
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  final Database _db;
  final PreparedStatement _search;

  List<Wine> search(FtsQuery query, int limit) {
    final rows = _search.select([query.match, max(limit, _rerankWindow)]);
    final words = [for (final t in query.tokens) fold(t)];
    final leading = <Row>[];
    final rest = <Row>[];
    for (final row in rows) {
      (_nameStartsWith(row['name'] as String, words) ? leading : rest).add(row);
    }
    return [
      for (final row in [...leading, ...rest].take(limit)) _wine(row),
    ];
  }

  void close() {
    _search.close();
    _db.close();
  }
}

bool _nameStartsWith(String name, List<String> words) {
  final nameWords = foldedWords(name);
  if (nameWords.length < words.length) return false;
  for (var i = 0; i < words.length; i++) {
    if (!nameWords[i].startsWith(words[i])) return false;
  }
  return true;
}

Wine _wine(Row row) {
  final id = IndexWineId(row['id'] as int);
  final country = row['country'] as String?;
  return Wine(
    id: WineId.forIndex(id),
    name: row['name'] as String,
    provenance: FromIndex(id),
    winery: row['winery'] as String?,
    type: _types[row['type']],
    grapes: _grapes(row['grapes'] as String?),
    region: row['region'] as String?,
    country: country == null
        ? null
        : Country(row['country_code'] as String?, country),
    abv: (row['abv'] as num?)?.toDouble(),
    typicalBody: _bodies[row['body']],
    typicalAcidity: _acidities[row['acidity']],
  );
}

List<String> _grapes(String? json) {
  if (json == null) return const [];
  try {
    return [
      for (final g in jsonDecode(json) as List)
        if (g is String) g,
    ];
  } on FormatException {
    return const [];
  } on TypeError {
    return const [];
  }
}

const _types = {
  'Red': WineType.red,
  'White': WineType.white,
  'Rosé': WineType.rose,
  'Sparkling': WineType.sparkling,
  'Dessert': WineType.dessert,
  'Dessert/Port': WineType.fortified,
};

const _bodies = {
  'Very light-bodied': Level.low,
  'Light-bodied': Level.mediumMinus,
  'Medium-bodied': Level.medium,
  'Full-bodied': Level.mediumPlus,
  'Very full-bodied': Level.high,
};

const _acidities = {
  'Low': Level.low,
  'Medium': Level.medium,
  'High': Level.high,
};

final class IndexWorker {
  IndexWorker._() {
    _replies.handler = _onReply;
  }

  static Future<IndexWorker> spawn(String dbPath) async {
    final worker = IndexWorker._();
    try {
      await Isolate.spawn(
        _serve,
        (dbPath, worker._replies.sendPort),
        onExit: worker._replies.sendPort,
        debugName: 'wine-index',
      );
    } catch (_) {
      worker._replies.close();
      rethrow;
    }
    worker._requests = await worker._ready.future;
    return worker;
  }

  final _replies = RawReceivePort();
  final _ready = Completer<SendPort>();
  final _exited = Completer<void>();
  final _pending = <int, Completer<List<Wine>>>{};
  SendPort? _requests;
  var _nextId = 0;

  Future<List<Wine>> search(FtsQuery query, int limit) {
    final requests = _requests;
    if (requests == null) {
      return Future.error(StateError('Wine index is closed'));
    }
    final id = _nextId++;
    final reply = _pending[id] = Completer<List<Wine>>();
    requests.send((id, query, limit));
    return reply.future;
  }

  /// Completes once the isolate has closed the database and exited.
  Future<void> close() {
    _requests?.send(null);
    _requests = null;
    return _exited.future;
  }

  void _onReply(Object? message) {
    switch (message) {
      case SendPort requests:
        _ready.complete(requests);
      case (int id, List<Wine> wines):
        _pending.remove(id)?.complete(wines);
      case (int id, String error):
        _pending.remove(id)?.completeError(StateError(error));
      case String error when !_ready.isCompleted:
        _ready.completeError(StateError(error));
      case null:
        _replies.close();
        _requests = null;
        final gone = StateError('Wine index isolate exited');
        if (!_ready.isCompleted) _ready.completeError(gone);
        for (final reply in _pending.values) {
          reply.completeError(gone);
        }
        _pending.clear();
        _exited.complete();
    }
  }
}

void _serve((String, SendPort) args) {
  final (path, replies) = args;
  final WineIndex index;
  try {
    index = WineIndex.open(path);
  } catch (e) {
    replies.send('Cannot open wine index: $e');
    return;
  }
  final requests = RawReceivePort();
  requests.handler = (Object? message) {
    if (message case (int id, FtsQuery query, int limit)) {
      try {
        replies.send((id, index.search(query, limit)));
      } catch (e) {
        replies.send((id, '$e'));
      }
    } else {
      index.close();
      requests.close();
    }
  };
  replies.send(requests.sendPort);
}
