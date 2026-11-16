import 'dart:io';

import 'package:cork/domain/ids.dart';
import 'package:cork/domain/scales.dart';
import 'package:cork/domain/wine.dart';
import 'package:cork/lookup/wine_index.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture_index.dart';

void main() {
  group('FtsQuery.parse', () {
    String? match(String text) => FtsQuery.parse(text)?.match;

    test('quotes and prefix-stars each token, keeping diacritics', () {
      expect(match('chât marg'), '"chât"* "marg"*');
      expect(match('  Château   MARGAUX '), '"château"* "margaux"*');
    });

    test('user quotes never reach the MATCH string', () {
      expect(match('"chateau" marg"'), '"chateau"* "marg"*');
      expect(match('ab"cd'), '"ab"* "cd"*');
      expect(match('"""'), isNull);
    });

    test('FTS operators and punctuation become plain words or vanish', () {
      expect(match('NOT merlot'), '"not"* "merlot"*');
      expect(match('pinot-noir (2019)*'), '"pinot"* "noir"* "2019"*');
      expect(match('^ab:cd NEAR(ef gh)'), '"ab"* "cd"* "near"* "ef"* "gh"*');
      expect(match("d'Yquem"), '"yquem"*');
    });

    test('tokens under two characters are dropped', () {
      expect(match('chateau m'), '"chateau"*');
      expect(match('a b c'), isNull);
      expect(match('c'), isNull);
      expect(match(''), isNull);
      expect(match('   '), isNull);
    });
  });

  group('WineIndex on the fixture index', () {
    late Directory tmp;
    late WineIndex index;

    setUpAll(() {
      tmp = Directory.systemTemp.createTempSync('wine_index_search');
      index = WineIndex.open(buildFixtureIndex(tmp));
    });

    tearDownAll(() {
      index.close();
      tmp.deleteSync(recursive: true);
    });

    List<Wine> search(String text, [int limit = 20]) =>
        index.search(FtsQuery.parse(text)!, limit);

    Wine byId(int id) =>
        search(_names[id]!).firstWhere((w) => w.id.value == 'xw:$id');

    test('maps every column of a row', () {
      final wine = byId(2);
      expect(wine.id, WineId('xw:2'));
      expect(wine.provenance, isA<FromIndex>());
      expect((wine.provenance as FromIndex).id, IndexWineId(2));
      expect(wine.name, 'Château Margaux (Premier Grand Cru Classé)');
      expect(wine.winery, 'Château Margaux');
      expect(wine.type, WineType.red);
      expect(wine.grapes, ['Cabernet Sauvignon', 'Merlot']);
      expect(wine.region, 'Margaux');
      expect(wine.country, const Country('FR', 'France'));
      expect(wine.abv, 13.5);
      expect(wine.typicalBody, Level.high);
      expect(wine.typicalAcidity, Level.high);
    });

    test('maps every type, body, and acidity value', () {
      expect(
        [
          for (final id in [3, 5, 6, 7, 8]) byId(id).type,
        ],
        [
          WineType.white,
          WineType.fortified,
          WineType.sparkling,
          WineType.rose,
          WineType.dessert,
        ],
      );
      expect(
        [
          for (final id in [7, 4, 3, 1, 2]) byId(id).typicalBody,
        ],
        [
          Level.low,
          Level.mediumMinus,
          Level.medium,
          Level.mediumPlus,
          Level.high,
        ],
      );
      expect(
        [
          for (final id in [3, 1, 2]) byId(id).typicalAcidity,
        ],
        [Level.low, Level.medium, Level.high],
      );
    });

    test('unknown or missing values map to null', () {
      final wine = byId(10);
      expect(wine.type, isNull);
      expect(wine.typicalBody, isNull);
      expect(wine.typicalAcidity, isNull);
      expect(wine.abv, isNull);
      expect(wine.country, isNull);
      expect(wine.winery, isNull);
      expect(wine.grapes, isEmpty);
    });

    test('matches without diacritics and across columns', () {
      expect(search('chateau suduiraut').single.name, 'Sauternes');
      expect(search('semillon').single.name, 'Sauternes');
      expect(search('weissb'), isEmpty, reason: 'the index does not fold ß');
      expect(search('weiß').single.winery, 'Weingut Müller');
      expect(search('muller').single.winery, 'Weingut Müller');
    });

    test('names starting with the typed words rank first', () {
      final names = [for (final w in search('chateau marg')) w.name];
      expect(names.first, 'Château Margaux (Premier Grand Cru Classé)');
      expect(names, contains('Margaux du Château Margaux'));
    });

    test('respects the limit', () {
      expect(search('margaux', 2), hasLength(2));
    });
  });

  test('"chateau marg" puts Château Margaux first in the bundled index', () {
    final index = WineIndex.open(wineIndexAssetKey);
    addTearDown(index.close);
    final top = index.search(FtsQuery.parse('chateau marg')!, 20).first;
    expect(top.winery, 'Château Margaux');
    expect(top.name, startsWith('Château Margaux'));
  });
}

const _names = {
  1: 'Margaux du Château',
  2: 'Château Margaux Premier',
  3: 'Pavillon Blanc',
  4: 'Angludet',
  5: 'Vintage Port',
  6: 'Moscato Asti',
  7: 'Tavel',
  8: 'Sauternes',
  10: 'Mystery Cuvée',
};
