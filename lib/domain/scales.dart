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
