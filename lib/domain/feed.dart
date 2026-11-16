import 'aroma_wheel_data.dart';
import 'dimension.dart';
import 'fold.dart';
import 'journal.dart';
import 'tasting.dart';

/// What the journal feed shows. A value with `==`, so it can key a provider.
final class FeedFilter {
  const FeedFilter({
    this.text = '',
    this.facets = const {},
    this.from,
    this.to,
    this.minScore,
    this.maxScore,
  });

  static const none = FeedFilter();

  /// Matched against wine, winery, grapes, region, country, where, notes,
  /// and descriptor labels.
  final String text;

  /// [GroupKey.id]s per dimension: AND across dimensions, OR within one.
  final Map<Dimension, Set<String>> facets;

  /// Inclusive local-time bounds on the tasting date.
  final DateTime? from;
  final DateTime? to;
  final Score? minScore;
  final Score? maxScore;

  bool get isActive => this != none;

  /// True when anything but the free text narrows the feed.
  bool get hasRefinements =>
      facets.values.any((s) => s.isNotEmpty) ||
      from != null ||
      to != null ||
      minScore != null ||
      maxScore != null;

  FeedFilter copyWith({
    String? text,
    Map<Dimension, Set<String>>? facets,
    DateTime? Function()? from,
    DateTime? Function()? to,
    Score? Function()? minScore,
    Score? Function()? maxScore,
  }) => FeedFilter(
    text: text ?? this.text,
    facets: facets ?? this.facets,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
    minScore: minScore != null ? minScore() : this.minScore,
    maxScore: maxScore != null ? maxScore() : this.maxScore,
  );

  /// Same filter with one facet value toggled.
  FeedFilter toggle(Dimension d, String keyId) {
    final next = {
      for (final e in facets.entries) e.key: {...e.value},
    };
    final set = next[d] ??= {};
    if (!set.remove(keyId)) set.add(keyId);
    if (set.isEmpty) next.remove(d);
    return copyWith(facets: next);
  }

  @override
  bool operator ==(Object other) =>
      other is FeedFilter &&
      other.text == text &&
      other.from == from &&
      other.to == to &&
      other.minScore == minScore &&
      other.maxScore == maxScore &&
      _sameFacets(other.facets, facets);

  @override
  int get hashCode => Object.hash(
    text,
    from,
    to,
    minScore,
    maxScore,
    Object.hashAllUnordered([
      for (final e in facets.entries)
        if (e.value.isNotEmpty)
          Object.hash(e.key, Object.hashAllUnordered(e.value)),
    ]),
  );
}

bool _sameFacets(Map<Dimension, Set<String>> a, Map<Dimension, Set<String>> b) {
  Map<Dimension, Set<String>> live(Map<Dimension, Set<String>> m) => {
    for (final e in m.entries)
      if (e.value.isNotEmpty) e.key: e.value,
  };
  final la = live(a);
  final lb = live(b);
  if (la.length != lb.length) return false;
  for (final e in la.entries) {
    final other = lb[e.key];
    if (other == null ||
        other.length != e.value.length ||
        !other.containsAll(e.value)) {
      return false;
    }
  }
  return true;
}

/// The feed entries [filter] keeps, newest first.
List<Entry> filterFeed(Journal journal, FeedFilter filter) {
  if (!filter.isActive) return journal.feed;
  final words = fold(filter.text).split(' ').where((w) => w.isNotEmpty);
  return [
    for (final e in journal.feed)
      if (_matches(e, filter, words)) e,
  ];
}

bool _matches(Entry e, FeedFilter f, Iterable<String> words) {
  final t = e.tasting;
  final local = t.tastedAt.toLocal();
  final from = f.from;
  final to = f.to;
  if (from != null && local.isBefore(from)) return false;
  if (to != null && local.isAfter(to)) return false;
  final min = f.minScore;
  final max = f.maxScore;
  if (min != null && t.score.tenths < min.tenths) return false;
  if (max != null && t.score.tenths > max.tenths) return false;

  for (final MapEntry(key: dimension, value: wanted) in f.facets.entries) {
    if (wanted.isEmpty) continue;
    if (!dimension.keysOf(e).any((k) => wanted.contains(k.id))) return false;
  }

  if (words.isEmpty) return true;
  final haystack = fold(
    [
      e.wine.name,
      e.wine.winery,
      ...e.wine.grapes,
      e.wine.region,
      e.wine.country?.name,
      t.place,
      t.notes,
      for (final d in t.descriptors) aromaWheel.resolve(d).label,
    ].whereType<String>().join(' '),
  );
  return words.every(haystack.contains);
}
