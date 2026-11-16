import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/aroma_wheel_data.dart';
import '../../domain/badges.dart';
import '../../domain/fold.dart';
import '../../domain/glass_color.dart';
import '../../domain/ids.dart';
import '../../domain/journal.dart';
import '../../domain/scales.dart';
import '../../domain/tasting.dart';
import '../../domain/wine.dart';
import '../format.dart';
import '../search/wine_search_screen.dart';
import '../theme/cork_theme.dart';
import '../widgets/chalk.dart';
import 'aroma_wheel_view.dart';
import 'cork_route.dart';
import 'descriptor_picker.dart';
import 'label_photo_picker.dart';
import 'tasting_controls.dart';

/// Opens the tasting form for a new tasting of [wine], or for [editing].
/// Resolves true when the tasting was saved or deleted.
Future<bool> openTastingForm(
  BuildContext context, {
  required Wine wine,
  Tasting? editing,
  Vintage? vintage,
}) async {
  final done = await Navigator.push<bool>(
    context,
    corkRoute(
      context,
      (_) => editing == null
          ? TastingFormScreen.create(wine: wine, vintage: vintage)
          : TastingFormScreen.edit(tasting: editing),
    ),
  );
  return done ?? false;
}

class TastingFormScreen extends ConsumerStatefulWidget {
  const TastingFormScreen.create({
    super.key,
    required Wine this.wine,
    this.vintage,
  }) : tasting = null;

  const TastingFormScreen.edit({super.key, required Tasting this.tasting})
    : wine = null,
      vintage = null;

  final Wine? wine;
  final Vintage? vintage;
  final Tasting? tasting;

  @override
  ConsumerState<TastingFormScreen> createState() => _TastingFormState();
}

enum _Menu { delete }

class _TastingFormState extends ConsumerState<TastingFormScreen> {
  late final TastingDraft _draft;
  late GlassFamily _family;
  late GlassIntensity _intensity;
  late final TextEditingController _vintage;
  late final TextEditingController _notes;
  late final TextEditingController _price;
  final _vintageKey = GlobalKey();
  final _priceKey = GlobalKey();

  var _removeFromWishlist = true;
  var _dirty = false;
  var _photoBusy = false;
  var _issues = <DraftField, String>{};

  @override
  void initState() {
    super.initState();
    final journal = ref.read(journalProvider);
    final currency = ref.read(settingsProvider).currency;
    final editing = widget.tasting;
    if (editing == null) {
      final wine = widget.wine!;
      _draft = TastingDraft.forWine(
        wine,
        now: DateTime.now(),
        currency: currency,
      );
      final vintage = widget.vintage ?? journal.wishlist[wine.id]?.vintage;
      if (vintage != null) _applyVintage(vintage);
    } else {
      _draft = TastingDraft.edit(
        editing,
        journal.wines[editing.wineId]!,
        defaultCurrency: currency,
      );
    }
    _family = _draft.color?.family ?? glassFamilyFor(_draft.wine.type);
    _intensity = _draft.color?.intensity ?? GlassIntensity.medium;
    _vintage = TextEditingController(text: _draft.vintageText);
    _notes = TextEditingController(text: _draft.notes);
    _price = TextEditingController(text: _draft.priceText);
  }

  @override
  void dispose() {
    _vintage.dispose();
    _notes.dispose();
    _price.dispose();
    super.dispose();
  }

  void _applyVintage(Vintage vintage) {
    switch (vintage) {
      case VintageYear(:final year):
        _draft
          ..vintageText = '$year'
          ..nonVintage = false;
      case NonVintage():
        _draft.nonVintage = true;
    }
  }

  /// Every user change goes through here, so the discard guard knows.
  void _edit(VoidCallback change, [DraftField? clears]) => setState(() {
    change();
    _dirty = true;
    if (clears != null) _issues = {..._issues}..remove(clears);
  });

