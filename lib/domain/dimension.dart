import 'fold.dart';
import 'journal.dart';
import 'tasting.dart';

final class GroupKey {
  const GroupKey(this.id, this.label, this.sortKey);
  final String id;
  final String label;
  final String sortKey;

  @override
  bool operator ==(Object other) => other is GroupKey && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'GroupKey($id)';
}

String grapeKey(String grape) => fold(grape);

/// Price band edges in major units, shared by every currency.
const priceBandEdges = [15, 30, 60];

enum Dimension {
  type('Type'),
  grape('Grape'),
  country('Country'),
  region('Region'),
  winery('Winery'),
  vintage('Vintage'),
  priceBand('Price');

  const Dimension(this.label);
  final String label;

  /// Zero, one, or many keys. A blend counts once under each of its grapes.
  /// An unrecorded value yields no key. Price bands carry the currency, so
  /// currencies never mix.
  Iterable<GroupKey> keysOf(Entry e) sync* {
    final wine = e.wine;
    final tasting = e.tasting;
    switch (this) {
      case Dimension.type:
        final type = wine.type;
        if (type != null) {
          yield GroupKey(type.name, type.label, '${type.index}');
        }
      case Dimension.grape:
        final seen = <String>{};
        for (final g in wine.grapes) {
          final id = grapeKey(g);
          if (id.isNotEmpty && seen.add(id)) yield GroupKey(id, g.trim(), id);
        }
      case Dimension.country:
        final country = wine.country;
        if (country != null) {
          final id = country.code?.toUpperCase() ?? fold(country.name);
          yield GroupKey(id, country.name, fold(country.name));
        }
      case Dimension.region:
        final region = wine.region?.trim();
        if (region != null && region.isNotEmpty) {
          yield GroupKey(fold(region), region, fold(region));
        }
      case Dimension.winery:
        final winery = wine.winery?.trim();
        if (winery != null && winery.isNotEmpty) {
          yield GroupKey(fold(winery), winery, fold(winery));
        }
      case Dimension.vintage:
        switch (tasting.vintage) {
          case VintageYear(:final year):
            yield GroupKey('$year', '$year', '$year'.padLeft(4, '0'));
          case NonVintage():
            yield const GroupKey('NV', 'NV', '9999');
          case null:
        }
      case Dimension.priceBand:
        final price = tasting.price;
        if (price != null) yield _priceBand(price);
    }
  }
}

GroupKey _priceBand(Money price) {
  final code = price.currency.code;
  final major = price.major;
  var band = priceBandEdges.indexWhere((edge) => major < edge);
  if (band == -1) band = priceBandEdges.length;
  final String label;
  if (band == 0) {
    label = '$code under ${priceBandEdges.first}';
  } else if (band == priceBandEdges.length) {
    label = '$code ${priceBandEdges.last}+';
  } else {
    label = '$code ${priceBandEdges[band - 1]} to ${priceBandEdges[band]}';
  }
  return GroupKey('$code:$band', label, '$code:$band');
}
