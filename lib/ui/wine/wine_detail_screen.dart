import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/aroma_wheel_data.dart';
import '../../domain/ids.dart';
import '../../domain/journal.dart';
import '../../domain/stats.dart';
import '../../domain/tasting.dart';
import '../../domain/wine.dart';
import '../format.dart';
import '../search/manual_wine_screen.dart';
import '../stats/stats_charts.dart';
import '../tasting/aroma_wheel_view.dart';
import '../tasting/cork_route.dart';
import '../tasting/tasting_form_screen.dart';
import '../theme/cork_theme.dart';
import '../widgets/chalk.dart';
import '../widgets/tasting_row.dart';

enum _Menu { editWine }

class WineDetailScreen extends ConsumerStatefulWidget {
  const WineDetailScreen({super.key, required this.id, this.expand});
  final WineId id;

  final TastingId? expand;

  @override
  ConsumerState<WineDetailScreen> createState() => _WineDetailState();
}

class _WineDetailState extends ConsumerState<WineDetailScreen> {
  late final _expanded = <TastingId>{?widget.expand};
  final _expandedKey = GlobalKey();

  bool get _instant => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    if (widget.expand != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _expandedKey.currentContext;
        if (target != null && target.mounted) {
          Scrollable.ensureVisible(target, alignment: 0.2);
        }
      });
    }
  }

  void _toggle(TastingId id) => setState(() {
    if (!_expanded.remove(id)) _expanded.add(id);
  });

  void _toggleWishlist(Journal journal, Wine wine) {
    final store = ref.read(journalStoreProvider);
    final previous = journal.wishlist[wine.id];
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (previous != null) {
      store.commit([Unwishlist(wine.id)]);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Removed from wishlist'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => store.commit([Wishlist(previous)]),
          ),
        ),
      );
    } else {
      store.commit([
        Wishlist(
          WishlistItem(wineId: wine.id, addedAt: DateTime.now().toUtc()),
        ),
      ]);
      messenger.showSnackBar(
        const SnackBar(content: Text('Added to wishlist')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final journal = ref.watch(journalProvider);
    final wine = journal.wines[widget.id];
    if (wine == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('This wine is no longer in your journal.'),
        ),
      );
    }
    final tastings = journal.tastingsOf(wine.id);
    final wishlisted = journal.wishlist.containsKey(wine.id);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: _Title(wine),
            actions: [
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
                onPressed: () => _toggleWishlist(journal, wine),
              ),
              PopupMenuButton<_Menu>(
                tooltip: 'More',
                onSelected: (_) => Navigator.push<bool>(
                  context,
                  corkRoute(context, (_) => ManualWineScreen.edit(wine: wine)),
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _Menu.editWine,
                    child: Text('Edit wine'),
                  ),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                CorkSpace.gutter,
                CorkSpace.lg,
                CorkSpace.gutter,
                0,
              ),
              child: _FactsTable(_wineFacts(wine)),
            ),
          ),
          const SliverToBoxAdapter(child: BoardHeading('Your verdict')),
          SliverToBoxAdapter(child: _Verdict(tastings)),
          if (tastings.isNotEmpty) ...[
            const SliverToBoxAdapter(child: BoardHeading('Tastings')),
            SliverToBoxAdapter(
              // A Column, not a lazy list: a wine has few tastings, and the
              // expanded one must exist to be scrolled into view on open.
              child: Column(
                children: [
                  for (final t in tastings)
                    _TastingItem(
                      key: t.id == widget.expand
                          ? _expandedKey
                          : ValueKey(t.id),
                      entry: (tasting: t, wine: wine),
                      expanded: _expanded.contains(t.id),
                      instant: _instant,
                      onToggle: () => _toggle(t.id),
                    ),
                ],
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => openTastingForm(context, wine: wine),
        icon: const Icon(Icons.wine_bar_rounded),
        label: Text(tastings.isEmpty ? 'Log a glass' : 'Log again'),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.wine);
  final Wine wine;

  @override
  Widget build(BuildContext context) {
    final winery = wine.winery;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(wine.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (winery != null && winery.isNotEmpty)
          Text(
            winery,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).cork.onShellVariant,
            ),
          ),
      ],
    );
  }
}

typedef _Fact = (String label, String? value);

List<_Fact> _wineFacts(Wine wine) => [
  ('Type', wine.type?.label),
  ('Grapes', wine.grapes.isEmpty ? null : wine.grapes.join(', ')),
  ('Region', wine.region),
  ('Country', wine.country?.name),
  (
    'ABV',
    switch (wine.abv) {
      final abv? when abv == abv.roundToDouble() => '${abv.toInt()}%',
      final abv? => '${abv.toStringAsFixed(1)}%',
      null => null,
    },
  ),
  (
    'Source',
    switch (wine.provenance) {
      FromIndex() => 'X-Wines',
      FromOpenFoodFacts() => 'Open Food Facts',
      EnteredByHand() => 'Added by you',
    },
  ),
];