  bool get _instant => MediaQuery.disableAnimationsOf(context);

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _changeWine() async {
    final picked = await pickWine(context);
    if (picked == null || !mounted) return;
    _edit(() {
      _draft.wine = picked.wine;
      if (picked.vintage case final v?) {
        _applyVintage(v);
        _vintage.text = _draft.vintageText;
      }
      _removeFromWishlist = true;
      if (_draft.color == null) _family = glassFamilyFor(picked.wine.type);
    });
  }

  void _setFamily(GlassFamily family) => _edit(() {
    _family = family;
    if (_draft.color?.family != family) _draft.color = null;
    if (family == GlassFamily.white) _draft.tannin = null;
  });

  void _setIntensity(GlassIntensity intensity) => _edit(() {
    _intensity = intensity;
    if (_draft.color case final c?) _draft.color = GlassColor(c.hue, intensity);
  });

  Future<void> _pickDate() async {
    final at = _draft.tastedAt;
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: at,
      firstDate: DateTime(1900),
      lastDate: at.isAfter(now) ? at : now,
    );
    if (day == null || !mounted) return;
    _edit(
      () => _draft.tastedAt = DateTime(
        day.year,
        day.month,
        day.day,
        at.hour,
        at.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final at = _draft.tastedAt;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(at),
    );
    if (time == null || !mounted) return;
    _edit(
      () => _draft.tastedAt = DateTime(
        at.year,
        at.month,
        at.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _addDescriptors() async {
    final picked = await showDescriptorPicker(
      context,
      selected: _draft.descriptors,
    );
    if (picked == null || !mounted || setEquals(picked, _draft.descriptors)) {
      return;
    }
    _edit(() => _draft.descriptors = {...picked});
  }

  Future<void> _addPhoto(ImageSource source) async {
    final picker = LabelPhotoPickerScope.of(context);
    final photos = ref.read(photoStoreProvider);
    setState(() => _photoBusy = true);
    try {
      final bytes = await picker.pick(source);
      if (bytes == null) return;
      final photo = await photos.add(bytes);
      if (mounted) _edit(() => _draft.photo = photo);
    } on PlatformException {
      if (mounted) {
        _say(
          source == ImageSource.camera
              ? "Couldn't open the camera. Check Cork's camera permission."
              : "Couldn't open your photos. Check Cork's photo permission.",
        );
      }
    } on FileSystemException {
      if (mounted) _say("Couldn't save the photo. Check free storage.");
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _save() {
    final store = ref.read(journalStoreProvider);
    switch (_draft.build()) {
      case Invalid(:final issues):
        setState(() => _issues = {for (final i in issues) i.field: i.message});
        final key = switch (issues.first.field) {
          DraftField.vintage => _vintageKey,
          DraftField.price => _priceKey,
          DraftField.score => null,
        };
        if (key?.currentContext case final field?) {
          Scrollable.ensureVisible(
            field,
            alignment: 0.3,
            duration: _instant ? Duration.zero : CorkMotion.medium,
            curve: CorkMotion.standard,
          );
        }
      case Valid(value: final tasting):
        final before = store.journal;
        final previous = before.wishlist[tasting.wineId];
        final remove = previous != null && _removeFromWishlist;
        final after = store.commit([
          AdoptWine(_draft.wine),
          SaveTasting(tasting, removeFromWishlist: remove),
        ]);
        ref.read(lastSavedProvider.notifier).mark(tasting.id);
        final earned = newlyEarned(before, after);
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context, true);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(_savedMessage(remove, earned)),
              action: previous != null && remove
                  ? SnackBarAction(
                      label: 'Undo',
                      onPressed: () => store.commit([Wishlist(previous)]),
                    )
                  : null,
            ),
          );
    }
  }

  Future<void> _delete() async {
    final delete = await showDialog<bool>(
      context: context,
      animationStyle: _instant ? AnimationStyle.noAnimation : null,
      builder: (context) => AlertDialog(
        title: const Text('Delete this tasting?'),
        content: const Text('Stats and badges will update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete != true || !mounted) return;
    ref.read(journalStoreProvider).commit([DeleteTasting(_draft.id!)]);
    Navigator.pop(context, true);
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      animationStyle: _instant ? AnimationStyle.noAnimation : null,
      builder: (context) => AlertDialog(
        title: Text(
          _draft.isEdit ? 'Discard your changes?' : 'Discard this tasting?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final journal = ref.watch(journalProvider);
    final canSave = _draft.score != null;

    return PopScope<bool>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !await _confirmDiscard()) return;
        if (context.mounted) Navigator.pop(context, false);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(_draft.isEdit ? 'Edit tasting' : 'New tasting'),
          actions: [
            TextButton(
              style: shellTextButtonStyle(context),
              onPressed: canSave ? _save : null,
              child: const Text('Save'),
            ),
            if (_draft.isEdit)
              PopupMenuButton<_Menu>(
                tooltip: 'More',
                onSelected: (_) => _delete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _Menu.delete,
                    child: Text('Delete tasting'),
                  ),
                ],
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: CorkSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CorkSpace.gutter,
                        CorkSpace.lg,
                        CorkSpace.gutter,
                        0,
                      ),
                      child: _wineCard(journal),
                    ),
                    const BoardHeading('Overall'),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CorkSpace.xs,
                      ),
                      child: ScoreInput(
                        score: _draft.score,
                        onChanged: (s) =>
                            _edit(() => _draft.score = s, DraftField.score),
                      ),
                    ),
                    const BoardHeading('Glass'),
                    GlassPicker(
                      family: _family,
                      intensity: _intensity,
                      color: _draft.color,
                      onFamily: _setFamily,
                      onIntensity: _setIntensity,
                      onHue: (hue) => _edit(
                        () => _draft.color = hue == null
                            ? null
                            : GlassColor(hue, _intensity),
                      ),
                    ),
                    _noseAndPalate(),
                    FormSection(
                      'Sweetness',
                      child: OrdinalPicker<Sweetness>(
                        label: 'Sweetness',
                        values: Sweetness.values,
                        labelOf: (s) => s.label,
                        selected: _draft.sweetness,
                        onChanged: (s) => _edit(() => _draft.sweetness = s),
                      ),
                    ),
                    const BoardHeading('Structure'),
                    _structure(),
                    _notesSection(),
                    _contextSection(journal),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CorkSpace.gutter,
                        CorkSpace.xl,
                        CorkSpace.gutter,
                        0,
                      ),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            CorkSpace.minTouch,
                          ),
                        ),
                        onPressed: canSave ? _save : null,
                        child: const Text('Save tasting'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wineCard(Journal journal) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final wine = _draft.wine;
    final place = placeOf(wine);
    final onWishlist = journal.wishlist.containsKey(wine.id);
    final muted = scheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CorkSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(wine.name, style: text.titleMedium),
                      if (wine.winery case final winery?)
                        Text(
                          winery,
                          style: text.bodyMedium?.copyWith(color: muted),
                        ),
                      if (place.isNotEmpty)
                        Text(
                          place,
                          style: text.bodySmall?.copyWith(color: muted),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _changeWine,
                  child: const Text('Change', semanticsLabel: 'Change wine'),
                ),
              ],
            ),
            const SizedBox(height: CorkSpace.lg),
            KeyedSubtree(
              key: _vintageKey,
              child: VintageField(
                controller: _vintage,
                nonVintage: _draft.nonVintage,
                errorText: _issues[DraftField.vintage],
                onChanged: (v) =>
                    _edit(() => _draft.vintageText = v, DraftField.vintage),
                onNonVintage: (nv) =>
                    _edit(() => _draft.nonVintage = nv, DraftField.vintage),
              ),
            ),
            if (onWishlist) ...[
              const SizedBox(height: CorkSpace.sm),
              MergeSemantics(
                child: Row(
                  children: [
                    Icon(
                      Icons.bookmark_rounded,
                      size: 20,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: CorkSpace.sm),
                    Expanded(
                      child: Text(
                        'On your wishlist. Remove it when you save?',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.tertiary,
                        ),
                      ),
                    ),
                    Switch(
                      value: _removeFromWishlist,
                      activeTrackColor: scheme.tertiary,
                      activeThumbColor: scheme.onTertiary,
                      onChanged: (on) => _edit(() => _removeFromWishlist = on),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _noseAndPalate() => FormSection(
    'Nose and palate',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StarDots(
          label: 'Aroma',
          value: _draft.aroma,
          onChanged: (s) => _edit(() => _draft.aroma = s),
        ),
        StarDots(
          label: 'Flavor',
          value: _draft.flavor,
          onChanged: (s) => _edit(() => _draft.flavor = s),
        ),
        StarDots(
          label: 'Finish',
          value: _draft.finish,
          onChanged: (s) => _edit(() => _draft.finish = s),
        ),
        const SizedBox(height: CorkSpace.xs),
        OrdinalPicker<FinishLength>(
          label: 'Finish length',
          values: FinishLength.values,
          labelOf: (l) => l.label,
          selected: _draft.finishLength,
          onChanged: (l) => _edit(() => _draft.finishLength = l),
        ),
      ],
    ),
  );

  Widget _structure() {
    final scales = <(String, Level?, void Function(Level?))>[
      ('Body', _draft.body, (l) => _draft.body = l),
      ('Acidity', _draft.acidity, (l) => _draft.acidity = l),
      if (_family != GlassFamily.white)
        ('Tannin', _draft.tannin, (l) => _draft.tannin = l),
    ];
    final summary = [
      for (final (name, level, _) in scales)
        if (level != null) '${level.label} ${name.toLowerCase()}',
    ].join(' · ');
    final text = Theme.of(context).textTheme;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
      childrenPadding: const EdgeInsets.fromLTRB(
        CorkSpace.gutter,
        0,
        CorkSpace.gutter,
        CorkSpace.sm,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      expansionAnimationStyle: _instant ? AnimationStyle.noAnimation : null,
      title: const Text('Body, acidity, tannin'),
      subtitle: summary.isEmpty ? null : Text(summary),
      children: [
        for (final (name, level, set) in scales) ...[
          const SizedBox(height: CorkSpace.sm),
          Text(name, style: text.bodyLarge),
          const SizedBox(height: CorkSpace.sm),
          OrdinalPicker<Level>(
            label: name,
            values: Level.values,
            labelOf: (l) => l.shortLabel,
            selected: level,
            onChanged: (l) => _edit(() => set(l)),
          ),
        ],
      ],
    );
  }

  Widget _notesSection() {
    final cork = Theme.of(context).cork;
    return FormSection(
      'Notes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_draft.descriptors.isNotEmpty) ...[
            Wrap(
              spacing: CorkSpace.sm,
              children: [
                for (final d in _draft.descriptors.map(aromaWheel.resolve))
                  InputChip(
                    label: Text(d.label),
                    avatar: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: aromaColor(cork, d.family),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    deleteButtonTooltipMessage: 'Remove ${d.label}',
                    onDeleted: () => _edit(
                      () => _draft.descriptors = {
                        for (final other in _draft.descriptors)
                          if (other != d.id) other,
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: CorkSpace.sm),
          ],
          FilledButton.tonalIcon(
            onPressed: _addDescriptors,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add descriptors'),
          ),
          const SizedBox(height: CorkSpace.lg),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes',
              alignLabelWithHint: true,
            ),
            onChanged: (v) => _edit(() => _draft.notes = v),
          ),
        ],
      ),
    );
  }

  Widget _contextSection(Journal journal) {
    final at = _draft.tastedAt;
    final currencies = {...commonCurrencies, _draft.currency}.toList();
    return FormSection(
      'Context',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: PickerField(
                  label: 'Date',
                  value: fullDate(at),
                  icon: Icons.calendar_today_rounded,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: CorkSpace.md),
              Expanded(
                child: PickerField(
                  label: 'Time',
                  value: timeLabel(at),
                  icon: Icons.schedule_rounded,
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: CorkSpace.lg),
          _WhereField(
            initial: _draft.place,
            places: _pastPlaces(journal),
            onChanged: (p) => _edit(() => _draft.place = p),
          ),
          const SizedBox(height: CorkSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: _priceKey,
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Price',
                      errorText: _issues[DraftField.price],
                    ),
                    onChanged: (v) =>
                        _edit(() => _draft.priceText = v, DraftField.price),
                  ),
                ),
              ),
              const SizedBox(width: CorkSpace.md),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<CurrencyCode>(
                  initialValue: _draft.currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: [
                    for (final c in currencies)
                      DropdownMenuItem(value: c, child: Text(c.code)),
                  ],
                  onChanged: (c) {
                    if (c != null) {
                      _edit(() => _draft.currency = c, DraftField.price);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: CorkSpace.lg),
          _PhotoTile(
            photo: _draft.photo,
            busy: _photoBusy,
            onPick: _addPhoto,
            onRemove: () => _edit(() => _draft.photo = null),
          ),
        ],
      ),
    );
  }
}

