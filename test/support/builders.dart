import 'package:cork/domain/glass_color.dart';
import 'package:cork/domain/ids.dart';
import 'package:cork/domain/journal.dart';
import 'package:cork/domain/scales.dart';
import 'package:cork/domain/tasting.dart';
import 'package:cork/domain/wine.dart';

Wine indexWine(
  int xw, {
  String? name,
  WineType? type = WineType.red,
  List<String> grapes = const ['Syrah'],
  String? winery = 'Domaine Exemple',
  String? region = 'Rhône',
  Country? country = const Country('FR', 'France'),
}) => Wine(
  id: WineId.forIndex(IndexWineId(xw)),
  name: name ?? 'Wine $xw',
  provenance: FromIndex(IndexWineId(xw)),
  type: type,
  grapes: grapes,
  winery: winery,
  region: region,
  country: country,
);

var _seq = 0;

Tasting tasting(
  Wine wine, {
  String? id,
  DateTime? at,
  int tenths = 40,
  Vintage? vintage,
  Money? price,
  Sweetness? sweetness,
  GlassColor? color,
  Set<DescriptorId> descriptors = const {},
  String notes = '',
  String? place,
}) {
  _seq++;
  return Tasting(
    id: TastingId(id ?? 't${_seq.toString().padLeft(6, '0')}'),
    wineId: wine.id,
    tastedAt: at ?? DateTime.utc(2026, 1, 1).add(Duration(days: _seq)),
    score: Score.fromTenths(tenths),
    vintage: vintage,
    price: price,
    sweetness: sweetness,
    color: color,
    descriptors: descriptors,
    notes: notes,
    place: place,
  );
}

/// A journal holding [tastings] and the wines they reference.
Journal journalOf(List<(Wine, Tasting)> pairs) => Journal.empty.apply([
  for (final (wine, t) in pairs) ...[AdoptWine(wine), SaveTasting(t)],
]);
