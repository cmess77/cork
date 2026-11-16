import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup.dart';
import '../data/journal_store.dart';
import '../data/photos.dart';
import '../data/settings_store.dart';
import '../domain/badges.dart';
import '../domain/feed.dart';
import '../domain/ids.dart';
import '../domain/journal.dart';
import '../domain/stats.dart';
import '../lookup/wine_lookup.dart';

final journalStoreProvider = Provider<JournalStore>(
  (_) => throw UnimplementedError('journalStoreProvider'),
);
final wineLookupProvider = Provider<WineLookup>(
  (_) => throw UnimplementedError('wineLookupProvider'),
);
final photoStoreProvider = Provider<PhotoStore>(
  (_) => throw UnimplementedError('photoStoreProvider'),
);
final backupProvider = Provider<Backup>(
  (_) => throw UnimplementedError('backupProvider'),
);
final settingsStoreProvider = Provider<SettingsStore>(
  (_) => throw UnimplementedError('settingsStoreProvider'),
);

T _follow<T>(Ref ref, Listenable notifier, T value) {
  void changed() => ref.invalidateSelf();
  notifier.addListener(changed);
  ref.onDispose(() => notifier.removeListener(changed));
  return value;
}

final journalProvider = Provider<Journal>((ref) {
  final store = ref.watch(journalStoreProvider);
  return _follow(ref, store, store.journal);
});

typedef Settings = ({CurrencyCode currency, ThemeChoice theme});

final settingsProvider = Provider<Settings>((ref) {
  final s = ref.watch(settingsStoreProvider);
  return _follow(ref, s, (currency: s.currency, theme: s.theme));
});

final feedProvider = Provider.family<List<Entry>, FeedFilter>(
  (ref, filter) => filterFeed(ref.watch(journalProvider), filter),
);

final badgesProvider = Provider<List<BadgeStatus>>(
  (ref) => deriveBadges(ref.watch(journalProvider).feed),
);

enum StatsRange {
  days30('30 days'),
  months12('12 months'),
  allTime('All time');

  const StatsRange(this.label);
  final String label;

  DateTime? since(DateTime now) => switch (this) {
    StatsRange.days30 => now.subtract(const Duration(days: 30)),
    StatsRange.months12 => DateTime(now.year - 1, now.month, now.day),
    StatsRange.allTime => null,
  };
}

final statsProvider = Provider.family<JournalStats, StatsRange>((ref, range) {
  final feed = ref.watch(journalProvider).feed;
  final since = range.since(DateTime.now());
  return computeStats(
    since == null ? feed : feed.where((e) => e.tasting.tastedAt.isAfter(since)),
  );
});

final class LastSaved extends Notifier<TastingId?> {
  @override
  TastingId? build() => null;

  void mark(TastingId? id) => state = id;
}

final lastSavedProvider = NotifierProvider<LastSaved, TastingId?>(
  LastSaved.new,
);
