import '../domain/wine.dart';

/// Finds wines. Hides the bundled index, Open Food Facts, the journal's own
/// wines, FTS syntax, HTTP, rate limiting, and asset installation.
/// Results are domain [Wine]s whose ids derive from provenance.
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
