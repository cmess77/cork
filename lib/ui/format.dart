import 'package:intl/intl.dart';

import '../domain/dimension.dart';
import '../domain/feed.dart';
import '../domain/fold.dart';
import '../domain/journal.dart';
import '../domain/tasting.dart';
import '../domain/wine.dart';

final _day = DateFormat('MMM d');
final _dayYear = DateFormat('MMM d, y');
final _month = DateFormat('MMMM y');
final _time = DateFormat.jm();

String dayLabel(DateTime utc) {
  final local = utc.toLocal();
  final today = DateTime.now();
  return local.year == today.year ? _day.format(local) : _dayYear.format(local);
}

String fullDate(DateTime t) => _dayYear.format(t.toLocal());

String timeLabel(DateTime t) => _time.format(t.toLocal());

String monthHeading(DateTime t) => _month.format(t.toLocal()).toUpperCase();

String wineryAndVintage(Wine wine, Vintage? vintage) =>
    [wine.winery, vintage?.format()].whereType<String>().join(' · ');

String placeOf(Wine wine) =>
    [wine.region, wine.country?.name].whereType<String>().join(', ');

String wineSubtitle(Wine wine) => [
  wine.winery,
  placeOf(wine),
].where((s) => s != null && s.isNotEmpty).join(' · ');

String whenAndWhere(Tasting t) =>
    [dayLabel(t.tastedAt), t.place].whereType<String>().join(' · ');

String countLabel(int n, String one) => '$n ${n == 1 ? one : '${one}s'}';

String summaryLine(int tastings, int wines, double mean) => [
  countLabel(tastings, 'tasting'),
  countLabel(wines, 'wine'),
  if (tastings > 0) 'avg ${mean.toStringAsFixed(1)}',
].join(' · ');

/// Entries grouped by local calendar month, newest month first.
List<(DateTime month, List<Entry> entries)> byMonth(List<Entry> feed) {
  final out = <(DateTime, List<Entry>)>[];
  for (final e in feed) {
    final local = e.tasting.tastedAt.toLocal();
    final month = DateTime(local.year, local.month);
    if (out.isEmpty || out.last.$1 != month) out.add((month, []));
    out.last.$2.add(e);
  }
  return out;
}

typedef FeedSection = ({String? heading, List<Entry> entries});

/// [feed] (newest first) ordered and headed for [sort]. Rating and name are
/// one unheaded run. A dimension heads a section per key, in key order,
/// newest first inside; a blend shows under each of its grapes, and entries
/// with nothing recorded close the list under "Not recorded".
List<FeedSection> sectionFeed(List<Entry> feed, FeedSort sort) {
  int newest(Entry a, Entry b) =>
      b.tasting.tastedAt.compareTo(a.tasting.tastedAt);
  switch (sort) {
    case ByDate(:final newestFirst):
      final months = byMonth(newestFirst ? feed : feed.reversed.toList());
      return [
        for (final (month, entries) in months)
          (heading: monthHeading(month), entries: entries),
      ];
    case ByScore():
      final sorted = [...feed]
        ..sort((a, b) {
          final c = b.tasting.score.tenths.compareTo(a.tasting.score.tenths);
          return c != 0 ? c : newest(a, b);
        });
      return [(heading: null, entries: sorted)];
    case ByName():
      final sorted = [...feed]
        ..sort((a, b) {
          final c = fold(a.wine.name).compareTo(fold(b.wine.name));
          return c != 0 ? c : newest(a, b);
        });
      return [(heading: null, entries: sorted)];
    case ByDimension(:final dimension):
      final groups = <GroupKey, List<Entry>>{};
      final unrecorded = <Entry>[];
      for (final e in feed) {
        final keys = dimension.keysOf(e).toList();
        if (keys.isEmpty) unrecorded.add(e);
        for (final k in keys) {
          (groups[k] ??= []).add(e);
        }
      }
      final keys = groups.keys.toList()
        ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
      return [
        for (final k in keys)
          (heading: k.label.toUpperCase(), entries: groups[k]!),
        if (unrecorded.isNotEmpty)
          (heading: 'NOT RECORDED', entries: unrecorded),
      ];
  }
}
