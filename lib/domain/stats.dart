import 'dimension.dart';
import 'ids.dart';
import 'journal.dart';
import 'scales.dart';
import 'wine.dart';

final class Tally {
  const Tally(this.count, this.tenthsSum);
  static const zero = Tally(0, 0);

  final int count;
  final int tenthsSum;

  /// Mean overall score, 0 when [count] is 0.
  double get mean => count == 0 ? 0 : tenthsSum / count / 10;

  Tally plus(int tenths) => Tally(count + 1, tenthsSum + tenths);
}

final class GroupStat {
  const GroupStat(this.key, this.tally, this.uniqueWines);
  final GroupKey key;
  final Tally tally;
  final int uniqueWines;
}

typedef MonthTally = ({DateTime month, Tally tally});
typedef WineTally = ({Wine wine, Tally tally});

typedef ScoreBin = ({int fromTenths, int count});

final class JournalStats {
  const JournalStats({
    required this.overall,
    required this.uniqueWines,
    required this.overTime,
    required this.by,
    required this.topWines,
    required this.scoreBins,
    required this.sweetness,
  });

  final Tally overall;
  final int uniqueWines;

  /// Local calendar months with at least one tasting, oldest first.
  final List<MonthTally> overTime;

  /// Every [Dimension], groups sorted by count then mean, both descending.
  final Map<Dimension, List<GroupStat>> by;

  /// Wines by mean score, ties by count, at most ten.
  final List<WineTally> topWines;

  /// Nine half-point bins: 1.0-1.4, 1.5-1.9, ..., 4.5-4.9, and 5.0.
  final List<ScoreBin> scoreBins;
  final Map<Sweetness, int> sweetness;
}

JournalStats computeStats(Iterable<Entry> entries) {
  var overall = Tally.zero;
  final wines = <WineId, Wine>{};
  final perWine = <WineId, Tally>{};
  final months = <DateTime, Tally>{};
  final groups = {for (final d in Dimension.values) d: <GroupKey, Tally>{}};
  final groupWines = {
    for (final d in Dimension.values) d: <GroupKey, Set<WineId>>{},
  };
  final bins = List.filled(9, 0);
  final sweetness = {for (final s in Sweetness.values) s: 0};

  for (final e in entries) {
    final tenths = e.tasting.score.tenths;
    final wineId = e.wine.id;
    overall = overall.plus(tenths);
    wines[wineId] = e.wine;
    perWine[wineId] = (perWine[wineId] ?? Tally.zero).plus(tenths);

    final local = e.tasting.tastedAt.toLocal();
    final month = DateTime(local.year, local.month);
    months[month] = (months[month] ?? Tally.zero).plus(tenths);

    for (final d in Dimension.values) {
      for (final key in d.keysOf(e)) {
        groups[d]![key] = (groups[d]![key] ?? Tally.zero).plus(tenths);
        (groupWines[d]![key] ??= {}).add(wineId);
      }
    }

    bins[((tenths - 10) ~/ 5).clamp(0, 8)]++;
    final s = e.tasting.sweetness;
    if (s != null) sweetness[s] = sweetness[s]! + 1;
  }

  int byCountThenMean(Tally a, Tally b) {
    final c = b.count.compareTo(a.count);
    return c != 0 ? c : b.mean.compareTo(a.mean);
  }

  final top =
      [
        for (final MapEntry(key: id, value: tally) in perWine.entries)
          (wine: wines[id]!, tally: tally),
      ]..sort((a, b) {
        final m = b.tally.mean.compareTo(a.tally.mean);
        if (m != 0) return m;
        final c = b.tally.count.compareTo(a.tally.count);
        return c != 0 ? c : a.wine.name.compareTo(b.wine.name);
      });

  return JournalStats(
    overall: overall,
    uniqueWines: wines.length,
    overTime: [
      for (final m in months.keys.toList()..sort())
        (month: m, tally: months[m]!),
    ],
    by: {
      for (final d in Dimension.values)
        d:
            [
              for (final MapEntry(key: key, value: tally) in groups[d]!.entries)
                GroupStat(key, tally, groupWines[d]![key]!.length),
            ]..sort((a, b) {
              final c = byCountThenMean(a.tally, b.tally);
              return c != 0 ? c : a.key.sortKey.compareTo(b.key.sortKey);
            }),
    },
    topWines: top.take(10).toList(),
    scoreBins: [
      for (var i = 0; i < 9; i++) (fromTenths: 10 + i * 5, count: bins[i]),
    ],
    sweetness: sweetness,
  );
}
