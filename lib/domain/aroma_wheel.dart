import 'ids.dart';

enum AromaFamily {
  fruit('Fruit'),
  floral('Floral'),
  herbal('Herbal'),
  spice('Spice'),
  earth('Earth'),
  oak('Oak'),
  yeast('Yeast'),
  oxidative('Oxidative');

  const AromaFamily(this.label);
  final String label;
}

final class Descriptor {
  const Descriptor(this.id, this.label, this.family);
  final DescriptorId id;
  final String label;
  final AromaFamily family;
}

final class AromaSubcategory {
  const AromaSubcategory(this.label, this.descriptors);
  final String label;
  final List<Descriptor> descriptors;
}

final class AromaCategory {
  const AromaCategory(this.family, this.subcategories);
  final AromaFamily family;
  final List<AromaSubcategory> subcategories;

  String get label => family.label;
  Iterable<Descriptor> get descriptors =>
      subcategories.expand((s) => s.descriptors);
}

final class AromaWheel {
  AromaWheel(this.categories)
    : _byId = {
        for (final c in categories)
          for (final d in c.descriptors) d.id: d,
      };

  final List<AromaCategory> categories;
  final Map<DescriptorId, Descriptor> _byId;

  Iterable<Descriptor> get descriptors => _byId.values;

  Descriptor resolve(DescriptorId id) =>
      _byId[id] ??
      Descriptor(id, _labelFromSlug(id.value), _familyFromSlug(id.value));

  bool knows(DescriptorId id) => _byId.containsKey(id);
}

String _labelFromSlug(String slug) {
  final last = slug.split('.').last.replaceAll('-', ' ');
  return last.isEmpty ? slug : last[0].toUpperCase() + last.substring(1);
}

AromaFamily _familyFromSlug(String slug) {
  final head = slug.split('.').first;
  return AromaFamily.values.firstWhere(
    (f) => f.name == head,
    orElse: () => AromaFamily.oxidative,
  );
}
