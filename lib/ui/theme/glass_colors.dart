import 'package:flutter/painting.dart';

import '../../domain/glass_color.dart';

/// The white a swatch sits on, so colour is judged the WSET way in either theme.
const Color glassTablecloth = Color(0xFFF7F6F1);

Color glassDisplayColor(GlassHue hue, GlassIntensity intensity) {
  final base = Color(hue.argb);
  switch (intensity) {
    case GlassIntensity.medium:
      return base;
    case GlassIntensity.pale:
      // A pale wine lets more of the white show through the bowl.
      final towardCloth = hue.family == GlassFamily.red ? 0.42 : 0.55;
      return Color.lerp(base, glassTablecloth, towardCloth)!;
    case GlassIntensity.deep:
      final hsl = HSLColor.fromColor(base);
      final darken = hue.family == GlassFamily.red ? 0.09 : 0.14;
      return hsl
          .withLightness((hsl.lightness - darken).clamp(0.06, 1.0))
          .withSaturation((hsl.saturation + 0.08).clamp(0.0, 1.0))
          .toColor();
  }
}
