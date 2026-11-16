import 'dart:convert';
import 'dart:io';

import 'package:cork/data/journal_codec.dart';
import 'package:cork/domain/glass_color.dart';
import 'package:cork/domain/ids.dart';
import 'package:cork/domain/journal.dart';
import 'package:cork/domain/scales.dart';
import 'package:cork/domain/tasting.dart';
import 'package:cork/domain/wine.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> fixture() =>
    jsonDecode(File('test/fixtures/journal_v1.json').readAsStringSync())
        as Map<String, Object?>;

Journal decodeFixture([Map<String, Object?>? json]) =>
    switch (decodeJournalFile(json ?? fixture())) {
      FileJournal(:final journal) => journal,
      final other => throw StateError('$other'),
    };

FileMalformed malformed(void Function(Map<String, Object?> json) edit) {
  final json = fixture();
  edit(json);
  return decodeJournalFile(json) as FileMalformed;
}

Map<String, Object?> tasting0(Map<String, Object?> json) =>
    (json['tastings'] as List).first as Map<String, Object?>;

void main() {
  test('the v1 fixture decodes into the domain', () {
    final j = decodeFixture();
    expect(j.wines, hasLength(3));
    final t = j.tastings[const TastingId('8c1f4be2a07d4e6f9b3c2d1e0f5a6b7c')]!;
    expect(t.score.tenths, 42);
    expect(t.vintage, const VintageYear(2019));
    expect(t.color, const GlassColor(GlassHue.ruby, GlassIntensity.deep));
    expect(t.body, Level.mediumPlus);
    expect(t.price, const Money(3200, CurrencyCode('AUD')));
    expect(t.tastedAt, DateTime.utc(2026, 11, 14, 8, 30));
    final off = j.wines[const WineId('off:3760123456789')]!;
    expect(off.type, isNull);
    expect(
      (off.provenance as FromOpenFoodFacts).barcode.value,
      '3760123456789',
    );
    expect(j.wines[const WineId('m:5f0c9a2e7b1d4c3a')]!.country!.code, isNull);
    expect(j.wishlist.values.single.vintage, const NonVintage());
  });

  test('encoding the decoded fixture reproduces its records exactly', () {
    final json = fixture();
    final again = encodeJournalFile(
      decodeFixture(json),
      exportedAt: DateTime.parse(json['exportedAt']! as String),
      appVersion: json['appVersion']! as String,
    );
    expect(jsonDecode(jsonEncode(again)), json);
  });

  test('failures name the path and the problem', () {
    expect(
      malformed((j) => tasting0(j)['score'] = 7).path,
      'tastings[0].score',
    );
    expect(
      malformed((j) => tasting0(j)['sweetness'] = 'semi').message,
      'unknown value "semi"',
    );
    expect(
      malformed((j) => tasting0(j)['wineId'] = 'xw:1').path,
      'tastings[0].wineId',
    );
    expect(
      malformed((j) => tasting0(j)['aroma'] = 6).path,
      'tastings[0].aroma',
    );
    expect(malformed((j) => tasting0(j).remove('tastedAt')).message, 'missing');
    expect(
      malformed(
        (j) => ((j['wines'] as List).first as Map)['id'] = 'xw:999',
      ).path,
      'wines[0].id',
    );
  });

  test('unknown keys are ignored and unknown descriptor ids kept', () {
    final json = fixture();
    tasting0(json)['futureField'] = true;
    tasting0(json)['descriptors'] = ['fruit.exotic.durian'];
    final t = decodeFixture(
      json,
    ).tastings.values.firstWhere((t) => t.descriptors.isNotEmpty);
    expect(t.descriptors, {const DescriptorId('fruit.exotic.durian')});
  });

  test('a file from a newer Cork is refused, not misread', () {
    final json = fixture()..['version'] = currentDocVersion + 1;
    expect(decodeJournalFile(json), isA<FileTooNew>());
    expect(decodeJournalFile({'hello': 1}), isA<NotACorkFile>());
    expect(decodeJournalFile([1, 2]), isA<NotACorkFile>());
  });

  test('the upgrade ladder runs each step from the stored version', () {
    final steps = <String>[];
    RawDocs tag(String name, RawDocs d) {
      steps.add(name);
      return (
        wines: [
          for (final w in d.wines) {...w, 'name': '${w['name']}+$name'},
        ],
        tastings: d.tastings,
        wishlist: d.wishlist,
      );
    }

    final ladder = <DocUpgrade>[(d) => tag('v2', d), (d) => tag('v3', d)];
    final docs = (
      wines: [
        <String, Object?>{'name': 'x'},
      ],
      tastings: <Doc>[],
      wishlist: <Doc>[],
    );
    expect(
      upgradeDocs(docs, 1, ladder: ladder).wines.single['name'],
      'x+v2+v3',
    );
    expect(upgradeDocs(docs, 2, ladder: ladder).wines.single['name'], 'x+v3');
    expect(upgradeDocs(docs, 3, ladder: ladder).wines.single['name'], 'x');
    expect(steps, ['v2', 'v3', 'v3']);
  });
}
