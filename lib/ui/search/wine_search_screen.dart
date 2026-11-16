import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/fold.dart';
import '../../domain/journal.dart';
import '../../domain/tasting.dart';
import '../../domain/wine.dart';
import '../../lookup/wine_lookup.dart';
import '../format.dart';
import '../tasting/cork_route.dart';
import '../tasting/tasting_form_screen.dart';
import '../theme/cork_theme.dart';
import '../widgets/chalk.dart';
import 'manual_wine_screen.dart';

/// What picking a wine does: open the tasting form, or add to the wishlist.
enum SearchMode { log, wishlist }

typedef PickedWine = ({Wine wine, Vintage? vintage});

/// Opens search to swap the wine of a tasting form that is already open.
/// Resolves to the chosen wine, or null when the user backs out.
Future<PickedWine?> pickWine(BuildContext context) => Navigator.push(
  context,
  corkRoute(context, (_) => const WineSearchScreen._picking()),
);

enum _Purpose { log, wishlist, pick }

/// Step one of logging, and Wishlist's "Add a wine": as-you-type matches from
/// the journal and the bundled index, online search on request, and manual
/// entry. Pops once the picked wine has been used.
class WineSearchScreen extends ConsumerStatefulWidget {
  const WineSearchScreen({super.key, this.mode = SearchMode.log})
    : _purpose = mode == SearchMode.log ? _Purpose.log : _Purpose.wishlist;

  const WineSearchScreen._picking()
    : mode = SearchMode.log,
      _purpose = _Purpose.pick;

  final SearchMode mode;
  final _Purpose _purpose;

  @override
  ConsumerState<WineSearchScreen> createState() => _WineSearchState();
}

/// Online search runs only on a tap, so its state is separate from the
/// as-you-type results and is reset by any edit to the query.
sealed class _Online {
  const _Online();
}

final class _NotAsked extends _Online {
  const _NotAsked();
}

final class _Asking extends _Online {
  const _Asking(this.query);
  final String query;
}

final class _Answered extends _Online {
  const _Answered(this.query, this.result);
  final String query;
  final OnlineResult result;
}

class _WineSearchState extends ConsumerState<WineSearchScreen> {
  final _query = TextEditingController();
  var _hits = const <Wine>[];
  _Online _online = const _NotAsked();
  PickedWine? _picked;

  // Keystrokes are numbered so a slow answer never replaces a newer one.
  var _sent = 0;
  var _shown = 0;

  String get _text => _query.text.trim();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _changed(String text) {
    final seq = ++_sent;
    final blank = text.trim().isEmpty;
    setState(() {
      _online = const _NotAsked();
      if (blank) {
        _shown = seq;
        _hits = const [];
      }
    });
    if (blank) return;
    ref.read(wineLookupProvider).suggest(text).then((hits) {
      if (!mounted || seq <= _shown) return;
      setState(() {
        _shown = seq;
        _hits = hits;
      });
    });
  }

  void _clear() {
    _query.clear();
    _changed('');
  }

  Future<void> _searchOnline() async {
    final query = _text;
    FocusScope.of(context).unfocus();
    setState(() => _online = _Asking(query));
    final result = await ref.read(wineLookupProvider).searchOnline(query);
    if (!mounted) return;
    if (_online case _Asking(query: final asked) when asked == query) {
      setState(() => _online = _Answered(query, result));
    }
  }

  bool get _canSearchOnline =>
      _text.isNotEmpty &&
      switch (_online) {
        _NotAsked() => true,
        _Asking() => false,
        _Answered(:final result) => result is! OnlineHits,
      };

  /// Uses [hit] for this screen's purpose. True when it was used and the
  /// search should close.
  Future<bool> _use(BuildContext from, Wine hit, Vintage? vintage) async {
    final store = ref.read(journalStoreProvider);
    final wine = store.journal.wines[hit.id] ?? hit;
    switch (widget._purpose) {
      case _Purpose.log:
        return openTastingForm(from, wine: wine, vintage: vintage);
      case _Purpose.wishlist:
        store.commit([
          AdoptWine(wine),
          Wishlist(
            WishlistItem(
              wineId: wine.id,
              addedAt: DateTime.now().toUtc(),
              vintage: vintage,
            ),
          ),
        ]);
        ScaffoldMessenger.of(from)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Added to wishlist')));
        return true;
      case _Purpose.pick:
        _picked = (wine: wine, vintage: vintage);
        return true;
    }
  }

  Future<void> _pick(Wine hit) async {
    if (await _use(context, hit, null) && mounted) {
      Navigator.pop(context, _picked);
    }
  }

  Future<void> _addManually() async {
    final used = await Navigator.push<bool>(
      context,
      corkRoute(
        context,
        (_) => ManualWineScreen(initialName: _text, onCreated: _use),
      ),
    );
    if (used == true && mounted) Navigator.pop(context, _picked);
  }

