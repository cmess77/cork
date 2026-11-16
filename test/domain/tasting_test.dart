import 'package:cork/domain/glass_color.dart';
import 'package:cork/domain/ids.dart';
import 'package:cork/domain/scales.dart';
import 'package:cork/domain/tasting.dart';
import 'package:cork/domain/wine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/builders.dart';

void main() {
  group('Score', () {
    test('parses one-decimal values from 1.0 to 5.0', () {
      expect(Score.tryParse(4.2)?.tenths, 42);
      expect(Score.tryParse(1)?.tenths, 10);
      expect(Score.tryParse(5.0)?.tenths, 50);
      expect(Score.tryParse(0.9), isNull);
      expect(Score.tryParse(5.1), isNull);
      expect(Score.tryParse(4.25), isNull);
    });

    test('formats with exactly one fractional digit', () {
      expect(Score.fromTenths(40).format(), '4.0');
      expect(Score.fromTenths(37).format(), '3.7');
      expect(Score.fromTenths(37).value, 3.7);
    });

    test('rejects tenths outside 10..50', () {
      expect(() => Score.fromTenths(9), throwsRangeError);
      expect(() => Score.fromTenths(51), throwsRangeError);
    });
  });

  test('Stars only holds 1 to 5', () {
    expect(Stars(1).value, 1);
    expect(() => Stars(0), throwsRangeError);
    expect(() => Stars(6), throwsRangeError);
  });

  group('Money', () {
    const aud = CurrencyCode('AUD');
    const jpy = CurrencyCode('JPY');
    const kwd = CurrencyCode('KWD');

    test('stores minor units per the currency exponent', () {
      expect(Money.tryParse('32', aud)?.minor, 3200);
      expect(Money.tryParse('32.5', aud)?.minor, 3250);
      expect(Money.tryParse('32,50', aud)?.minor, 3250);
      expect(Money.tryParse('1500', jpy)?.minor, 1500);
      expect(Money.tryParse('1.250', kwd)?.minor, 1250);
    });

    test('rejects negative, junk, and over-precise amounts', () {
      expect(Money.tryParse('-3', aud), isNull);
      expect(Money.tryParse('abc', aud), isNull);
      expect(Money.tryParse('3.999', aud), isNull);
      expect(Money.tryParse('15.5', jpy), isNull);
    });

    test('formats the stored decimal string', () {
      expect(const Money(3200, aud).formatAmount(), '32.00');
      expect(const Money(5, aud).formatAmount(), '0.05');
      expect(const Money(1500, jpy).formatAmount(), '1500');
      expect(const Money(1250, kwd).formatAmount(), '1.250');
    });
  });

  group('Vintage', () {
    test('parses years and NV', () {
      expect(Vintage.tryParse('2019'), const VintageYear(2019));
      expect(Vintage.tryParse(' nv '), const NonVintage());
      expect(Vintage.tryParse('19'), isNull);
      expect(Vintage.tryParse('2200'), isNull);
    });
  });

  group('TastingDraft.build', () {
    final wine = indexWine(1);
    const aud = CurrencyCode('AUD');
    TastingDraft draft() => TastingDraft.forWine(
      wine,
      now: DateTime(2026, 11, 14, 20),
      currency: aud,
    );

    test('is Invalid naming the score while it is unset', () {
      final result = draft().build();
      expect(result, isA<Invalid<Tasting>>());
      final issues = (result as Invalid<Tasting>).issues;
      expect(issues.single.field, DraftField.score);
      expect(issues.single.message, 'Set a score');
    });

    test('collects every issue with its field', () {
      final d = draft()
        ..vintageText = '20x9'
        ..priceText = 'twelve';
      final issues = (d.build() as Invalid<Tasting>).issues;
      expect(issues.map((i) => i.field), [
        DraftField.score,
        DraftField.vintage,
        DraftField.price,
      ]);
    });

    test('builds a Tasting with only a score', () {
      final d = draft()..score = Score.fromTenths(38);
      final t =
          (d.build(mintId: () => const TastingId('abc')) as Valid<Tasting>)
              .value;
      expect(t.id, const TastingId('abc'));
      expect(t.wineId, wine.id);
      expect(t.score.tenths, 38);
      expect(t.tastedAt.isUtc, isTrue);
      expect(t.vintage, isNull);
      expect(t.price, isNull);
      expect(t.place, isNull);
    });

    test('an edit round-trips every field and keeps its id', () {
      final original =
          (TastingDraft.forWine(wine, now: DateTime(2026, 3, 1), currency: aud)
                ..score = Score.fromTenths(42)
                ..vintageText = '2019'
                ..color = const GlassColor(GlassHue.ruby, GlassIntensity.deep)
                ..aroma = Stars(4)
                ..flavor = Stars(3)
                ..finish = Stars(5)
                ..finishLength = FinishLength.long
                ..sweetness = Sweetness.dry
                ..body = Level.mediumPlus
                ..acidity = Level.high
                ..tannin = Level.medium
                ..descriptors = {
                  const DescriptorId('fruit.black-fruit.blackberry'),
                }
                ..notes = '  Opened up.  '
                ..place = 'Bar Brutal'
                ..priceText = '32.5'
                ..photo = PhotoRef('${'a' * 64}.jpg'))
              .build(mintId: () => const TastingId('t1'));
      final first = (original as Valid<Tasting>).value;
      final again =
          (TastingDraft.edit(
                    first,
                    wine,
                    defaultCurrency: const CurrencyCode('USD'),
                  ).build()
                  as Valid<Tasting>)
              .value;

      expect(again.id, first.id);
      expect(again.tastedAt, first.tastedAt);
      expect(again.vintage, const VintageYear(2019));
      expect(again.color, first.color);
      expect(again.aroma, first.aroma);
      expect(again.finishLength, FinishLength.long);
      expect(again.tannin, Level.medium);
      expect(again.descriptors, first.descriptors);
      expect(again.notes, 'Opened up.');
      expect(again.place, 'Bar Brutal');
      expect(again.price, const Money(3250, aud));
      expect(again.photo, first.photo);
    });

    test('prefills structure from the wine hints', () {
      final hinted = Wine(
        id: WineId.forIndex(const IndexWineId(2)),
        name: 'Hinted',
        provenance: const FromIndex(IndexWineId(2)),
        typicalBody: Level.high,
        typicalAcidity: Level.low,
      );
      final d = TastingDraft.forWine(
        hinted,
        now: DateTime(2026),
        currency: aud,
      );
      expect(d.body, Level.high);
      expect(d.acidity, Level.low);
    });
  });

  test('GlassFamily partitions the WSET hues 8, 4, 5', () {
    expect(GlassFamily.white.hues, hasLength(8));
    expect(GlassFamily.rose.hues, hasLength(4));
    expect(GlassFamily.red.hues, hasLength(5));
    expect(
      const GlassColor(GlassHue.ruby, GlassIntensity.medium).phrase,
      'Medium ruby',
    );
  });
}
