import 'aroma_wheel.dart';
import 'ids.dart';

/// Ids are `family.subcategory-slug.descriptor-slug`. They are stored in
/// journals, so `test/domain/aroma_wheel_test.dart` keeps this list append-only.
final aromaWheel = AromaWheel([
  _category(AromaFamily.fruit, {
    'Citrus': ['Lemon', 'Lime', 'Grapefruit', 'Orange peel'],
    'Green fruit': ['Green apple', 'Pear', 'Gooseberry', 'Grape'],
    'Stone fruit': ['Peach', 'Apricot', 'Nectarine'],
    'Tropical fruit': [
      'Pineapple',
      'Mango',
      'Passion fruit',
      'Lychee',
      'Banana',
      'Melon',
    ],
    'Red fruit': [
      'Strawberry',
      'Raspberry',
      'Red cherry',
      'Redcurrant',
      'Cranberry',
      'Pomegranate',
    ],
    'Black fruit': [
      'Blackberry',
      'Blackcurrant',
      'Black cherry',
      'Plum',
      'Blueberry',
    ],
    'Dried fruit': ['Raisin', 'Fig', 'Prune', 'Date', 'Dried apricot'],
  }),
  _category(AromaFamily.floral, {
    'Flowers': [
      'Rose',
      'Violet',
      'Elderflower',
      'Orange blossom',
      'Honeysuckle',
      'Jasmine',
      'Acacia',
      'Lavender',
    ],
  }),
  _category(AromaFamily.herbal, {
    'Green': ['Green bell pepper', 'Grass', 'Tomato leaf', 'Asparagus'],
    'Herbs': ['Mint', 'Eucalyptus', 'Thyme', 'Fennel', 'Dill', 'Sage'],
  }),
  _category(AromaFamily.spice, {
    'Sweet spice': [
      'Cinnamon',
      'Clove',
      'Nutmeg',
      'Ginger',
      'Licorice',
      'Anise',
    ],
    'Pungent spice': ['Black pepper', 'White pepper'],
  }),
  _category(AromaFamily.earth, {
    'Earth': ['Wet earth', 'Forest floor', 'Mushroom', 'Truffle', 'Wet leaves'],
    'Mineral': ['Flint', 'Wet stones', 'Chalk', 'Slate', 'Petrol'],
    'Animal': ['Leather', 'Game', 'Meat'],
  }),
  _category(AromaFamily.oak, {
    'Oak': [
      'Vanilla',
      'Toast',
      'Smoke',
      'Cedar',
      'Coconut',
      'Coffee',
      'Chocolate',
    ],
  }),
  _category(AromaFamily.yeast, {
    'Lees': ['Bread', 'Brioche', 'Biscuit', 'Yeast'],
    'Dairy': ['Butter', 'Cream', 'Yogurt'],
  }),
  _category(AromaFamily.oxidative, {
    'Nutty': ['Almond', 'Hazelnut', 'Walnut'],
    'Sweet': ['Honey', 'Toffee', 'Caramel', 'Molasses'],
    'Aged': ['Tobacco', 'Dried leaves', 'Sherry'],
  }),
]);

AromaCategory _category(
  AromaFamily family,
  Map<String, List<String>> subcategories,
) => AromaCategory(family, [
  for (final MapEntry(key: sub, value: labels) in subcategories.entries)
    AromaSubcategory(sub, [
      for (final label in labels)
        Descriptor(
          DescriptorId('${family.name}.${_slug(sub)}.${_slug(label)}'),
          label,
          family,
        ),
    ]),
]);

String _slug(String label) => label.toLowerCase().replaceAll(' ', '-');