List<_Fact> _tastingFacts(Tasting t) {
  String? stars(Stars? s) => s == null ? null : '${s.value} of 5';
  final structure = [
    if (t.body case final l?) '${l.label} body',
    if (t.acidity case final l?) '${l.label} acidity',
    if (t.tannin case final l?) '${l.label} tannin',
  ].join(' · ');
  final finish = [
    stars(t.finish),
    t.finishLength?.label,
  ].whereType<String>().join(' · ');
  return [
    ('Glass', t.color?.phrase),
    ('Aroma', stars(t.aroma)),
    ('Flavor', stars(t.flavor)),
    ('Finish', finish.isEmpty ? null : finish),
    ('Sweetness', t.sweetness?.label),
    ('Structure', structure.isEmpty ? null : structure),
    ('Where', t.place),
    (
      'Price',
      switch (t.price) {
        final p? => '${p.formatAmount()} ${p.currency.code}',
        null => null,
      },
    ),
  ];
}

class _FactsTable extends StatelessWidget {
  const _FactsTable(this.facts);
  final List<_Fact> facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium;
    final muted = body?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      children: [
        for (final (label, value) in facts)
          if (value != null && value.isNotEmpty)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: CorkSpace.lg,
                    bottom: CorkSpace.sm,
                  ),
                  child: Text(label, style: muted),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: CorkSpace.sm),
                  child: Text(value, style: body),
                ),
              ],
            ),
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict(this.tastings);

  final List<Tasting> tastings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (tastings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
        child: Text(
          'Not tasted yet. Log a glass to give it a score.',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      );
    }
    final tally = tastings.fold(Tally.zero, (t, x) => t.plus(x.score.tenths));
    final coloured = [
      for (final t in tastings.reversed)
        if (t.color != null) t,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScoreText(
            meanScore(tally),
            style: theme.textTheme.displayLarge?.copyWith(
              color: theme.cork.score,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            'from ${countLabel(tally.count, 'tasting')}',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          if (coloured.isNotEmpty) ...[
            const SizedBox(height: CorkSpace.md),
            Semantics(
              label:
                  'Glass colours of ${countLabel(coloured.length, 'tasting')}, '
                  'oldest first',
              child: Wrap(
                spacing: CorkSpace.sm,
                runSpacing: CorkSpace.sm,
                children: [
                  for (final t in coloured) GlassSwatch(t.color, size: 24),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TastingItem extends StatelessWidget {
  const _TastingItem({
    super.key,
    required this.entry,
    required this.expanded,
    required this.instant,
    required this.onToggle,
  });

  final Entry entry;
  final bool expanded;
  final bool instant;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        expanded: expanded,
        child: TastingRow(entry, datedTitle: true, onTap: onToggle),
      ),
      AnimatedSize(
        duration: instant ? Duration.zero : CorkMotion.medium,
        curve: CorkMotion.standard,
        alignment: Alignment.topCenter,
        child: expanded
            ? _TastingDetails(entry)
            : const SizedBox(width: double.infinity),
      ),
    ],
  );
}

class _TastingDetails extends ConsumerWidget {
  const _TastingDetails(this.entry);
  final Entry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = entry.tasting;
    final theme = Theme.of(context);
    final photo = t.photo;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CorkSpace.gutter + TastingThumb.size + CorkSpace.lg,
        0,
        CorkSpace.gutter,
        CorkSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.notes.isNotEmpty) ...[
            Text(t.notes, style: theme.textTheme.bodyMedium),
            const SizedBox(height: CorkSpace.md),
          ],
          if (t.descriptors.isNotEmpty) ...[
            Wrap(
              spacing: CorkSpace.sm,
              runSpacing: CorkSpace.sm,
              children: [
                for (final d in t.descriptors.map(aromaWheel.resolve))
                  Chip(
                    label: Text(d.label),
                    avatar: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: aromaColor(theme.cork, d.family),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: CorkSpace.md),
          ],
          _FactsTable(_tastingFacts(t)),
          if (photo != null) ...[
            const SizedBox(height: CorkSpace.sm),
            ClipRRect(
              borderRadius: CorkRadius.card,
              child: Image.file(
                ref.watch(photoStoreProvider).fileFor(photo),
                width: 160,
                height: 160,
                fit: BoxFit.cover,
                cacheWidth: (160 * dpr).round(),
                semanticLabel: 'Label photo',
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: CorkSpace.xs),
          TextButton.icon(
            onPressed: () =>
                openTastingForm(context, wine: entry.wine, editing: t),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit', semanticsLabel: 'Edit tasting'),
          ),
        ],
      ),
    );
  }
}
