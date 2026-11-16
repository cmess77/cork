import 'dimension.dart';
import 'journal.dart';
import 'wine.dart';

sealed class BadgeRule {
  const BadgeRule(this.id, this.title, this.description, this.target);
  final String id;
  final String title;

  final String description;
  final int target;
}

final class TastingCount extends BadgeRule {
  const TastingCount(super.id, super.title, super.description, super.target);
}

final class DistinctKeys extends BadgeRule {
  const DistinctKeys(
    super.id,
    super.title,
    super.description,
    super.target,
    this.dimension,
  );
  final Dimension dimension;
}

final class SameKey extends BadgeRule {
  const SameKey(
    super.id,
    super.title,
    super.description,
    super.target,
    this.dimension,
  );
  final Dimension dimension;
}

final class EveryType extends BadgeRule {
  EveryType(String id, String title, String description)
    : super(id, title, description, WineType.values.length);
}

final badgeRules = <BadgeRule>[
  const TastingCount('first', 'First pour', 'Log your first tasting', 1),
  const TastingCount('t10', 'Ten down', 'Log 10 tastings', 10),
  const TastingCount('t50', 'Fifty pours', 'Log 50 tastings', 50),
  const TastingCount('t100', 'Century', 'Log 100 tastings', 100),
  const DistinctKeys(
    'g5',
    'Five grapes',
    'Taste 5 different grapes',
    5,
    Dimension.grape,
  ),
  const SameKey(
    'g10',
    'Devotee',
    'Taste 10 wines of a single grape',
    10,
    Dimension.grape,
  ),
  const DistinctKeys(
    'c3',
    'Passport',
    'Taste wines from 3 countries',
    3,
    Dimension.country,
  ),
  const DistinctKeys(
    'c10',
    'Ten countries',
    'Taste wines from 10 countries',
    10,
    Dimension.country,
  ),
  const DistinctKeys(
    'r10',
    'Regional tour',
    'Taste wines from 10 regions',
    10,
    Dimension.region,
  ),
  EveryType(
    'types',
    'Full flight',
    'Taste a red, white, rosé, sparkling, dessert, and fortified wine',
  ),
];

final class BadgeStatus {
  const BadgeStatus(this.rule, this.progress, this.earnedAt, this.counted);
  final BadgeRule rule;

  /// Clamped to `rule.target`.
  final int progress;

  /// When the tasting that crossed the line was tasted.
  final DateTime? earnedAt;

  /// The tastings that count toward the rule, oldest first.
  final List<Entry> counted;

  bool get earned => earnedAt != null;
}

List<BadgeStatus> deriveBadges(Iterable<Entry> entries) {
  final oldestFirst = entries.toList()
    ..sort((a, b) => compareEntriesNewestFirst(b, a));
  return [for (final rule in badgeRules) _replay(rule, oldestFirst)];
}

BadgeStatus _replay(BadgeRule rule, List<Entry> oldestFirst) {
  DateTime? earnedAt;
  final counted = <Entry>[];

  void check(int progress, Entry e) {
    if (earnedAt == null && progress >= rule.target) {
      earnedAt = e.tasting.tastedAt;
    }
  }

  switch (rule) {
    case TastingCount():
      for (final e in oldestFirst) {
        counted.add(e);
        check(counted.length, e);
      }
      return BadgeStatus(rule, _clamp(counted.length, rule), earnedAt, counted);

    case DistinctKeys(:final dimension):
      final seen = <GroupKey>{};
      for (final e in oldestFirst) {
        final fresh = dimension.keysOf(e).where(seen.add).toList();
        if (fresh.isNotEmpty) counted.add(e);
        check(seen.length, e);
      }
      return BadgeStatus(rule, _clamp(seen.length, rule), earnedAt, counted);

    case SameKey(:final dimension):
      final byKey = <GroupKey, List<Entry>>{};
      for (final e in oldestFirst) {
        for (final key in dimension.keysOf(e)) {
          final list = byKey[key] ??= [];
          list.add(e);
          check(list.length, e);
        }
      }
      final best = byKey.values.fold<List<Entry>>(
        const [],
        (a, b) => b.length > a.length ? b : a,
      );
      return BadgeStatus(rule, _clamp(best.length, rule), earnedAt, best);

    case EveryType():
      final seen = <WineType>{};
      for (final e in oldestFirst) {
        final type = e.wine.type;
        if (type != null && seen.add(type)) counted.add(e);
        check(seen.length, e);
      }
      return BadgeStatus(rule, _clamp(seen.length, rule), earnedAt, counted);
  }
}

int _clamp(int progress, BadgeRule rule) =>
    progress > rule.target ? rule.target : progress;

List<BadgeRule> newlyEarned(Journal before, Journal after) {
  final had = {
    for (final s in deriveBadges(before.feed))
      if (s.earned) s.rule.id,
  };
  return [
    for (final s in deriveBadges(after.feed))
      if (s.earned && !had.contains(s.rule.id)) s.rule,
  ];
}
