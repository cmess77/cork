/// Folds text for matching and grouping: lower case, Latin diacritics
/// stripped, runs of whitespace collapsed. 'Gewürz  Traminer' and
/// 'gewurz traminer' fold to the same key.
String fold(String text) {
  final out = StringBuffer();
  var pendingSpace = false;
  for (final rune in text.trim().toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    if (ch.trim().isEmpty) {
      pendingSpace = true;
      continue;
    }
    if (pendingSpace && out.isNotEmpty) out.write(' ');
    pendingSpace = false;
    out.write(_plain[ch] ?? ch);
  }
  return out.toString();
}

const _groups = {
  'a': 'àáâãäåāăą',
  'ae': 'æ',
  'c': 'çćĉċč',
  'd': 'ďđ',
  'e': 'èéêëēĕėęě',
  'g': 'ĝğġģ',
  'h': 'ĥħ',
  'i': 'ìíîïĩīĭįı',
  'j': 'ĵ',
  'k': 'ķ',
  'l': 'ĺļľŀł',
  'n': 'ñńņňŉ',
  'o': 'òóôõöøōŏő',
  'oe': 'œ',
  'r': 'ŕŗř',
  's': 'śŝşšș',
  'ss': 'ß',
  't': 'ţťŧț',
  'u': 'ùúûüũūŭůűų',
  'w': 'ŵ',
  'y': 'ýÿŷ',
  'z': 'źżž',
};

final _plain = {
  for (final MapEntry(key: plain, value: marked) in _groups.entries)
    for (final ch in marked.split('')) ch: plain,
};
