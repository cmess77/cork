import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/fold.dart';
import '../../domain/ids.dart';
import '../../domain/journal.dart';
import '../../domain/tasting.dart';
import '../../domain/wine.dart';
import '../tasting/tasting_controls.dart';
import '../theme/cork_theme.dart';
import '../widgets/chalk.dart';
import 'wine_countries.dart';

/// What happens to a newly entered wine: the caller logs it, wishlists it,
/// or hands it back. Resolves true when the wine was used, which closes the
/// form; false leaves the form open with its fields intact.
typedef WineCreated =
    Future<bool> Function(BuildContext context, Wine wine, Vintage? vintage);

/// Hand entry of a wine the index and Open Food Facts do not have, or an edit
/// of a wine already in the journal.
class ManualWineScreen extends ConsumerStatefulWidget {
  const ManualWineScreen({
    super.key,
    this.initialName = '',
    required WineCreated this.onCreated,
  }) : editing = null;

  /// Commits [EditWine] and pops true on save.
  const ManualWineScreen.edit({super.key, required Wine wine})
    : editing = wine,
      initialName = '',
      onCreated = null;

  final String initialName;
  final WineCreated? onCreated;
  final Wine? editing;

  @override
  ConsumerState<ManualWineScreen> createState() => _ManualWineState();
}

class _ManualWineState extends ConsumerState<ManualWineScreen> {
  // One id per form, so going back from the tasting form and saving again
  // still describes the same wine.
  late final _id = widget.editing?.id ?? WineId.mintManual();
  late final _name = TextEditingController(
    text: widget.editing?.name ?? widget.initialName,
  );
  late final _winery = TextEditingController(text: widget.editing?.winery);
  late final _region = TextEditingController(text: widget.editing?.region);
  final _grapeInput = TextEditingController();
  final _vintage = TextEditingController();
  late var _country = widget.editing?.country?.name ?? '';
  late var _type = widget.editing?.type;
  late final _grapes = [...?widget.editing?.grapes];
  var _nonVintage = false;

  String? _nameError;
  String? _typeError;
  String? _vintageError;

  @override
  void dispose() {
    _name.dispose();
    _winery.dispose();
    _region.dispose();
    _grapeInput.dispose();
    _vintage.dispose();
    super.dispose();
  }

  void _addGrapes(Iterable<String> names) {
    for (final raw in names) {
      final grape = raw.trim();
      if (grape.isEmpty) continue;
      if (_grapes.any((g) => fold(g) == fold(grape))) continue;
      _grapes.add(grape);
    }
  }

  void _grapeTyped(String text) {
    if (!text.contains(',')) return;
    final parts = text.split(',');
    final rest = parts.removeLast();
    setState(() => _addGrapes(parts));
    _grapeInput.value = TextEditingValue(
      text: rest,
      selection: TextSelection.collapsed(offset: rest.length),
    );
  }

  void _commitGrapeInput() {
    if (_grapeInput.text.trim().isEmpty) return;
    setState(() => _addGrapes([_grapeInput.text]));
    _grapeInput.clear();
  }

  Country? _resolvedCountry() {
    final typed = fold(_country);
    if (typed.isEmpty) return null;
    final original = widget.editing?.country;
    if (original != null && fold(original.name) == typed) return original;
    for (final c in wineCountries) {
      if (fold(c.name) == typed) return c;
    }
    return Country(null, _country.trim());
  }