  void _toggleWishlist(Wine hit) {
    final store = ref.read(journalStoreProvider);
    final wine = store.journal.wines[hit.id] ?? hit;
    store.commit(
      store.journal.wishlist.containsKey(wine.id)
          ? [Unwishlist(wine.id)]
          : [
              AdoptWine(wine),
              Wishlist(
                WishlistItem(wineId: wine.id, addedAt: DateTime.now().toUtc()),
              ),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final journal = ref.watch(journalProvider);
    final scheme = Theme.of(context).colorScheme;
    final empty = _text.isEmpty;
    final local = empty ? journal.recentWines.take(10).toList() : _hits;
    final words = _words(_query.text);

    Widget row(Wine w) => _WineRow(
      wine: w,
      words: words,
      wishlisted: journal.wishlist.containsKey(w.id),
      onTap: () => _pick(w),
      onBookmark: () => _toggleWishlist(w),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CorkSpace.gutter,
                CorkSpace.sm,
                CorkSpace.gutter,
                CorkSpace.sm,
              ),
              child: SearchBar(
                controller: _query,
                autoFocus: true,
                hintText: 'Wine, winery, grape or region',
                textInputAction: TextInputAction.search,
                leading: const BackButton(),
                trailing: [
                  if (!empty)
                    IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _clear,
                    ),
                ],
                onChanged: _changed,
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: CorkSpace.lg),
                children: [
                  if (empty && local.isNotEmpty) const BoardHeading('Recent'),
                  if (empty && local.isEmpty)
                    const _Note('Wines you log or save show up here.'),
                  for (final w in local) row(w),
                  if (!empty && local.isEmpty)
                    _Note(
                      "Nothing in your journal or the built-in list for "
                      "'$_text'.",
                    ),
                  ..._onlineSection(row),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CorkSpace.gutter,
                  CorkSpace.sm,
                  CorkSpace.gutter,
                  CorkSpace.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _canSearchOnline ? _searchOnline : null,
                        icon: const Icon(Icons.cloud_outlined),
                        label: const Text('Search online'),
                      ),
                    ),
                    const SizedBox(width: CorkSpace.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _addManually,
                        child: const Text('Add manually'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _onlineSection(Widget Function(Wine) row) {
    const heading = BoardHeading('From Open Food Facts');
    return switch (_online) {
      _NotAsked() => const [],
      _Asking() => const [
        heading,
        LinearProgressIndicator(semanticsLabel: 'Searching Open Food Facts'),
      ],
      _Answered(:final query, :final result) => [
        heading,
        ...switch (result) {
          OnlineHits(:final wines) when wines.isEmpty => [
            _Note("Nothing online for '$query'. Add it manually."),
          ],
          OnlineHits(:final wines) => [for (final w in wines) row(w)],
          OnlineRateLimited() => const [
            _Note('Online search is busy. Try again in a minute.'),
          ],
          OnlineUnavailable() => const [
            _Note(
              "You're offline. Your saved wines and the built-in list still "
              'work.',
            ),
          ],
        },
      ],
    };
  }
}

/// Folded query words, for bolding the matched start of each name word.
List<String> _words(String query) =>
    fold(query).split(' ').where((w) => w.isNotEmpty).toList();

final _wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// [name] with the start of each word that a typed word matches in [bold].
List<TextSpan> _highlight(String name, List<String> words, TextStyle bold) {
  final spans = <TextSpan>[];
  var at = 0;
  for (final m in _wordPattern.allMatches(name)) {
    final n = _matchedLength(m[0]!, words);
    if (n == 0) continue;
    if (m.start > at) spans.add(TextSpan(text: name.substring(at, m.start)));
    spans.add(
      TextSpan(text: name.substring(m.start, m.start + n), style: bold),
    );
    at = m.start + n;
  }
  if (at < name.length) spans.add(TextSpan(text: name.substring(at)));
  return spans;
}

/// How many characters of [word] the longest matching typed word covers.
/// Counted on the original spelling, since folding can lengthen 'ß' or 'æ'.
int _matchedLength(String word, List<String> words) {
  final folded = fold(word);
  var best = 0;
  for (final w in words) {
    if (!folded.startsWith(w)) continue;
    for (var n = 1; n <= word.length; n++) {
      if (fold(word.substring(0, n)).length >= w.length) {
        best = max(best, n);
        break;
      }
    }
  }
  return best;
}

class _WineRow extends StatelessWidget {
  const _WineRow({
    required this.wine,
    required this.words,
    required this.wishlisted,
    required this.onTap,
    required this.onBookmark,
  });

  final Wine wine;
  final List<String> words;
  final bool wishlisted;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final title = text.titleMedium!;
    final subtitle = wineSubtitle(wine);
    final type = wine.type;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.only(
            left: CorkSpace.gutter,
            right: CorkSpace.xs,
            top: CorkSpace.sm,
            bottom: CorkSpace.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: type == null
                    ? null
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TypeDot(type),
                          const SizedBox(height: CorkSpace.xs),
                          Text(
                            type.label,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: CorkSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: _highlight(
                          wine.name,
                          words,
                          CorkFonts.withWeight(title, FontWeight.w700),
                        ),
                      ),
                      style: title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: wishlisted
                    ? 'Remove from wishlist'
                    : 'Add to wishlist',
                isSelected: wishlisted,
                icon: const Icon(Icons.bookmark_border_rounded),
                selectedIcon: Icon(
                  Icons.bookmark_rounded,
                  color: scheme.tertiary,
                ),
                onPressed: onBookmark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: CorkSpace.gutter,
      vertical: CorkSpace.md,
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
