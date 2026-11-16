import '../domain/glass_color.dart';
import '../domain/ids.dart';
import '../domain/journal.dart';
import '../domain/scales.dart';
import '../domain/tasting.dart';
import '../domain/wine.dart';

const currentDocVersion = 1;

typedef Doc = Map<String, Object?>;
typedef RawDocs = ({List<Doc> wines, List<Doc> tastings, List<Doc> wishlist});

typedef DocUpgrade = RawDocs Function(RawDocs docs);

const List<DocUpgrade> docUpgrades = [];

RawDocs upgradeDocs(
  RawDocs docs,
  int fromVersion, {
  List<DocUpgrade> ladder = docUpgrades,
}) {
  var out = docs;
  for (var v = fromVersion; v <= ladder.length; v++) {
    out = ladder[v - 1](out);
  }
  return out;
}

sealed class Decoded {
  const Decoded();
}

final class DecodedJournal extends Decoded {
  const DecodedJournal(this.journal);
  final Journal journal;
}

final class DecodeFailure extends Decoded {
  const DecodeFailure(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

final class NewerDocVersion extends Decoded {
  const NewerDocVersion(this.version);
  final int version;
}

abstract final class JournalCodec {
  static Doc encodeWine(Wine w) => _compact({
    'id': w.id.value,
    'name': w.name,
    'winery': w.winery,
    'type': w.type?.name,
    'grapes': w.grapes.isEmpty ? null : w.grapes,
    'region': w.region,
    'country': switch (w.country) {
      final c? => _compact({'code': c.code, 'name': c.name}),
      null => null,
    },
    'abv': w.abv,
    'typicalBody': w.typicalBody?.name,
    'typicalAcidity': w.typicalAcidity?.name,
    'provenance': switch (w.provenance) {
      FromIndex(:final id) => {'source': 'xwines', 'id': id.value},
      FromOpenFoodFacts(:final barcode) => {
        'source': 'openfoodfacts',
        'barcode': barcode.value,
      },
      EnteredByHand() => {'source': 'manual'},
    },
  });

  static Doc encodeTasting(Tasting t) => _compact({
    'id': t.id.value,
    'wineId': t.wineId.value,
    'tastedAt': t.tastedAt.toUtc().toIso8601String(),
    'score': t.score.value,
    'vintage': _encodeVintage(t.vintage),
    'color': switch (t.color) {
      final c? => {'hue': c.hue.name, 'intensity': c.intensity.name},
      null => null,
    },
    'aroma': t.aroma?.value,
    'flavor': t.flavor?.value,
    'finish': t.finish?.value,
    'finishLength': t.finishLength?.name,
    'sweetness': t.sweetness?.name,
    'body': t.body?.name,
    'acidity': t.acidity?.name,
    'tannin': t.tannin?.name,
    'descriptors': t.descriptors.isEmpty
        ? null
        : [for (final d in t.descriptors) d.value],
    'notes': t.notes.isEmpty ? null : t.notes,
    'place': t.place,
    'price': switch (t.price) {
      final p? => {'amount': p.formatAmount(), 'currency': p.currency.code},
      null => null,
    },
    'photo': t.photo?.fileName,
  });

  static Doc encodeWishlistItem(WishlistItem i) => _compact({
    'wineId': i.wineId.value,
    'addedAt': i.addedAt.toUtc().toIso8601String(),
    'vintage': _encodeVintage(i.vintage),
    'note': i.note.isEmpty ? null : i.note,
  });

  static RawDocs encodeJournal(Journal j) => (
    wines: [for (final w in j.wines.values) encodeWine(w)],
    tastings: [for (final t in j.tastings.values) encodeTasting(t)],
    wishlist: [for (final i in j.wishlist.values) encodeWishlistItem(i)],
  );

  static Decoded decode(int docVersion, RawDocs docs) {
    if (docVersion > currentDocVersion) return NewerDocVersion(docVersion);
    if (docVersion < 1) {
      return DecodeFailure('version', 'expected 1 or more, got $docVersion');
    }
    try {
      final up = upgradeDocs(docs, docVersion);
      final wines = <WineId, Wine>{};
      for (final (i, raw) in up.wines.indexed) {
        final w = _wine(_Obj(raw, 'wines[$i]'));
        if (wines.containsKey(w.id)) {
          throw _Fail('wines[$i].id', 'duplicate id ${w.id.value}');
        }
        wines[w.id] = w;
      }
      final tastings = <TastingId, Tasting>{};
      for (final (i, raw) in up.tastings.indexed) {
        final path = 'tastings[$i]';
        final t = _tasting(_Obj(raw, path));
        if (!wines.containsKey(t.wineId)) {
          throw _Fail('$path.wineId', 'no wine ${t.wineId.value}');
        }
        if (tastings.containsKey(t.id)) {
          throw _Fail('$path.id', 'duplicate id ${t.id.value}');
        }
        tastings[t.id] = t;
      }
      final wishlist = <WineId, WishlistItem>{};
      for (final (i, raw) in up.wishlist.indexed) {
        final path = 'wishlist[$i]';
        final item = _wishlistItem(_Obj(raw, path));
        if (!wines.containsKey(item.wineId)) {
          throw _Fail('$path.wineId', 'no wine ${item.wineId.value}');
        }
        wishlist[item.wineId] = item;
      }
      return DecodedJournal(Journal(wines, tastings, wishlist));
    } on _Fail catch (f) {
      return DecodeFailure(f.path, f.message);
    }
  }
}

const corkFileFormat = 'cork.journal';

Doc encodeJournalFile(
  Journal journal, {
  required DateTime exportedAt,
  required String appVersion,
}) {
  final docs = JournalCodec.encodeJournal(journal);
  return {
    'format': corkFileFormat,
    'version': currentDocVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'wines': docs.wines,
    'tastings': docs.tastings,
    'wishlist': docs.wishlist,
  };
}

sealed class FileDecoded {
  const FileDecoded();
}

final class FileJournal extends FileDecoded {
  const FileJournal(this.journal);
  final Journal journal;
}

final class NotACorkFile extends FileDecoded {
  const NotACorkFile();
}

final class FileTooNew extends FileDecoded {
  const FileTooNew(this.version);
  final int version;
}

final class FileMalformed extends FileDecoded {
  const FileMalformed(this.path, this.message);
  final String path;
  final String message;
}

FileDecoded decodeJournalFile(Object? json) {
  if (json is! Map || json['format'] != corkFileFormat) {
    return const NotACorkFile();
  }
  final version = json['version'];
  if (version is! int) return const FileMalformed('version', 'missing');
  List<Doc> docs(String key) => switch (json[key]) {
    null => const [],
    final List l when l.every((e) => e is Map) => [
      for (final e in l) (e as Map).cast<String, Object?>(),
    ],
    _ => throw const FormatException(),
  };
  final RawDocs raw;
  try {
    raw = (
      wines: docs('wines'),
      tastings: docs('tastings'),
      wishlist: docs('wishlist'),
    );
  } on FormatException {
    return const FileMalformed(
      '',
      'wines, tastings, and wishlist must be lists',
    );
  }
  return switch (JournalCodec.decode(version, raw)) {
    DecodedJournal(:final journal) => FileJournal(journal),
    NewerDocVersion(:final version) => FileTooNew(version),
    DecodeFailure(:final path, :final message) => FileMalformed(path, message),
  };
}

Object? _encodeVintage(Vintage? v) => switch (v) {
  VintageYear(:final year) => year,
  NonVintage() => 'NV',
  null => null,
};

Doc _compact(Map<String, Object?> m) => {
  for (final e in m.entries)
    if (e.value != null) e.key: e.value,
};

Wine _wine(_Obj o) {
  final provenance = _provenance(o.obj('provenance'));
  final id = WineId(o.str('id'));
  final expected = switch (provenance) {
    FromIndex(id: final x) => WineId.forIndex(x),
    FromOpenFoodFacts(:final barcode) => WineId.forBarcode(barcode),
    EnteredByHand() => null,
  };
  if (expected != null && expected != id) {
    throw _Fail('${o.path}.id', 'expected ${expected.value}, got ${id.value}');
  }
  if (expected == null && !id.value.startsWith('m:')) {
    throw _Fail('${o.path}.id', 'a manual wine id starts with m:');
  }
  final country = o.optObj('country');
  return Wine(
    id: id,
    name: o.str('name'),
    provenance: provenance,
    winery: o.optStr('winery'),
    type: o.optEnum('type', WineType.values),
    grapes: o.strList('grapes'),
    region: o.optStr('region'),
    country: country == null
        ? null
        : Country(country.optStr('code'), country.str('name')),
    abv: o.optNum('abv')?.toDouble(),
    typicalBody: o.optEnum('typicalBody', Level.values),
    typicalAcidity: o.optEnum('typicalAcidity', Level.values),
  );
}

Provenance _provenance(_Obj o) => switch (o.str('source')) {
  'xwines' => FromIndex(IndexWineId(o.integer('id'))),
  'openfoodfacts' => FromOpenFoodFacts(Barcode(o.str('barcode'))),
  'manual' => const EnteredByHand(),
  final other => throw _Fail('${o.path}.source', 'unknown source "$other"'),
};

Tasting _tasting(_Obj o) {
  final color = o.optObj('color');
  final price = o.optObj('price');
  Stars? stars(String key) {
    final v = o.optInt(key);
    if (v == null) return null;
    if (v < 1 || v > 5) throw _Fail('${o.path}.$key', 'expected 1..5, got $v');
    return Stars(v);
  }

  final photo = o.optStr('photo');
  return Tasting(
    id: TastingId(o.str('id')),
    wineId: WineId(o.str('wineId')),
    tastedAt: o.instant('tastedAt'),
    score: switch (Score.tryParse(o.number('score'))) {
      final s? => s,
      null => throw _Fail(
        '${o.path}.score',
        'expected 1.0..5.0 in 0.1 steps, got ${o.number('score')}',
      ),
    },
    vintage: o.optVintage('vintage'),
    color: color == null
        ? null
        : GlassColor(
            color.enumValue('hue', GlassHue.values),
            color.enumValue('intensity', GlassIntensity.values),
          ),
    aroma: stars('aroma'),
    flavor: stars('flavor'),
    finish: stars('finish'),
    finishLength: o.optEnum('finishLength', FinishLength.values),
    sweetness: o.optEnum('sweetness', Sweetness.values),
    body: o.optEnum('body', Level.values),
    acidity: o.optEnum('acidity', Level.values),
    tannin: o.optEnum('tannin', Level.values),
    descriptors: {for (final d in o.strList('descriptors')) DescriptorId(d)},
    notes: o.optStr('notes') ?? '',
    place: o.optStr('place'),
    price: price == null ? null : _money(price),
    photo: photo == null
        ? null
        : PhotoRef.tryParse(photo) ??
              (throw _Fail('${o.path}.photo', 'not a photo name: $photo')),
  );
}

Money _money(_Obj o) {
  final code = o.str('currency');
  final currency =
      CurrencyCode.tryParse(code) ??
      (throw _Fail('${o.path}.currency', 'not an ISO 4217 code: $code'));
  final amount = o.str('amount');
  return Money.tryParse(amount, currency) ??
      (throw _Fail('${o.path}.amount', 'not an amount: $amount'));
}

WishlistItem _wishlistItem(_Obj o) => WishlistItem(
  wineId: WineId(o.str('wineId')),
  addedAt: o.instant('addedAt'),
  vintage: o.optVintage('vintage'),
  note: o.optStr('note') ?? '',
);

final class _Fail implements Exception {
  _Fail(this.path, this.message);
  final String path;
  final String message;
}

final class _Obj {
  _Obj(Object? raw, this.path)
    : _m = raw is Map
          ? raw.cast<String, Object?>()
          : throw _Fail(path, 'expected an object');

  final Map<String, Object?> _m;
  final String path;

  Never _bad(String key, String expected) =>
      throw _Fail('$path.$key', 'expected $expected, got ${_m[key]}');

  Object? _req(String key) => _m[key] ?? (throw _Fail('$path.$key', 'missing'));

  String str(String key) => switch (_req(key)) {
    final String s when s.isNotEmpty => s,
    _ => _bad(key, 'a non-empty string'),
  };

  String? optStr(String key) => switch (_m[key]) {
    null => null,
    final String s => s.isEmpty ? null : s,
    _ => _bad(key, 'a string'),
  };

  num number(String key) => switch (_req(key)) {
    final num n => n,
    _ => _bad(key, 'a number'),
  };

  num? optNum(String key) => switch (_m[key]) {
    null => null,
    final num n => n,
    _ => _bad(key, 'a number'),
  };

  int integer(String key) => switch (_req(key)) {
    final int n => n,
    _ => _bad(key, 'an integer'),
  };

  int? optInt(String key) => switch (_m[key]) {
    null => null,
    final int n => n,
    _ => _bad(key, 'an integer'),
  };

  List<String> strList(String key) => switch (_m[key]) {
    null => const [],
    final List l when l.every((e) => e is String) => List.unmodifiable(l),
    _ => _bad(key, 'a list of strings'),
  };

  _Obj obj(String key) => _Obj(_req(key), '$path.$key');

  _Obj? optObj(String key) => _m[key] == null ? null : obj(key);

  T enumValue<T extends Enum>(String key, List<T> values) {
    final name = str(key);
    for (final v in values) {
      if (v.name == name) return v;
    }
    throw _Fail('$path.$key', 'unknown value "$name"');
  }

  T? optEnum<T extends Enum>(String key, List<T> values) =>
      _m[key] == null ? null : enumValue(key, values);

  DateTime instant(String key) {
    final text = str(key);
    final t = DateTime.tryParse(text);
    if (t == null) throw _Fail('$path.$key', 'not an ISO 8601 time: $text');
    return t.toUtc();
  }

  Vintage? optVintage(String key) => switch (_m[key]) {
    null => null,
    'NV' => const NonVintage(),
    final int y when y >= Vintage.earliest && y <= Vintage.latest =>
      VintageYear(y),
    _ => _bad(key, 'a year or "NV"'),
  };
}
