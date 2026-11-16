// On-device gate: the SQLite that ships in the APK must have FTS5 with
// `remove_diacritics`, and the bundled index must install and answer a prefix
// query. Run with:
//   flutter test integration_test/index_gate_test.dart -d emulator-5554

import 'dart:io';

import 'package:cork/lookup/wine_index.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled index installs and FTS5 answers prefix queries', (
    tester,
  ) async {
    final support = await getApplicationSupportDirectory();
    final indexDir = p.join(support.path, 'index_gate');
    final dir = Directory(indexDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);

    final cold = Stopwatch()..start();
    final path = await installWineIndex(
      indexDir,
      loadAsset: () => rootBundle.load(wineIndexAssetKey),
    );
    cold.stop();

    final warm = Stopwatch()..start();
    await installWineIndex(
      indexDir,
      loadAsset: () => rootBundle.load(wineIndexAssetKey),
    );
    warm.stop();

    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    addTearDown(db.close);

    final options = [
      for (final row in db.select('PRAGMA compile_options'))
        row.values.first as String,
    ];
    expect(options, contains('ENABLE_FTS5'));

    db.execute(
      "CREATE VIRTUAL TABLE temp.probe USING fts5(t, "
      "tokenize='unicode61 remove_diacritics 2')",
    );
    db.execute("INSERT INTO temp.probe(t) VALUES ('Château Margaux')");
    expect(
      db.select("SELECT t FROM temp.probe WHERE probe MATCH '\"chateau\"*'"),
      hasLength(1),
    );

    final query = Stopwatch()..start();
    final rows = db.select(
      'SELECT w.name, w.winery FROM wines_fts f JOIN wines w ON w.id = f.rowid '
      'WHERE wines_fts MATCH ? ORDER BY bm25(wines_fts, 10.0, 6.0, 3.0, 2.0) '
      'LIMIT 20',
      ['"chateau"* "marg"*'],
    );
    query.stop();
    expect(rows, isNotEmpty);

    // ignore: avoid_print
    print(
      'INDEX_GATE sqlite=${sqlite3.version.libVersion} '
      'install_cold_ms=${cold.elapsedMilliseconds} '
      'install_warm_ms=${warm.elapsedMilliseconds} '
      'first_query_ms=${query.elapsedMilliseconds} rows=${rows.length} '
      'top="${rows.first['name']} / ${rows.first['winery']}"',
    );
  });
}
