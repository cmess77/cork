import 'ids.dart';
import 'scales.dart';

enum WineType {
  red('Red'),
  white('White'),
  rose('Rosé'),
  sparkling('Sparkling'),
  dessert('Dessert'),
  fortified('Fortified');

  const WineType(this.label);
  final String label;
}

sealed class Provenance {
  const Provenance();
}

final class FromIndex extends Provenance {
  const FromIndex(this.id);
  final IndexWineId id;
}

final class FromOpenFoodFacts extends Provenance {
  const FromOpenFoodFacts(this.barcode);
  final Barcode barcode;
}

final class EnteredByHand extends Provenance {
  const EnteredByHand();
}

final class Country {
  const Country(this.code, this.name);

  final String? code;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Country && other.code == code && other.name == name;

  @override
  int get hashCode => Object.hash(code, name);
}

/// Invariant: [id] derives from [provenance] (random for [EnteredByHand]).
final class Wine {
  const Wine({
    required this.id,
    required this.name,
    required this.provenance,
    this.winery,
    this.type,
    this.grapes = const [],
    this.region,
    this.country,
    this.abv,
    this.typicalBody,
    this.typicalAcidity,
  });

  factory Wine.manual({
    required WineId id,
    required String name,
    required WineType type,
    String? winery,
    List<String> grapes = const [],
    String? region,
    Country? country,
  }) => Wine(
    id: id,
    name: name,
    provenance: const EnteredByHand(),
    winery: winery,
    type: type,
    grapes: grapes,
    region: region,
    country: country,
  );

  final WineId id;
  final String name;
  final Provenance provenance;
  final String? winery;

  /// Null only for Open Food Facts hits whose category does not say.
  final WineType? type;
  final List<String> grapes;
  final String? region;
  final Country? country;
  final double? abv;

  final Level? typicalBody;
  final Level? typicalAcidity;

  Wine copyWith({
    String? name,
    String? Function()? winery,
    WineType? Function()? type,
    List<String>? grapes,
    String? Function()? region,
    Country? Function()? country,
  }) => Wine(
    id: id,
    name: name ?? this.name,
    provenance: provenance,
    winery: winery != null ? winery() : this.winery,
    type: type != null ? type() : this.type,
    grapes: grapes ?? this.grapes,
    region: region != null ? region() : this.region,
    country: country != null ? country() : this.country,
    abv: abv,
    typicalBody: typicalBody,
    typicalAcidity: typicalAcidity,
  );
}
