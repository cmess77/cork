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

/// One flat scale: a hue owns its family, so "ruby white" cannot be written.
/// [argb] is the medium-intensity display colour over a white tablecloth.
enum GlassHue {
  waterWhite(GlassFamily.white, 'Water-white', 0xFFF1F0DE),
  greenYellow(GlassFamily.white, 'Green-yellow', 0xFFE3E59A),
  lemon(GlassFamily.white, 'Lemon', 0xFFEEDC7C),
  straw(GlassFamily.white, 'Straw', 0xFFE6CB6E),
  gold(GlassFamily.white, 'Gold', 0xFFDBAE3E),
  deepGold(GlassFamily.white, 'Deep gold', 0xFFC88F27),
  amber(GlassFamily.white, 'Amber', 0xFFB56E1D),
  whiteBrown(GlassFamily.white, 'Brown', 0xFF86521F),
  palePink(GlassFamily.rose, 'Pale pink', 0xFFF0C1BC),
  salmon(GlassFamily.rose, 'Salmon', 0xFFEC9C84),
  onionSkin(GlassFamily.rose, 'Onion-skin', 0xFFD68E66),
  deepPink(GlassFamily.rose, 'Deep pink', 0xFFD65774),
  purple(GlassFamily.red, 'Purple', 0xFF52183D),
  ruby(GlassFamily.red, 'Ruby', 0xFF7D1429),
  garnet(GlassFamily.red, 'Garnet', 0xFF7A2B25),
  tawny(GlassFamily.red, 'Tawny', 0xFF9B5A31),
  redBrown(GlassFamily.red, 'Brown', 0xFF693A22);

  const GlassHue(this.family, this.label, this.argb);
  final GlassFamily family;
  final String label;
  final int argb;
}

final class GlassColor {
  const GlassColor(this.hue, this.intensity);
  final GlassHue hue;
  final GlassIntensity intensity;

  GlassFamily get family => hue.family;

  /// The WSET phrase, such as "Medium ruby".
  String get phrase => '${intensity.label} ${hue.label.toLowerCase()}';

  @override
  bool operator ==(Object other) =>
      other is GlassColor && other.hue == hue && other.intensity == intensity;

  @override
  int get hashCode => Object.hash(hue, intensity);
}