  String? _optional(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    _commitGrapeInput();
    final name = _name.text.trim();
    Vintage? vintage;
    String? vintageError;
    if (_nonVintage) {
      vintage = const NonVintage();
    } else if (_vintage.text.trim().isNotEmpty) {
      vintage = Vintage.tryParse(_vintage.text);
      if (vintage == null) {
        vintageError =
            'Enter a year from ${Vintage.earliest} to ${Vintage.latest}';
      }
    }
    setState(() {
      _nameError = name.isEmpty ? "Enter the wine's name" : null;
      _typeError = _type == null ? 'Pick a type' : null;
      _vintageError = vintageError;
    });
    final type = _type;
    if (name.isEmpty || type == null || vintageError != null) return;

    final editing = widget.editing;
    if (editing != null) {
      ref.read(journalStoreProvider).commit([
        EditWine(
          editing.copyWith(
            name: name,
            winery: () => _optional(_winery),
            type: () => type,
            grapes: [..._grapes],
            region: () => _optional(_region),
            country: _resolvedCountry,
          ),
        ),
      ]);
      Navigator.pop(context, true);
      return;
    }

    final wine = Wine.manual(
      id: _id,
      name: name,
      type: type,
      winery: _optional(_winery),
      grapes: [..._grapes],
      region: _optional(_region),
      country: _resolvedCountry(),
    );
    final used = await widget.onCreated!(context, wine, vintage);
    if (used && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final editing = widget.editing;
    const gap = SizedBox(height: CorkSpace.lg);

    return Scaffold(
      appBar: AppBar(
        title: Text(editing == null ? 'Add a wine' : 'Edit wine'),
        actions: [
          TextButton(
            style: shellTextButtonStyle(context),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            // A Column, not a ListView: error lines and grape chips come and
            // go above later fields, and a Column keeps each field's state.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(CorkSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    autofocus: editing == null && widget.initialName.isEmpty,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      helperText: 'Required',
                      errorText: _nameError,
                    ),
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                  ),
                  gap,
                  TextField(
                    controller: _winery,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Winery'),
                  ),
                  gap,
                  Text('Type', style: text.titleSmall),
                  const SizedBox(height: CorkSpace.sm),
                  Wrap(
                    spacing: CorkSpace.sm,
                    children: [
                      for (final t in WineType.values)
                        ChoiceChip(
                          label: Text(t.label),
                          avatar: Center(child: TypeDot(t, size: 10)),
                          selected: _type == t,
                          onSelected: (_) => setState(() {
                            _type = t;
                            _typeError = null;
                          }),
                        ),
                    ],
                  ),
                  if (_typeError case final error?)
                    Padding(
                      padding: const EdgeInsets.only(top: CorkSpace.xs),
                      child: Text(
                        error,
                        style: text.bodySmall?.copyWith(color: scheme.error),
                      ),
                    ),
                  gap,
                  if (_grapes.isNotEmpty) ...[
                    Wrap(
                      spacing: CorkSpace.sm,
                      children: [
                        for (final g in _grapes)
                          InputChip(
                            label: Text(g),
                            deleteButtonTooltipMessage: 'Remove $g',
                            onDeleted: () => setState(() => _grapes.remove(g)),
                          ),
                      ],
                    ),
                    const SizedBox(height: CorkSpace.sm),
                  ],
                  TextField(
                    controller: _grapeInput,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Grapes',
                      helperText: 'Press enter or type a comma after each',
                    ),
                    onChanged: _grapeTyped,
                    onSubmitted: (_) => _commitGrapeInput(),
                    // Keeps the keyboard up so the next grape can follow.
                    onEditingComplete: () {},
                  ),
                  gap,
                  TextField(
                    controller: _region,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Region'),
                  ),
                  gap,
                  Autocomplete<Country>(
                    initialValue: TextEditingValue(text: _country),
                    displayStringForOption: (c) => c.name,
                    optionsBuilder: (value) {
                      final q = fold(value.text);
                      if (q.isEmpty) return const [];
                      return wineCountries
                          .where((c) => fold(c.name).contains(q))
                          .take(8);
                    },
                    onSelected: (c) => _country = c.name,
                    fieldViewBuilder: (context, controller, focus, submit) =>
                        TextField(
                          controller: controller,
                          focusNode: focus,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Country',
                          ),
                          onChanged: (v) => _country = v,
                          onSubmitted: (_) => submit(),
                        ),
                  ),
                  if (editing == null) ...[
                    gap,
                    VintageField(
                      controller: _vintage,
                      nonVintage: _nonVintage,
                      errorText: _vintageError,
                      onChanged: (_) {
                        if (_vintageError != null) {
                          setState(() => _vintageError = null);
                        }
                      },
                      onNonVintage: (nv) => setState(() {
                        _nonVintage = nv;
                        _vintageError = null;
                      }),
                    ),
                  ],
                  const SizedBox(height: CorkSpace.xl),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(CorkSpace.minTouch),
                    ),
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
