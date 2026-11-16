import 'package:cork/domain/ids.dart';
import 'package:cork/domain/journal.dart';
import 'package:cork/domain/tasting.dart';
import 'package:cork/domain/wine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/builders.dart';

void main() {
  final syrah = indexWine(1, name: 'Syrah One');
  final riesling = indexWine(2, name: 'Riesling Two', type: WineType.white);

  test('applying the same changes twice equals applying them once', () {
    final t = tasting(syrah);
    final changes = [AdoptWine(syrah), SaveTasting(t)];
    final once = Journal.empty.apply(changes);
    final twice = once.apply(changes);
    expect(twice.wines.keys, once.wines.keys);
    expect(twice.tastings.keys, once.tastings.keys);
  });

  test('AdoptWine never overwrites a wine the user edited', () {
    final edited = syrah.copyWith(name: 'My Syrah');
    final j = Journal.empty.apply([AdoptWine(syrah), EditWine(edited)]);
    final again = j.apply([AdoptWine(syrah)]);
    expect(again.wines[syrah.id]!.name, 'My Syrah');
  });

  test('a tasting or wishlist entry for an absent wine is a StateError', () {
    expect(
      () => Journal.empty.apply([SaveTasting(tasting(syrah))]),
      throwsStateError,
    );
    expect(
      () => Journal.empty.apply([
        Wishlist(WishlistItem(wineId: syrah.id, addedAt: DateTime.utc(2026))),
      ]),
      throwsStateError,
    );
    expect(() => Journal.empty.apply([EditWine(syrah)]), throwsStateError);
  });

  test('saving a tasting can take its wine off the wishlist in one commit', () {
    final j = Journal.empty.apply([
      AdoptWine(syrah),
      Wishlist(WishlistItem(wineId: syrah.id, addedAt: DateTime.utc(2026))),
    ]);
    final kept = j.apply([SaveTasting(tasting(syrah))]);
    expect(kept.wishlist.containsKey(syrah.id), isTrue);
    final removed = j.apply([
      SaveTasting(tasting(syrah), removeFromWishlist: true),
    ]);
    expect(removed.wishlist, isEmpty);
  });

  test('feed is newest first and tastingsOf groups by wine', () {
    final old = tasting(syrah, at: DateTime.utc(2026, 1, 1));
    final mid = tasting(riesling, at: DateTime.utc(2026, 2, 1));
    final recent = tasting(syrah, at: DateTime.utc(2026, 3, 1));
    final j = journalOf([(syrah, old), (riesling, mid), (syrah, recent)]);
    expect(j.feed.map((e) => e.tasting.id), [recent.id, mid.id, old.id]);
    expect(j.tastingsOf(syrah.id).map((t) => t.id), [recent.id, old.id]);
    expect(j.tastingsOf(const WineId('xw:999')), isEmpty);
  });

  test('editing a tasting replaces it by id; deleting removes it', () {
    final t = tasting(syrah, tenths: 30);
    final j = journalOf([(syrah, t)]);
    final edited = Tasting(
      id: t.id,
      wineId: t.wineId,
      tastedAt: t.tastedAt,
      score: Score.fromTenths(45),
    );
    final after = j.apply([SaveTasting(edited)]);
    expect(after.tastings.length, 1);
    expect(after.tastings[t.id]!.score.tenths, 45);
    expect(after.apply([DeleteTasting(t.id)]).tastings, isEmpty);
  });

  test('recentWines orders by last activity and keeps idle wines', () {
    final manual = Wine.manual(
      id: const WineId('m:1'),
      name: 'Nonna Rosso',
      type: WineType.red,
    );
    final j = Journal.empty.apply([
      AdoptWine(manual),
      AdoptWine(syrah),
      AdoptWine(riesling),
      SaveTasting(tasting(syrah, at: DateTime.utc(2026, 1, 1))),
      Wishlist(
        WishlistItem(wineId: riesling.id, addedAt: DateTime.utc(2026, 5, 1)),
      ),
    ]);
    expect(j.recentWines.map((w) => w.id), [riesling.id, syrah.id, manual.id]);
  });
}
