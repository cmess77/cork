import 'package:cork/domain/dimension.dart';
import 'package:cork/domain/feed.dart';
import 'package:cork/domain/ids.dart';
import 'package:cork/domain/scales.dart';
import 'package:cork/domain/stats.dart';
import 'package:cork/domain/tasting.dart';
import 'package:cork/domain/wine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/builders.dart';

void main() {
  const aud = CurrencyCode('AUD');
  const usd = CurrencyCode('USD');

  group('Dimension.keysOf', () {
    test('grapes fold case, accents, and spacing into one key', () {
      final a = indexWine(1, grapes: ['Gewürztraminer', 'Pinot  Gris']);
      final b = indexWine(2, grapes: ['gewurztraminer']);
      final keysA = Dimension.grape.keysOf((wine: a, tasting: tasting(a)));
      final keysB = Dimension.grape.keysOf((wine: b, tasting: tasting(b)));
      expect(keysA.map((k) => k.id), ['gewurztraminer', 'pinot gris']);
      expect(keysA.first, keysB.single);
      expect(keysA.first.label, 'Gewürztraminer');
    });

    test('price bands carry the currency and sort by band', () {
      final w = indexWine(1);
      GroupKey band(String amount, CurrencyCode c) =>
          Dimension.priceBand.keysOf((
            wine: w,
            tasting: tasting(w, price: Money.tryParse(amount, c)),
          )).single;
      expect(band('9.99', aud).label, 'AUD under 15');
      expect(band('15', aud).label, 'AUD 15 to 30');
      expect(band('59', aud).label, 'AUD 30 to 60');
      expect(band('60', aud).label, 'AUD 60+');
      expect(band('20', usd), isNot(band('20', aud)));
      expect(
        band('80', aud).sortKey.compareTo(band('20', aud).sortKey),
        greaterThan(0),
      );
    });

    test('unrecorded values yield no key; NV sorts after years', () {
      final w = indexWine(1, type: null, region: null, country: null);
      final e = (wine: w, tasting: tasting(w));
      for (final d in [
        Dimension.type,
        Dimension.region,
        Dimension.country,
        Dimension.vintage,
        Dimension.priceBand,
      ]) {
        expect(d.keysOf(e), isEmpty, reason: d.name);
      }
      final nv = Dimension.vintage.keysOf((
        wine: w,
        tasting: tasting(w, vintage: const NonVintage()),
      )).single;
      final y = Dimension.vintage.keysOf((
        wine: w,
        tasting: tasting(w, vintage: const VintageYear(2019)),
      )).single;
      expect(nv.sortKey.compareTo(y.sortKey), greaterThan(0));
    });
  });

  group('computeStats', () {
    final syrah = indexWine(1, grapes: ['Syrah']);
    final blend = indexWine(
      2,
      grapes: ['Grenache', 'Syrah'],
      country: const Country('ES', 'Spain'),
    );
    final white = indexWine(3, type: WineType.white, grapes: ['Riesling']);
    final j = journalOf([
      (syrah, tasting(syrah, tenths: 40, at: DateTime(2026, 1, 10).toUtc())),
      (syrah, tasting(syrah, tenths: 30, at: DateTime(2026, 1, 20).toUtc())),
      (
        blend,
        tasting(
          blend,
          tenths: 45,
          at: DateTime(2026, 3, 5).toUtc(),
          sweetness: Sweetness.dry,
        ),
      ),
      (
        white,
        tasting(
          white,
          tenths: 50,
          at: DateTime(2026, 3, 9).toUtc(),
          sweetness: Sweetness.offDry,
        ),
      ),
    ]);
    final stats = computeStats(j.feed);

    test('overall tally and unique wines', () {
      expect(stats.overall.count, 4);
      expect(stats.overall.mean, closeTo(4.125, 1e-9));
      expect(stats.uniqueWines, 3);
    });

    test('monthly series is oldest first with local months', () {
      expect(stats.overTime.map((m) => m.month), [
        DateTime(2026, 1),
        DateTime(2026, 3),
      ]);
      expect(stats.overTime.first.tally.mean, closeTo(3.5, 1e-9));
    });

    test('a blend counts once under each grape', () {
      final grapes = {for (final g in stats.by[Dimension.grape]!) g.key.id: g};
      expect(grapes['syrah']!.tally.count, 3);
      expect(grapes['syrah']!.uniqueWines, 2);
      expect(grapes['grenache']!.tally.count, 1);
      expect(stats.by[Dimension.grape]!.first.key.id, 'syrah');
    });

    test('top wines by mean, score bins, and sweetness counts', () {
      expect(stats.topWines.first.wine.id, white.id);
      expect(stats.topWines.last.wine.id, syrah.id);
      expect(stats.scoreBins, hasLength(9));
      expect(stats.scoreBins.last, (fromTenths: 50, count: 1));
      expect(stats.scoreBins[4], (fromTenths: 30, count: 1));
      expect(stats.sweetness[Sweetness.dry], 1);
      expect(stats.sweetness[Sweetness.sweet], 0);
    });

    test('empty input yields zeros', () {
      final empty = computeStats(const []);
      expect(empty.overall.count, 0);
      expect(empty.overall.mean, 0);
      expect(empty.overTime, isEmpty);
    });

    test('feed facets filter by dimension keys and text', () {
      final spain = filterFeed(
        j,
        const FeedFilter(
          facets: {
            Dimension.country: {'ES'},
          },
        ),
      );
      expect(spain.single.wine.id, blend.id);
      final both = filterFeed(
        j,
        const FeedFilter(
          facets: {
            Dimension.grape: {'syrah'},
            Dimension.country: {'FR'},
          },
        ),
      );
      expect(both, hasLength(2));
      expect(
        filterFeed(j, const FeedFilter(text: 'riesl')).single.wine.id,
        white.id,
      );
      expect(
        filterFeed(j, FeedFilter(minScore: Score.fromTenths(45))),
        hasLength(2),
      );
    });

    test('FeedFilter equality ignores empty facet sets and order', () {
      expect(const FeedFilter(facets: {Dimension.type: {}}), FeedFilter.none);
      expect(
        const FeedFilter(
          facets: {
            Dimension.grape: {'a', 'b'},
          },
        ),
        const FeedFilter(
          facets: {
            Dimension.grape: {'b', 'a'},
          },
        ),
      );
      expect(
        FeedFilter.none
            .toggle(Dimension.type, 'red')
            .toggle(Dimension.type, 'red'),
        FeedFilter.none,
      );
    });
  });
}
