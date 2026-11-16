// Ordinal scales of the WSET Systematic Approach. Enum `.name` is the wire
// name stored in the journal; `label` is what the screen shows.

enum Sweetness {
  boneDry('Bone dry'),
  dry('Dry'),
  offDry('Off-dry'),
  mediumSweet('Medium-sweet'),
  sweet('Sweet'),
  luscious('Luscious');

  const Sweetness(this.label);
  final String label;
}

enum FinishLength {
  short('Short'),
  medium('Medium'),
  long('Long');

  const FinishLength(this.label);
  final String label;
}

/// Five-point scale for body, acidity, and tannin.
enum Level {
  low('Low', 'Low'),
  mediumMinus('Medium-', 'Med-'),
  medium('Medium', 'Medium'),
  mediumPlus('Medium+', 'Med+'),
  high('High', 'High');

  const Level(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}