/// Places from past tastings, most recent first, one per folded spelling.
List<String> _pastPlaces(Journal journal) {
  final seen = <String>{};
  return [
    for (final e in journal.feed)
      if (e.tasting.place case final p? when seen.add(fold(p))) p,
  ];
}

class _WhereField extends StatelessWidget {
  const _WhereField({
    required this.initial,
    required this.places,
    required this.onChanged,
  });

  final String initial;
  final List<String> places;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Autocomplete<String>(
    initialValue: TextEditingValue(text: initial),
    optionsBuilder: (value) {
      final q = fold(value.text);
      return places
          .where((p) => q.isEmpty || (fold(p).contains(q) && fold(p) != q))
          .take(6);
    },
    onSelected: onChanged,
    fieldViewBuilder: (context, controller, focus, submit) => TextField(
      controller: controller,
      focusNode: focus,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Where',
        prefixIcon: Icon(Icons.place_outlined),
      ),
      onChanged: onChanged,
      onSubmitted: (_) => submit(),
    ),
  );
}

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({
    required this.photo,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });

  final PhotoRef? photo;
  final bool busy;
  final ValueChanged<ImageSource> onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final photo = this.photo;
    final Widget body;
    if (photo == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Label photo', style: text.titleSmall),
          const SizedBox(height: CorkSpace.md),
          Wrap(
            spacing: CorkSpace.sm,
            runSpacing: CorkSpace.sm,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : () => onPick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take photo'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => onPick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from gallery'),
              ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: CorkSpace.md),
            const LinearProgressIndicator(semanticsLabel: 'Adding photo'),
          ],
        ],
      );
    } else {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      body = Row(
        children: [
          ClipRRect(
            borderRadius: CorkRadius.card,
            child: Image.file(
              ref.watch(photoStoreProvider).fileFor(photo),
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              cacheWidth: (88 * dpr).round(),
              semanticLabel: 'Label photo',
              errorBuilder: (_, _, _) => SizedBox.square(
                dimension: 88,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: CorkSpace.lg),
          Expanded(child: Text('Label photo', style: text.titleSmall)),
          TextButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Remove', semanticsLabel: 'Remove photo'),
          ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: CorkRadius.card,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(CorkSpace.md), child: body),
    );
  }
}

String _savedMessage(bool removedFromWishlist, List<BadgeRule> earned) => [
  'Tasting saved',
  if (removedFromWishlist) 'Removed from wishlist',
  if (earned.length == 1)
    'Badge earned: ${earned.single.title}'
  else if (earned.length > 1)
    'Badges earned: ${earned.map((b) => b.title).join(', ')}',
].join(' · ');
