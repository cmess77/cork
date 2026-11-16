import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/dimension.dart';
import '../../domain/feed.dart';
import '../../domain/journal.dart';
import '../../domain/tasting.dart';
import '../../domain/wine.dart';
import '../format.dart';
import '../routes.dart';
import '../tasting/tasting_form_screen.dart';
import '../theme/cork_theme.dart';
import '../widgets/chalk.dart';
import '../widgets/tasting_row.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key, this.initialFilter = FeedFilter.none});
  final FeedFilter initialFilter;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

enum _RowAction { edit, delete }

typedef _Refinement = ({String label, FeedFilter without});

class _FeedScreenState extends ConsumerState<FeedScreen> {
  late var _filter = widget.initialFilter;
  late var _searching = widget.initialFilter.text.isNotEmpty;
  late final _query = TextEditingController(text: widget.initialFilter.text);
  var _fabExtended = true;

  bool get _instant => MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _setFilter(FeedFilter filter) => setState(() => _filter = filter);

  void _closeSearch() {
    _query.clear();
    setState(() {
      _searching = false;
      _filter = _filter.copyWith(text: '');
    });
  }

  void _clearAll() {
    _query.clear();
    setState(() {
      _searching = false;
      _filter = FeedFilter.none;
    });
  }

  bool _onScroll(UserScrollNotification n) {
    final extended = switch (n.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _fabExtended,
    };
    if (extended != _fabExtended) setState(() => _fabExtended = extended);
    return false;
  }

