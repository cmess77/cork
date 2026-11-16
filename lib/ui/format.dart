import 'package:intl/intl.dart';

import '../domain/journal.dart';
import '../domain/tasting.dart';
import '../domain/wine.dart';

final _day = DateFormat('MMM d');
final _dayYear = DateFormat('MMM d, y');
final _month = DateFormat('MMMM y');
final _time = DateFormat.jm();

String dayLabel(DateTime utc, {DateTime? now}) {
  final local = utc.toLocal();
  final today = now ?? DateTime.now();
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

String countLabel(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

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
