import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../tool/build_wine_index.dart';

void main() {
  late Directory tmp;
  late Database db;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('wine_index_test');
    final result = buildWineIndex(
      'tool/fixtures/XWines_Test_100_wines.csv',
      '${tmp.path}/index.db',
    );
    expect(result.skipped, 0);
    db = sqlite3.open('${tmp.path}/index.db', mode: OpenMode.readOnly);
  });

  tearDownAll(() {
    db.close();
    tmp.deleteSync(recursive: true);
  });

  List<int> ids(String match) => [
    for (final r in db.select(
      'SELECT rowid FROM wines_fts WHERE wines_fts MATCH ? ORDER BY rowid',
      [match],
    ))
      r['rowid'] as int,
  ];

  Row wine(int id) =>
      db.select('SELECT * FROM wines WHERE id = ?', [id]).single;

  List<String> grapes(int id) =>
      (jsonDecode(wine(id)['grapes'] as String) as List).cast<String>();

  test('indexes every fixture row', () {
    expect(db.select('SELECT count(*) AS n FROM wines').single['n'], 100);
  });

  test('grapes round-trip as JSON lists', () {
    expect(grapes(113730), ['Pinot Noir']);
    expect(grapes(102079), ['Loureiro', 'Alvarinho', 'Arinto']);
    expect(grapes(162507), contains('Carmenère'));
    expect(grapes(162507).length, greaterThan(1));
  });

  test('columns carry the source values', () {
    final row = wine(113730);
    expect(row['name'], "Pommard Premier Cru 'Grand Clos des Épenots'");
    expect(row['type'], 'Red');
    expect(row['abv'], isA<double>());
    expect(row['country_code'], isNotNull);
  });

  test('FTS prefix query on grapes', () {
    final hits = ids('grapes : pino*');
    expect(hits, containsAll([113730, 114973]));
    for (final id in hits) {
      expect(grapes(id).join(' ').toLowerCase(), contains('pino'));
    }
  });

  test('FTS name search ignores diacritics in both directions', () {
    expect(ids('name : alem*'), contains(103003));
    expect(ids('name : além*'), contains(103003));
    expect(ids('name : epenots'), [113730]);
    expect(ids('name : mare alta'), [102079]);
  });

  test('FTS prefix query on winery and region', () {
    final row = wine(113730);
    final winery = (row['winery'] as String).substring(0, 3);
    final region = (row['region'] as String).substring(0, 3);
    expect(ids('winery : "$winery"*'), contains(113730));
    expect(ids('region : "$region"*'), contains(113730));
  });

  group('parseLiteralList', () {
    test('handles quotes, apostrophes and bare tokens', () {
      expect(parseLiteralList('''['A', "B's", 3, 'N.V.', None]'''), [
        'A',
        "B's",
        3,
        'N.V.',
        null,
      ]);
    });

    test('empty list', () => expect(parseLiteralList('[]'), isEmpty));

    test('rejects non-lists', () {
      expect(() => parseLiteralList('__import__("os")'), throwsFormatException);
    });
  });
}
