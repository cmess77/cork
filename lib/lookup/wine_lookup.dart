import 'dart:typed_data';

import '../domain/fold.dart';
import '../domain/ids.dart';
import '../domain/journal.dart';
import '../domain/wine.dart';
import 'open_food_facts.dart';
import 'wine_index.dart';

abstract interface class WineLookup {
  /// As-you-type. Never touches the network and never throws on any input.
  /// Journal wines come first (most recent activity first), then index hits
  /// by relevance. An index hit already in the journal appears once, as the
  /// journal's copy. A trailing token shorter than two characters is ignored
  /// rather than blanking the results between words.
  Future<List<Wine>> suggest(String text, {int limit = 50});

  /// Explicit user tap only. Enforces the Open Food Facts budget internally,
  /// so no caller can breach it.
  Future<OnlineResult> searchOnline(String text);

  Future<void> close();
}

sealed class OnlineResult {
  const OnlineResult();
}

final class OnlineHits extends OnlineResult {
  const OnlineHits(this.wines);

  /// [FromOpenFoodFacts] provenance; `type` may be null.
  final List<Wine> wines;
}

final class OnlineRateLimited extends OnlineResult {
  const OnlineRateLimited(this.retryIn);
  final Duration retryIn;
}

/// No network, timeout, server error, or a payload that would not parse.
final class OnlineUnavailable extends OnlineResult {
  const OnlineUnavailable();
}

final class BundledWineLookup implements WineLookup {
  BundledWineLookup._(this._index, this._online, this._journal);

  /// Installs the bundled index under [indexDir] (once per asset version) and
  /// starts the isolate that serves it. [journal] is read on every keystroke,
  /// so it must return the current value, not a snapshot.
  static Future<BundledWineLookup> open({
    required String indexDir,
    required Future<ByteData> Function() loadAsset,
    required Journal Function() journal,
    required String appVersion,
  }) async {
    final path = await installWineIndex(indexDir, loadAsset: loadAsset);
    return BundledWineLookup._(
      await IndexWorker.spawn(path),
      OpenFoodFacts(appVersion: appVersion),
      journal,
    );
  }

  final IndexWorker _index;
  final OpenFoodFacts _online;
  final Journal Function() _journal;

  @override
  Future<List<Wine>> suggest(String text, {int limit = 50}) async {
    if (limit <= 0) return const [];
    final journal = _journal();
    final query = FtsQuery.parse(text);
    if (query == null) return journal.recentWines.take(limit).toList();

    final words = [for (final t in query.tokens) fold(t)];
    final out = journal.recentWines
        .where((w) => _matches(w, words))
        .take(limit)
        .toList();
    final shown = <WineId>{for (final w in out) w.id};

    List<Wine> hits;
    try {
      hits = await _index.search(query, limit);
    } catch (_) {
      hits = const [];
    }
    for (final hit in hits) {
      if (out.length >= limit) break;
      if (shown.add(hit.id)) out.add(journal.wines[hit.id] ?? hit);
    }
    return out;
  }

  @override
  Future<OnlineResult> searchOnline(String text) => _online.search(text);

  @override
  Future<void> close() async {
    _online.close();
    await _index.close();
  }
}

bool _matches(Wine wine, List<String> words) {
  final haystack = [
    ...foldedWords(wine.name),
    if (wine.winery case final winery?) ...foldedWords(winery),
    for (final g in wine.grapes) ...foldedWords(g),
    if (wine.region case final region?) ...foldedWords(region),
  ];
  return words.every((w) => haystack.any((h) => h.startsWith(w)));
}
