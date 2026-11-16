import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/dimension.dart';
import '../../domain/feed.dart';
import '../../domain/journal.dart';
import '../../domain/stats.dart';
import '../../domain/wine.dart';
import '../format.dart';
import '../routes.dart';
import '../theme/cork_theme.dart';
import '../widgets/chalk.dart';
import 'stats_charts.dart';

enum _Sort {
  count('Count'),
  average('Average');

  const _Sort(this.label);
  final String label;
}

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  var _range = StatsRange.allTime;
  var _dimension = Dimension.type;
  var _sort = _Sort.count;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Stats')),
        ..._slivers(
          ref.watch(journalProvider),
          ref.watch(statsProvider(_range)),
        ),
      ],
    ),
  );

  List<Widget> _slivers(Journal journal, JournalStats stats) {
    if (journal.tastings.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Message('Stats appear after your first tasting.'),
        ),
      ];
    }

    final rangePicker = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CorkSpace.gutter,
          CorkSpace.lg,
          CorkSpace.gutter,
          0,
        ),
        child: SegmentedButton<StatsRange>(
          showSelectedIcon: false,
          segments: [
            for (final r in StatsRange.values)
              ButtonSegment(value: r, label: Text(r.label)),
          ],
          selected: {_range},
          onSelectionChanged: (s) => setState(() => _range = s.single),
        ),
      ),
    );

    if (stats.overall.count == 0) {
      return [
        rangePicker,
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Message(
            'No tastings in the last ${_range.label.toLowerCase()}.',
          ),
        ),
      ];
    }

    final since = _range.since(DateTime.now());
    final glasses = [
      for (final e in journal.feed.reversed)
        if (since == null || e.tasting.tastedAt.isAfter(since)) e,
    ];
    final groups = _sorted(stats.by[_dimension]!, _sort);
    final most = groups.map((g) => g.tally.count).fold(0, max);

    return [
      rangePicker,
      SliverToBoxAdapter(child: _SummaryCard(stats, glasses)),
      const SliverToBoxAdapter(child: BoardHeading('Average over time')),
      SliverToBoxAdapter(
        child: _Block(
          child: stats.overTime.length < 3
              ? const _CardNote('Log a few more months to see a trend.')
              : TrendChart(stats.overTime),
        ),
      ),
      const SliverToBoxAdapter(child: BoardHeading('Breakdown')),
      SliverToBoxAdapter(child: _dimensionChips()),
      SliverToBoxAdapter(child: _sortPicker()),
      if (groups.isEmpty)
        SliverToBoxAdapter(
          child: _CardNote(
            'No ${_dimension.label.toLowerCase()} recorded in this period.',
            padding: const EdgeInsets.symmetric(
              horizontal: CorkSpace.gutter,
              vertical: CorkSpace.md,
            ),
          ),
        )
      else
        SliverList.builder(
          itemCount: groups.length,
          itemBuilder: (context, i) =>
              _GroupRow(groups[i], dimension: _dimension, most: most),
        ),
      const SliverToBoxAdapter(child: BoardHeading('Distributions')),
      SliverToBoxAdapter(
        child: _Block(title: 'Score', child: ScoreDotPlot(stats.scoreBins)),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: CorkSpace.sm)),
      SliverToBoxAdapter(
        child: _Block(
          title: 'Sweetness',
          child: stats.sweetness.values.every((n) => n == 0)
              ? const _CardNote('No sweetness recorded in this period.')
              : SweetnessBars(stats.sweetness),
        ),
      ),
      const SliverToBoxAdapter(child: BoardHeading('Top rated')),
      SliverList.builder(
        itemCount: stats.topWines.length,
        itemBuilder: (context, i) => _TopWineRow(stats.topWines[i]),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: CorkSpace.xl)),
    ];
  }

  Widget _dimensionChips() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
    child: Row(
      children: [
        for (final d in Dimension.values)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: CorkSpace.sm),
            child: ChoiceChip(
              label: Text(d.label),
              selected: d == _dimension,
              onSelected: (_) => setState(() => _dimension = d),
            ),
          ),
      ],
    ),
  );

  Widget _sortPicker() => Padding(
    padding: const EdgeInsets.fromLTRB(
      CorkSpace.gutter,
      CorkSpace.sm,
      CorkSpace.gutter,
      CorkSpace.xs,
    ),
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: SegmentedButton<_Sort>(
        showSelectedIcon: false,
        segments: [
          for (final s in _Sort.values)
            ButtonSegment(value: s, label: Text(s.label)),
        ],
        selected: {_sort},
        onSelectionChanged: (s) => setState(() => _sort = s.single),
      ),
    ),
  );
}

