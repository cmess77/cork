import 'ids.dart';
import 'tasting.dart';
import 'wine.dart';

final class WishlistItem {
  const WishlistItem({
    required this.wineId,
    required this.addedAt,
    this.vintage,
    this.note = '',
  });

  final WineId wineId;

  /// UTC instant.
  final DateTime addedAt;
  final Vintage? vintage;
  final String note;
}

typedef Entry = ({Tasting tasting, Wine wine});

/// Invariant: every `Tasting.wineId` and every wishlist key is a key of [wines].
final class Journal {
  Journal(
    Map<WineId, Wine> wines,
    Map<TastingId, Tasting> tastings,
    Map<WineId, WishlistItem> wishlist,
  ) : wines = Map.unmodifiable(wines),
      tastings = Map.unmodifiable(tastings),
      wishlist = Map.unmodifiable(wishlist);

  static final empty = Journal({}, {}, {});

  final Map<WineId, Wine> wines;
  final Map<TastingId, Tasting> tastings;
  final Map<WineId, WishlistItem> wishlist;

  /// Newest first; ties broken by id so the order is total.
  late final List<Entry> feed = List<Entry>.unmodifiable(
    <Entry>[
      for (final t in tastings.values) (tasting: t, wine: wines[t.wineId]!),
    ]..sort(compareEntriesNewestFirst),
  );

  late final Map<WineId, List<Tasting>> _byWine = () {
    final by = <WineId, List<Tasting>>{};
    for (final e in feed) {
      (by[e.wine.id] ??= []).add(e.tasting);
    }
    return by;
  }();

  /// This wine's tastings, newest first.
  List<Tasting> tastingsOf(WineId id) => _byWine[id] ?? const [];

  /// Every wine in the journal, most recent activity (tasting or wishlist
  /// add) first. Wines with no activity left keep their place at the end.
  late final List<Wine> recentWines = () {
    final last = <WineId, DateTime>{};
    void touch(WineId id, DateTime at) {
      final seen = last[id];
      if (seen == null || at.isAfter(seen)) last[id] = at;
    }

    for (final t in tastings.values) {
      touch(t.wineId, t.tastedAt);
    }
    for (final w in wishlist.values) {
      touch(w.wineId, w.addedAt);
    }
    final epoch = DateTime.utc(0);
    return List<Wine>.unmodifiable(
      wines.values.toList()..sort((a, b) {
        final byTime = (last[b.id] ?? epoch).compareTo(last[a.id] ?? epoch);
        return byTime != 0 ? byTime : a.name.compareTo(b.name);
      }),
    );
  }();

  /// Pure reducer. Every change is an upsert or a delete by id, so applying a
  /// change twice equals applying it once. Throws [StateError] when a change
  /// names a wine that is absent.
  Journal apply(Iterable<JournalChange> changes) {
    final wines = {...this.wines};
    final tastings = {...this.tastings};
    final wishlist = {...this.wishlist};

    void requireWine(WineId id) {
      if (!wines.containsKey(id)) throw StateError('No wine $id in journal');
    }

    for (final change in changes) {
      switch (change) {
        case AdoptWine(:final wine):
          wines.putIfAbsent(wine.id, () => wine);
        case EditWine(:final wine):
          requireWine(wine.id);
          wines[wine.id] = wine;
        case SaveTasting(:final tasting, :final removeFromWishlist):
          requireWine(tasting.wineId);
          tastings[tasting.id] = tasting;
          if (removeFromWishlist) wishlist.remove(tasting.wineId);
        case DeleteTasting(:final id):
          tastings.remove(id);
        case Wishlist(:final item):
          requireWine(item.wineId);
          wishlist[item.wineId] = item;
        case Unwishlist(:final wineId):
          wishlist.remove(wineId);
      }
    }
    return Journal(wines, tastings, wishlist);
  }
}

int compareEntriesNewestFirst(Entry a, Entry b) {
  final byTime = b.tasting.tastedAt.compareTo(a.tasting.tastedAt);
  return byTime != 0
      ? byTime
      : b.tasting.id.value.compareTo(a.tasting.id.value);
}

sealed class JournalChange {
  const JournalChange();
}

/// Adopts a lookup hit or a hand-entered wine. Never overwrites: a wine the
/// user already edited keeps their edits when it is picked again.
final class AdoptWine extends JournalChange {
  const AdoptWine(this.wine);
  final Wine wine;
}

final class EditWine extends JournalChange {
  const EditWine(this.wine);
  final Wine wine;
}

final class SaveTasting extends JournalChange {
  const SaveTasting(this.tasting, {this.removeFromWishlist = false});
  final Tasting tasting;
  final bool removeFromWishlist;
}

final class DeleteTasting extends JournalChange {
  const DeleteTasting(this.id);
  final TastingId id;
}

final class Wishlist extends JournalChange {
  const Wishlist(this.item);
  final WishlistItem item;
}

final class Unwishlist extends JournalChange {
  const Unwishlist(this.wineId);
  final WineId wineId;
}
