import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/journal.dart';
import '../../domain/wine.dart';
import '../format.dart';
import '../routes.dart';
import '../search/wine_search_screen.dart';
import '../tasting/cork_route.dart';
import '../tasting/tasting_form_screen.dart';
import '../theme/cork_theme.dart';

enum _Sort {
  recent('Recently added'),
  name('Name');

  const _Sort(this.label);
  final String label;
}

typedef _Saved = ({WishlistItem item, Wine wine});

/// Wines saved to try. Swipe removes with Undo; Log opens the tasting form.
class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  var _sort = _Sort.recent;

  List<_Saved> _sorted(Journal journal) {
    final saved = [
      for (final item in journal.wishlist.values)
        (item: item, wine: journal.wines[item.wineId]!),
    ];
    return saved..sort(
      (a, b) => switch (_sort) {
        _Sort.recent => b.item.addedAt.compareTo(a.item.addedAt),
        _Sort.name => a.wine.name.toLowerCase().compareTo(
          b.wine.name.toLowerCase(),
        ),
      },
    );
  }

  void _remove(_Saved s) {
    final store = ref.read(journalStoreProvider);
    store.commit([Unwishlist(s.wine.id)]);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Removed from wishlist'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => store.commit([Wishlist(s.item)]),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final saved = _sorted(ref.watch(journalProvider));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        actions: [
          PopupMenuButton<_Sort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              for (final s in _Sort.values)
                CheckedPopupMenuItem(
                  value: s,
                  checked: s == _sort,
                  child: Text(s.label),
                ),
            ],
          ),
        ],
      ),
      body: saved.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(CorkSpace.xl),
                child: Text(
                  'Save wines you want to try. Tap the bookmark in search, '
                  'or Add a wine.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: CorkSpace.sm, bottom: 88),
              itemCount: saved.length,
              itemBuilder: (context, i) {
                final s = saved[i];
                return Dismissible(
                  key: ValueKey(s.wine.id),
                  background: const _RemoveBackground(
                    alignment: AlignmentDirectional.centerStart,
                  ),
                  secondaryBackground: const _RemoveBackground(
                    alignment: AlignmentDirectional.centerEnd,
                  ),
                  onDismissed: (_) => _remove(s),
                  child: _WishlistRow(
                    saved: s,
                    onTap: () => openWine(context, s.wine.id),
                    onLog: () => openTastingForm(
                      context,
                      wine: s.wine,
                      vintage: s.item.vintage,
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Navigator.push<void>(
          context,
          corkRoute(
            context,
            (_) => const WineSearchScreen(mode: SearchMode.wishlist),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add a wine'),
      ),
    );
  }
}

class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground({required this.alignment});
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CorkSpace.xl),
        child: Align(
          alignment: alignment,
          child: Icon(
            Icons.bookmark_remove_outlined,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _WishlistRow extends StatelessWidget {
  const _WishlistRow({
    required this.saved,
    required this.onTap,
    required this.onLog,
  });

  final _Saved saved;
  final VoidCallback onTap;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final wine = saved.wine;
    final subtitle = [
      wine.winery,
      wine.region,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');

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
              Icon(
                Icons.bookmark_rounded,
                color: theme.colorScheme.tertiary,
                semanticLabel: 'On your wishlist',
              ),
              const SizedBox(width: CorkSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      wine.name,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: text.bodyMedium?.copyWith(color: muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      'Added ${dayLabel(saved.item.addedAt)}',
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Log',
                icon: const Icon(Icons.wine_bar_outlined),
                onPressed: onLog,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