List<GroupStat> _sorted(List<GroupStat> groups, _Sort sort) => switch (sort) {
  _Sort.count => groups,
  _Sort.average =>
    [...groups]..sort((a, b) {
      final m =
          b.tally.tenthsSum * a.tally.count - a.tally.tenthsSum * b.tally.count;
      if (m != 0) return m.sign;
      final c = b.tally.count.compareTo(a.tally.count);
      return c != 0 ? c : a.key.sortKey.compareTo(b.key.sortKey);
    }),
};

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(CorkSpace.xl),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class _CardNote extends StatelessWidget {
  const _CardNote(this.text, {this.padding = EdgeInsets.zero});
  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _Block extends StatelessWidget {
  const _Block({required this.child, this.title});
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(CorkSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title case final title?) ...[
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: CorkSpace.md),
            ],
            child,
          ],
        ),
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.stats, this.glasses);
  final JournalStats stats;

  final List<Entry> glasses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coloured = [
      for (final e in glasses)
        if (e.tasting.color != null) e,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CorkSpace.gutter,
        CorkSpace.lg,
        CorkSpace.gutter,
        0,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(CorkSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Average '),
                    TextSpan(
                      text: meanScore(stats.overall).format(),
                      style: TextStyle(
                        color: theme.cork.score,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    TextSpan(
                      text:
                          ' · ${countLabel(stats.overall.count, 'tasting')}'
                          ' · ${countLabel(stats.uniqueWines, 'wine')}',
                    ),
                  ],
                ),
                style: theme.textTheme.titleMedium,
              ),
              if (coloured.isNotEmpty) ...[
                const SizedBox(height: CorkSpace.md),
                Semantics(
                  label:
                      'Glass colours of ${countLabel(coloured.length, 'tasting')}, '
                      'oldest first',
                  child: Wrap(
                    spacing: CorkSpace.xs,
                    runSpacing: CorkSpace.sm,
                    children: [
                      for (final e in coloured)
                        GlassSwatch(e.tasting.color, size: 20),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow(this.group, {required this.dimension, required this.most});
  final GroupStat group;
  final Dimension dimension;
  final int most;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final count = group.tally.count;
    final color = dimension == Dimension.type
        ? typeSeriesColor(context, WineType.values.byName(group.key.id))
        : theme.colorScheme.secondary;
    return MergeSemantics(
      child: InkWell(
        onTap: () => openFilteredFeed(
          context,
          FeedFilter(
            facets: {
              dimension: {group.key.id},
            },
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CorkSpace.gutter,
              vertical: CorkSpace.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        group.key.label,
                        style: text.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: CorkSpace.xs),
                      ExcludeSemantics(
                        child: CountBar(fraction: count / most, color: color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CorkSpace.lg),
                Text(
                  '$count',
                  textAlign: TextAlign.right,
                  semanticsLabel: countLabel(count, 'tasting'),
                  style: text.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: CorkSpace.md),
                ScoreText(meanScore(group.tally)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopWineRow extends StatelessWidget {
  const _TopWineRow(this.top);
  final WineTally top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final winery = top.wine.winery;
    return MergeSemantics(
      child: InkWell(
        onTap: () => openWine(context, top.wine.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CorkSpace.gutter,
              vertical: CorkSpace.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        top.wine.name,
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (winery != null && winery.isNotEmpty)
                        Text(
                          winery,
                          style: text.bodyMedium?.copyWith(color: muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: CorkSpace.lg),
                Text(
                  countLabel(top.tally.count, 'tasting'),
                  style: text.bodySmall?.copyWith(
                    color: muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: CorkSpace.md),
                ScoreText(meanScore(top.tally)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
