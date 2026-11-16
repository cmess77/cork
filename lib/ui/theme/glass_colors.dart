import 'package:flutter/painting.dart';

/// WSET Systematic Approach colour families for a glass of wine.
enum GlassFamily {
  white('White'),
  rose('Rosé'),
  red('Red');

  const GlassFamily(this.label);
  final String label;

  List<GlassHue> get hues =>
      GlassHue.values.where((h) => h.family == this).toList(growable: false);
}

/// WSET intensity, judged by tilting the glass over a white surface.
enum GlassIntensity {
  pale('Pale'),
  medium('Medium'),
  deep('Deep');

  const GlassIntensity(this.label);
  final String label;
}

/// Each hue's [base] is its medium-intensity display colour, as the wine reads
/// over a white tablecloth. Pale and deep are derived in [glassDisplayColor].
enum GlassHue {
  waterWhite(GlassFamily.white, 'Water-white', Color(0xFFF1F0DE)),
  greenYellow(GlassFamily.white, 'Green-yellow', Color(0xFFE3E59A)),
  lemon(GlassFamily.white, 'Lemon', Color(0xFFEEDC7C)),
  straw(GlassFamily.white, 'Straw', Color(0xFFE6CB6E)),
  gold(GlassFamily.white, 'Gold', Color(0xFFDBAE3E)),
  deepGold(GlassFamily.white, 'Deep gold', Color(0xFFC88F27)),
  amber(GlassFamily.white, 'Amber', Color(0xFFB56E1D)),
  whiteBrown(GlassFamily.white, 'Brown', Color(0xFF86521F)),
  palePink(GlassFamily.rose, 'Pale pink', Color(0xFFF0C1BC)),
  salmon(GlassFamily.rose, 'Salmon', Color(0xFFEC9C84)),
  onionSkin(GlassFamily.rose, 'Onion-skin', Color(0xFFD68E66)),
  deepPink(GlassFamily.rose, 'Deep pink', Color(0xFFD65774)),
  purple(GlassFamily.red, 'Purple', Color(0xFF52183D)),
  ruby(GlassFamily.red, 'Ruby', Color(0xFF7D1429)),
  garnet(GlassFamily.red, 'Garnet', Color(0xFF7A2B25)),
  tawny(GlassFamily.red, 'Tawny', Color(0xFF9B5A31)),
  redBrown(GlassFamily.red, 'Brown', Color(0xFF693A22));

  const GlassHue(this.family, this.label, this.base);
  final GlassFamily family;
  final String label;
  final Color base;
}

/// The white a swatch sits on, so colour is judged the WSET way in either theme.
const Color glassTablecloth = Color(0xFFF7F6F1);

Color glassDisplayColor(GlassHue hue, GlassIntensity intensity) {
  switch (intensity) {
    case GlassIntensity.medium:
      return hue.base;
    case GlassIntensity.pale:
      // A pale wine lets more of the white show through the bowl.
      final towardCloth = hue.family == GlassFamily.red ? 0.42 : 0.55;
      return Color.lerp(hue.base, glassTablecloth, towardCloth)!;
    case GlassIntensity.deep:
      final hsl = HSLColor.fromColor(hue.base);
      final darken = hue.family == GlassFamily.red ? 0.09 : 0.14;
      return hsl
          .withLightness((hsl.lightness - darken).clamp(0.06, 1.0))
          .withSaturation((hsl.saturation + 0.08).clamp(0.0, 1.0))
          .toColor();
  }
}