  Future<void> _openFilters(Journal journal) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: _instant ? AnimationStyle.noAnimation : null,
    builder: (_) => _FilterSheet(
      initial: _filter,
      countries: _keysOf(journal, Dimension.country),
      onChanged: _setFilter,
    ),
  );

  Future<void> _rowMenu(Entry e) async {
    final action = await showModalBottomSheet<_RowAction>(
      context: context,
      sheetAnimationStyle: _instant ? AnimationStyle.noAnimation : null,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CorkSpace.gutter,
                0,
                CorkSpace.gutter,
                CorkSpace.sm,
              ),
              child: Text(
                e.wine.name,
                style: Theme.of(sheet).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(sheet, _RowAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(sheet, _RowAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _RowAction.edit:
        await openTastingForm(context, wine: e.wine, editing: e.tasting);
      case _RowAction.delete:
        await _confirmDelete(e);
      case null:
    }
  }

  Future<void> _confirmDelete(Entry e) async {
    final delete = await showDialog<bool>(
      context: context,
      animationStyle: _instant ? AnimationStyle.noAnimation : null,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this tasting?'),
        content: const Text('Stats and badges will update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete != true || !mounted) return;
    ref.read(journalStoreProvider).commit([DeleteTasting(e.tasting.id)]);
  }

  @override
  Widget build(BuildContext context) {
    final journal = ref.watch(journalProvider);
    final entries = ref.watch(feedProvider(_filter));
    final empty = journal.tastings.isEmpty;
    final refinements = _refinements(_filter, journal);

    return Scaffold(
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          slivers: [
            _appBar(journal, showActions: !empty),
            if (empty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyBoard(onLog: () => logGlass(context)),
              )
            else ...[
              if (refinements.isNotEmpty)
                SliverToBoxAdapter(child: _chipsRow(refinements)),
              if (entries.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FilteredEmpty(onClear: _clearAll),
                )
              else ...[
                SliverToBoxAdapter(child: _Summary(entries)),
                for (final (month, group) in byMonth(entries))
                  SliverMainAxisGroup(
                    slivers: [
                      PinnedHeaderSliver(
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: BoardHeading(monthHeading(month)),
                        ),
                      ),
                      SliverList.builder(
                        itemCount: group.length,
                        itemBuilder: (context, i) {
                          final e = group[i];
                          return TastingRow(
                            e,
                            key: ValueKey(e.tasting.id),
                            onTap: () => openWine(
                              context,
                              e.wine.id,
                              expand: e.tasting.id,
                            ),
                            onLongPress: () => _rowMenu(e),
                          );
                        },
                      ),
                    ],
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            ],
          ],
        ),
      ),
      floatingActionButton: empty
          ? null
          : AnimatedSize(
              duration: _instant ? Duration.zero : CorkMotion.short,
              curve: CorkMotion.standard,
              child: FloatingActionButton.extended(
                heroTag: null,
                isExtended: _fabExtended,
                tooltip: _fabExtended ? null : 'Log a glass',
                onPressed: () => logGlass(context),
                icon: const Icon(Icons.wine_bar_rounded),
                label: const Text('Log a glass'),
              ),
            ),
    );
  }

  Widget _appBar(Journal journal, {required bool showActions}) {
    final cork = Theme.of(context).cork;
    final text = Theme.of(context).textTheme;
    return SliverAppBar(
      pinned: true,
      leading: _searching
          ? IconButton(
              tooltip: 'Close search',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _closeSearch,
            )
          : null,
      title: _searching
          ? TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              cursorColor: cork.onShell,
              style: text.bodyLarge?.copyWith(color: cork.onShell),
              decoration: InputDecoration(
                hintText: 'Search your journal',
                hintStyle: text.bodyLarge?.copyWith(color: cork.onShellVariant),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (t) => _setFilter(_filter.copyWith(text: t)),
            )
          : const Text('Cork'),
      actions: [
        if (showActions && !_searching)
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => setState(() => _searching = true),
          ),
        if (showActions)
          IconButton(
            tooltip: 'Filter',
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _openFilters(journal),
          ),
      ],
    );
  }

  Widget _chipsRow(List<_Refinement> refinements) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(
      CorkSpace.gutter,
      CorkSpace.md,
      CorkSpace.gutter,
      0,
    ),
    child: Row(
      children: [
        for (final r in refinements)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: CorkSpace.sm),
            child: InputChip(
              label: Text(r.label),
              deleteButtonTooltipMessage: 'Remove ${r.label}',
              onDeleted: () => _setFilter(r.without),
            ),
          ),
        TextButton(
          onPressed: () => _setFilter(FeedFilter(text: _filter.text)),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
}

List<GroupKey> _keysOf(Journal journal, Dimension d) =>
    {for (final e in journal.feed) ...d.keysOf(e)}.toList()
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

List<_Refinement> _refinements(FeedFilter f, Journal journal) {
  final labels = <(Dimension, String), String>{
    for (final t in WineType.values) (Dimension.type, t.name): t.label,
  };
  for (final d in f.facets.keys) {
    for (final k in _keysOf(journal, d)) {
      labels[(d, k.id)] ??= k.label;
    }
  }
  return [
    for (final MapEntry(key: d, value: ids) in f.facets.entries)
      for (final id in ids)
        (label: labels[(d, id)] ?? id, without: f.toggle(d, id)),
    if (f.minScore != null || f.maxScore != null)
      (
        label: _scoreRange(f.minScore, f.maxScore),
        without: f.copyWith(minScore: () => null, maxScore: () => null),
      ),
    if (f.from != null || f.to != null)
      (
        label: _dateRange(f.from, f.to),
        without: f.copyWith(from: () => null, to: () => null),
      ),
  ];
}

String _scoreRange(Score? min, Score? max) => switch ((min, max)) {
  (final lo?, final hi?) => 'Score ${lo.format()} to ${hi.format()}',
  (final lo?, null) => 'Score ${lo.format()} and up',
  (null, final hi?) => 'Score up to ${hi.format()}',
  (null, null) => 'Any score',
};

String _dateRange(DateTime? from, DateTime? to) => switch ((from, to)) {
  (final a?, final b?) => '${fullDate(a)} to ${fullDate(b)}',
  (final a?, null) => 'From ${fullDate(a)}',
  (null, final b?) => 'Until ${fullDate(b)}',
  (null, null) => 'Any date',
};

class _Summary extends StatelessWidget {
  const _Summary(this.entries);
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final wines = {for (final e in entries) e.wine.id}.length;
    final tenths = entries.fold(0, (sum, e) => sum + e.tasting.score.tenths);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CorkSpace.gutter,
        CorkSpace.lg,
        CorkSpace.gutter,
        0,
      ),
      child: Text(
        summaryLine(entries.length, wines, tenths / entries.length / 10),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({required this.onLog});
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CorkSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BoardHeading(
              'Nothing on the board yet',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: CorkSpace.sm),
            Text(
              'Log the first glass you taste and it shows up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: CorkSpace.xl),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, CorkSpace.minTouch),
              ),
              onPressed: onLog,
              icon: const Icon(Icons.wine_bar_rounded),
              label: const Text('Log a glass'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CorkSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No tastings match these filters.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: CorkSpace.sm),
            TextButton(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.countries,
    required this.onChanged,
  });

  final FeedFilter initial;
  final List<GroupKey> countries;
  final ValueChanged<FeedFilter> onChanged;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late var _f = widget.initial;

  void _set(FeedFilter f) {
    setState(() => _f = f);
    widget.onChanged(f);
  }

  Future<void> _pickDates() async {
    final from = _f.from;
    final to = _f.to;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialDateRange: from != null && to != null
          ? DateTimeRange(start: from, end: DateTime(to.year, to.month, to.day))
          : null,
    );
    if (picked == null || !mounted) return;
    final s = picked.start;
    final e = picked.end;
    _set(
      _f.copyWith(
        from: () => DateTime(s.year, s.month, s.day),
        to: () => DateTime(e.year, e.month, e.day, 23, 59, 59, 999),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lo = _f.minScore ?? Score.min;
    final hi = _f.maxScore ?? Score.max;
    final hasDates = _f.from != null || _f.to != null;

    Widget chips(Iterable<(String id, String label)> keys, Dimension d) {
      final selected = _f.facets[d] ?? const {};
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
        child: Wrap(
          spacing: CorkSpace.sm,
          runSpacing: CorkSpace.sm,
          children: [
            for (final (id, label) in keys)
              FilterChip(
                label: Text(label),
                selected: selected.contains(id),
                onSelected: (_) => _set(_f.toggle(d, id)),
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BoardHeading(
            'Type',
            padding: EdgeInsets.fromLTRB(
              CorkSpace.gutter,
              0,
              CorkSpace.gutter,
              CorkSpace.sm,
            ),
          ),
          chips([
            for (final t in WineType.values) (t.name, t.label),
          ], Dimension.type),
          const BoardHeading('Score'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
            child: Text(
              '${lo.format()} to ${hi.format()}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          RangeSlider(
            values: RangeValues(lo.tenths.toDouble(), hi.tenths.toDouble()),
            min: Score.min.tenths.toDouble(),
            max: Score.max.tenths.toDouble(),
            divisions: Score.max.tenths - Score.min.tenths,
            labels: RangeLabels(lo.format(), hi.format()),
            semanticFormatterCallback: (v) => (v / 10).toStringAsFixed(1),
            onChanged: (v) {
              final a = v.start.round();
              final b = v.end.round();
              _set(
                _f.copyWith(
                  minScore: () =>
                      a <= Score.min.tenths ? null : Score.fromTenths(a),
                  maxScore: () =>
                      b >= Score.max.tenths ? null : Score.fromTenths(b),
                ),
              );
            },
          ),
          const BoardHeading('Date'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, CorkSpace.minTouch),
                      alignment: AlignmentDirectional.centerStart,
                    ),
                    onPressed: _pickDates,
                    icon: const Icon(Icons.calendar_today_rounded),
                    label: Text(_dateRange(_f.from, _f.to)),
                  ),
                ),
                if (hasDates)
                  IconButton(
                    tooltip: 'Clear dates',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () =>
                        _set(_f.copyWith(from: () => null, to: () => null)),
                  ),
              ],
            ),
          ),
          if (widget.countries.isNotEmpty) ...[
            const BoardHeading('Country'),
            chips([
              for (final k in widget.countries) (k.id, k.label),
            ], Dimension.country),
          ],
          Padding(
            padding: const EdgeInsets.all(CorkSpace.gutter),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(CorkSpace.minTouch),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
