import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/glass_color.dart';
import '../../domain/tasting.dart';
import '../../domain/wine.dart';
import '../theme/cork_theme.dart';
import '../widgets/chalk.dart';

GlassFamily glassFamilyFor(WineType? type) => switch (type) {
  WineType.red || WineType.fortified => GlassFamily.red,
  WineType.rose => GlassFamily.rose,
  WineType.white ||
  WineType.sparkling ||
  WineType.dessert ||
  null => GlassFamily.white,
};

class ScoreInput extends StatelessWidget {
  const ScoreInput({super.key, required this.score, required this.onChanged});
  final Score? score;
  final ValueChanged<Score> onChanged;

  static const _restingTenths = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final score = this.score;
    final tenths = score?.tenths ?? _restingTenths;
    final muted = score == null ? scheme.onSurfaceVariant : null;

    return Column(
      children: [
        SizedBox(
          height: 72,
          child: Center(
            child: score == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Set a score',
                        style: text.headlineSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Required',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : Text(
                    score.format(),
                    style: text.displayLarge?.copyWith(
                      color: theme.cork.score,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    semanticsLabel: 'Overall score ${score.format()}',
                  ),
          ),
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Lower score by 0.1',
              icon: const Icon(Icons.remove_rounded),
              onPressed: tenths > Score.min.tenths
                  ? () => onChanged(Score.fromTenths(tenths - 1))
                  : null,
            ),
            Expanded(
              child: Slider(
                value: tenths / 10,
                min: Score.min.value,
                max: Score.max.value,
                divisions: Score.max.tenths - Score.min.tenths,
                label: Score.fromTenths(tenths).format(),
                activeColor: muted,
                thumbColor: muted,
                semanticFormatterCallback: (v) =>
                    score == null ? 'Not set' : v.toStringAsFixed(1),
                onChanged: (v) => onChanged(Score.fromTenths((v * 10).round())),
              ),
            ),
            IconButton(
              tooltip: 'Raise score by 0.1',
              icon: const Icon(Icons.add_rounded),
              onPressed: tenths < Score.max.tenths
                  ? () => onChanged(Score.fromTenths(tenths + 1))
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class StarDots extends StatelessWidget {
  const StarDots({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Stars? value;
  final ValueChanged<Stars?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = value?.value ?? 0;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: true,
            selected: current == i,
            label: '$label $i of 5',
            excludeSemantics: true,
            child: InkResponse(
              radius: CorkSpace.minTouch / 2,
              onTap: () => onChanged(current == i ? null : Stars(i)),
              child: SizedBox.square(
                dimension: CorkSpace.minTouch,
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= current ? scheme.onSurface : null,
                      border: Border.all(
                        color: i <= current ? scheme.onSurface : scheme.outline,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class OrdinalPicker<T> extends StatelessWidget {
  const OrdinalPicker({
    super.key,
    required this.label,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final String Function(T) labelOf;
  final T? selected;
  final ValueChanged<T?> onChanged;

  static const _segmentPadding = CorkSpace.sm;

  static const _segmentSlack = CorkSpace.sm;

  bool _fits(BuildContext context, TextStyle style, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final v in values) {
      final painter = TextPainter(
        text: TextSpan(text: labelOf(v), style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = max(widest, painter.width);
      painter.dispose();
    }
    final segment = widest + 2 * _segmentPadding + _segmentSlack;
    return segment * values.length <= width;
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium!;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_fits(context, style, constraints.maxWidth)) {
          return Semantics(
            label: label,
            container: true,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              emptySelectionAllowed: true,
              expandedInsets: EdgeInsets.zero,
              style: SegmentedButton.styleFrom(
                textStyle: style,
                padding: const EdgeInsets.symmetric(
                  horizontal: _segmentPadding,
                ),
              ),
              segments: [
                for (final v in values)
                  ButtonSegment(value: v, label: Text(labelOf(v))),
              ],
              selected: {?selected},
              onSelectionChanged: (s) => onChanged(s.isEmpty ? null : s.single),
            ),
          );
        }
        return _SliderScale<T>(
          label: label,
          values: values,
          labelOf: labelOf,
          selected: selected,
          onChanged: onChanged,
        );
      },
    );
  }
}

class _SliderScale<T> extends StatelessWidget {
  const _SliderScale({
    required this.label,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final String Function(T) labelOf;
  final T? selected;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selected = this.selected;
    final index = selected == null ? null : values.indexOf(selected);
    final muted = index == null ? scheme.onSurfaceVariant : null;
    final ends = text.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: CorkSpace.minTouch,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected == null ? 'Not set' : labelOf(selected),
                  style: text.titleSmall?.copyWith(color: muted),
                ),
              ),
              if (selected != null)
                TextButton(
                  onPressed: () => onChanged(null),
                  child: Text('Clear', semanticsLabel: 'Clear $label'),
                ),
            ],
          ),
        ),
        Slider(
          value: (index ?? 0).toDouble(),
          max: (values.length - 1).toDouble(),
          divisions: values.length - 1,
          label: labelOf(values[index ?? 0]),
          activeColor: muted,
          thumbColor: muted,
          semanticFormatterCallback: (v) =>
              index == null ? 'Not set' : labelOf(values[v.round()]),
          onChanged: (v) => onChanged(values[v.round()]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CorkSpace.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(labelOf(values.first), style: ends),
              Text(labelOf(values.last), style: ends),
            ],
          ),
        ),
      ],
    );
  }
}

class ChoiceSegments<T> extends StatelessWidget {
  const ChoiceSegments({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<T>(
    showSelectedIcon: false,
    expandedInsets: EdgeInsets.zero,
    segments: [
      for (final v in values) ButtonSegment(value: v, label: Text(labelOf(v))),
    ],
    selected: {selected},
    onSelectionChanged: (s) => onChanged(s.single),
  );
}

class GlassPicker extends StatelessWidget {
  const GlassPicker({
    super.key,
    required this.family,
    required this.intensity,
    required this.color,
    required this.onFamily,
    required this.onIntensity,
    required this.onHue,
  });

  final GlassFamily family;
  final GlassIntensity intensity;
  final GlassColor? color;
  final ValueChanged<GlassFamily> onFamily;
  final ValueChanged<GlassIntensity> onIntensity;

  /// Null when the selected hue is tapped again.
  final ValueChanged<GlassHue?> onHue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    const gutter = EdgeInsets.symmetric(horizontal: CorkSpace.gutter);
    final color = this.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: gutter,
          child: ChoiceSegments(
            values: GlassFamily.values,
            labelOf: (f) => f.label,
            selected: family,
            onChanged: onFamily,
          ),
        ),
        const SizedBox(height: CorkSpace.sm),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: CorkSpace.gutter - CorkSpace.sm,
            ),
            children: [
              for (final hue in family.hues)
                _SwatchChoice(
                  color: GlassColor(hue, intensity),
                  selected: color?.hue == hue,
                  onTap: () => onHue(color?.hue == hue ? null : hue),
                ),
            ],
          ),
        ),
        const SizedBox(height: CorkSpace.sm),
        Padding(
          padding: gutter,
          child: ChoiceSegments(
            values: GlassIntensity.values,
            labelOf: (i) => i.label,
            selected: intensity,
            onChanged: onIntensity,
          ),
        ),
        const SizedBox(height: CorkSpace.md),
        Padding(
          padding: gutter,
          child: Text(
            color?.phrase ?? 'No colour picked',
            style: text.bodyMedium?.copyWith(
              color: color == null ? scheme.onSurfaceVariant : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _SwatchChoice extends StatelessWidget {
  const _SwatchChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final GlassColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: color.phrase,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: CorkRadius.card,
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlassSwatch(color, selected: selected),
              const SizedBox(height: CorkSpace.sm),
              Text(
                color.hue.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VintageField extends StatelessWidget {
  const VintageField({
    super.key,
    required this.controller,
    required this.nonVintage,
    required this.onChanged,
    required this.onNonVintage,
    this.errorText,
  });

  final TextEditingController controller;
  final bool nonVintage;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onNonVintage;
  final String? errorText;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: TextField(
          controller: controller,
          enabled: !nonVintage,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(
            labelText: 'Vintage',
            hintText: 'Year',
            errorText: errorText,
          ),
          onChanged: onChanged,
        ),
      ),
      const SizedBox(width: CorkSpace.md),
      Padding(
        padding: const EdgeInsets.only(top: CorkSpace.sm),
        child: FilterChip(
          label: const Text('NV'),
          tooltip: 'Non-vintage',
          selected: nonVintage,
          onSelected: onNonVintage,
        ),
      ),
    ],
  );
}

class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: CorkRadius.field,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: Icon(icon)),
        child: Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}

ButtonStyle shellTextButtonStyle(BuildContext context) {
  final cork = Theme.of(context).cork;
  return TextButton.styleFrom(
    foregroundColor: cork.onShell,
    disabledForegroundColor: cork.onShellVariant.withValues(alpha: 0.6),
  );
}

class FormSection extends StatelessWidget {
  const FormSection(this.heading, {super.key, required this.child});
  final String heading;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BoardHeading(heading),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
        child: child,
      ),
    ],
  );
}
