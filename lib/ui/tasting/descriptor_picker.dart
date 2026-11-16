import 'package:flutter/material.dart';

import '../../domain/aroma_wheel.dart';
import '../../domain/aroma_wheel_data.dart';
import '../../domain/fold.dart';
import '../../domain/ids.dart';
import '../format.dart';
import '../theme/cork_theme.dart';
import '../widgets/chalk.dart';
import 'aroma_wheel_view.dart';

/// Opens the descriptor picker sheet over the aroma wheel. Returns the new
/// selection, or null when dismissed without Done.
Future<Set<DescriptorId>?> showDescriptorPicker(
  BuildContext context, {
  required Set<DescriptorId> selected,
}) => showModalBottomSheet<Set<DescriptorId>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (_) => _DescriptorPicker(initial: selected),
);

class _DescriptorPicker extends StatefulWidget {
  const _DescriptorPicker({required this.initial});
  final Set<DescriptorId> initial;

  @override
  State<_DescriptorPicker> createState() => _DescriptorPickerState();
}

class _DescriptorPickerState extends State<_DescriptorPicker>
    with SingleTickerProviderStateMixin {
  // Ids this build does not know stay in the set, so an edit never drops them.
  late var _selected = Set<DescriptorId>.unmodifiable(widget.initial);
  // First read during build, so the Remove animations setting is in scope.
  late final _tabs = TabController(
    length: aromaWheel.categories.length,
    vsync: this,
    animationDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : CorkMotion.medium,
  )..addListener(_tabChanged);
  final _search = TextEditingController();
  var _query = '';

  AromaFamily get _current => aromaWheel.categories[_tabs.index].family;

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  void _tabChanged() => setState(() {});

  void _toggle(DescriptorId id, bool on) => setState(() {
    _selected = Set.unmodifiable(
      on ? {..._selected, id} : _selected.where((d) => d != id),
    );
  });

  void _showFamily(AromaFamily family) {
    setState(() {
      _search.clear();
      _query = '';
    });
    _tabs.animateTo(
      aromaWheel.categories.indexWhere((c) => c.family == family),
      curve: CorkMotion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wheelSide = (constraints.maxWidth - 2 * CorkSpace.gutter).clamp(
            0.0,
            constraints.maxHeight * 0.38,
          );
          return Column(
            children: [
              SizedBox.square(
                dimension: wheelSide,
                child: AromaWheelView(
                  current: _current,
                  selected: _selected,
                  onFamilyTap: _showFamily,
                ),
              ),
              const SizedBox(height: CorkSpace.md),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CorkSpace.gutter,
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search descriptors',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() {
                              _search.clear();
                              _query = '';
                            }),
                          ),
                  ),
                ),
              ),
              if (_query.trim().isEmpty) ...[
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final c in aromaWheel.categories) Tab(text: c.label),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      for (final c in aromaWheel.categories)
                        _ChipList(
                          sections: [
                            for (final s in c.subcategories)
                              (s.label, s.descriptors),
                          ],
                          selected: _selected,
                          onToggle: _toggle,
                        ),
                    ],
                  ),
                ),
              ] else
                Expanded(child: _results(text, scheme)),
              SafeArea(
                top: false,
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
                        child: Text(
                          _selected.isEmpty
                              ? 'Nothing picked yet'
                              : '${countLabel(_selected.length, 'descriptor')} picked',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, _selected),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _results(TextTheme text, ColorScheme scheme) {
    final q = fold(_query);
    final sections = [
      for (final c in aromaWheel.categories)
        (
          c.label,
          [
            for (final d in c.descriptors)
              if (fold(d.label).contains(q)) d,
          ],
        ),
    ].where((s) => s.$2.isNotEmpty).toList();
    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(CorkSpace.gutter),
        child: Text(
          'No descriptors match "${_query.trim()}".',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return _ChipList(
      sections: sections,
      selected: _selected,
      onToggle: _toggle,
    );
  }
}

/// Board-headed groups of descriptor chips.
class _ChipList extends StatelessWidget {
  const _ChipList({
    required this.sections,
    required this.selected,
    required this.onToggle,
  });

  final List<(String, List<Descriptor>)> sections;
  final Set<DescriptorId> selected;
  final void Function(DescriptorId id, bool on) onToggle;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: CorkSpace.lg),
    children: [
      for (final (heading, descriptors) in sections) ...[
        BoardHeading(heading),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
          child: Wrap(
            spacing: CorkSpace.sm,
            children: [
              for (final d in descriptors)
                _DescriptorChip(
                  descriptor: d,
                  selected: selected.contains(d.id),
                  onSelected: (on) => onToggle(d.id, on),
                ),
            ],
          ),
        ),
      ],
    ],
  );
}

class _DescriptorChip extends StatelessWidget {
  const _DescriptorChip({
    required this.descriptor,
    required this.selected,
    required this.onSelected,
  });

  final Descriptor descriptor;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(descriptor.label),
    selected: selected,
    showCheckmark: false,
    onSelected: onSelected,
    avatar: Center(
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: aromaColor(Theme.of(context).cork, descriptor.family),
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}
