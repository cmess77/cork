import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/aroma_wheel.dart';
import '../../domain/aroma_wheel_data.dart';
import '../../domain/ids.dart';
import '../theme/cork_theme.dart';

Color aromaColor(CorkTokens tokens, AromaFamily family) => switch (family) {
  AromaFamily.fruit => tokens.aromaFruit,
  AromaFamily.floral => tokens.aromaFloral,
  AromaFamily.herbal => tokens.aromaHerbal,
  AromaFamily.spice => tokens.aromaSpice,
  AromaFamily.earth => tokens.aromaEarth,
  AromaFamily.oak => tokens.aromaOak,
  AromaFamily.yeast => tokens.aromaYeast,
  AromaFamily.oxidative => tokens.aromaOxidative,
};

/// A span of the wheel in radians, clockwise from twelve o'clock.
typedef Arc = ({double start, double sweep});

typedef DescriptorArc = ({Descriptor descriptor, Arc arc});
typedef SubcategoryArc = ({Arc arc, List<DescriptorArc> descriptors});
typedef CategoryArc = ({
  AromaFamily family,
  Arc arc,
  List<SubcategoryArc> subcategories,
});

/// Every descriptor gets the same slice, so a category's wedge is as wide as
/// its vocabulary.
final List<CategoryArc> _arcs = () {
  final slice = 2 * pi / aromaWheel.descriptors.length;
  var index = 0;
  Arc span(int count) => (start: index * slice, sweep: count * slice);
  final out = <CategoryArc>[];
  for (final c in aromaWheel.categories) {
    final categoryArc = span(c.descriptors.length);
    final subs = <SubcategoryArc>[];
    for (final s in c.subcategories) {
      final subArc = span(s.descriptors.length);
      final ds = <DescriptorArc>[];
      for (final d in s.descriptors) {
        ds.add((descriptor: d, arc: span(1)));
        index++;
      }
      subs.add((arc: subArc, descriptors: ds));
    }
    out.add((family: c.family, arc: categoryArc, subcategories: subs));
  }
  return out;
}();

/// Ring radii as fractions of the wheel radius: hub, category, subcategory,
/// descriptor.
const _hub = 0.32;
const _categoryOuter = 0.54;
const _subcategoryOuter = 0.75;

/// Where things sit on a wheel drawn into a square of [size].
final class AromaWheelGeometry {
  const AromaWheelGeometry(this.size);
  final Size size;

  Offset get center => size.center(Offset.zero);
  double get radius => size.shortestSide / 2;

  /// The category whose wedge holds [local], in any ring. Null in the hub
  /// and outside the wheel.
  AromaFamily? familyAt(Offset local) {
    final v = local - center;
    final d = v.distance;
    if (d < radius * _hub || d > radius) return null;
    final angle = (atan2(v.dy, v.dx) + pi / 2) % (2 * pi);
    for (final c in _arcs) {
      if (angle >= c.arc.start && angle < c.arc.start + c.arc.sweep) {
        return c.family;
      }
    }
    return null;
  }

  /// The middle of [family]'s segment in the category ring.
  Offset anchorOf(AromaFamily family) {
    final arc = _arcs.firstWhere((c) => c.family == family).arc;
    final angle = arc.start + arc.sweep / 2 - pi / 2;
    final r = radius * (_hub + _categoryOuter) / 2;
    return center + Offset(cos(angle), sin(angle)) * r;
  }
}

/// The aroma wheel as a reference: the current category and every selected
/// descriptor in full colour, everything else dimmed. Tapping a wedge reports
/// its category.
class AromaWheelView extends StatelessWidget {
  const AromaWheelView({
    super.key,
    required this.current,
    required this.selected,
    required this.onFamilyTap,
  });

  final AromaFamily current;
  final Set<DescriptorId> selected;
  final ValueChanged<AromaFamily> onFamilyTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final geometry = AromaWheelGeometry(Size.square(side));
        return Semantics(
          container: true,
          label: _semanticsLabel(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final family = geometry.familyAt(details.localPosition);
              if (family != null) onFamilyTap(family);
            },
            child: CustomPaint(
              size: Size.square(side),
              painter: _WheelPainter(
                colors: {
                  for (final f in AromaFamily.values)
                    f: aromaColor(theme.cork, f),
                },
                ground: theme.colorScheme.surfaceContainerLow,
                current: current,
                selected: selected,
                hubLabel: TextSpan(
                  text: current.label,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _semanticsLabel() {
    final counts = {
      for (final f in AromaFamily.values)
        f: selected.where((id) => aromaWheel.resolve(id).family == f).length,
    };
    final picked = [
      for (final MapEntry(key: f, value: n) in counts.entries)
        if (n > 0) '$n ${f.label}',
    ];
    final total = counts.values.fold(0, (a, b) => a + b);
    return [
      'Aroma wheel, showing ${current.label}',
      total == 0
          ? 'no descriptors selected'
          : '$total selected: ${picked.join(', ')}',
    ].join('. ');
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.colors,
    required this.ground,
    required this.current,
    required this.selected,
    required this.hubLabel,
  });

  final Map<AromaFamily, Color> colors;
  final Color ground;
  final AromaFamily current;
  final Set<DescriptorId> selected;
  final TextSpan hubLabel;

  static const _dimmed = 0.28;
  static const _faint = 0.14;

  @override
  void paint(Canvas canvas, Size size) {
    final g = AromaWheelGeometry(size);
    final r = g.radius;
    final gap = Paint()
      ..color = ground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    void sector(Arc arc, double inner, double outer, Color color) {
      final path = _sector(g.center, r * inner, r * outer, arc);
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, gap);
    }

    for (final c in _arcs) {
      final color = colors[c.family]!;
      final isCurrent = c.family == current;
      final ringColor = isCurrent ? color : color.withValues(alpha: _dimmed);
      sector(c.arc, _hub, _categoryOuter, ringColor);
      for (final s in c.subcategories) {
        sector(s.arc, _categoryOuter, _subcategoryOuter, ringColor);
        for (final d in s.descriptors) {
          final on = selected.contains(d.descriptor.id);
          sector(
            d.arc,
            _subcategoryOuter,
            1,
            on ? color : color.withValues(alpha: isCurrent ? _dimmed : _faint),
          );
        }
      }
    }

    final label = TextPainter(
      text: hubLabel,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: r * _hub * 1.8);
    label.paint(canvas, g.center - Offset(label.width, label.height) / 2);
    label.dispose();
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.current != current ||
      !setEquals(old.selected, selected) ||
      old.ground != ground ||
      old.hubLabel != hubLabel ||
      !_sameColors(old.colors);

  bool _sameColors(Map<AromaFamily, Color> other) =>
      AromaFamily.values.every((f) => other[f] == colors[f]);
}

Path _sector(Offset c, double inner, double outer, Arc arc) {
  final start = arc.start - pi / 2;
  return Path()
    ..arcTo(Rect.fromCircle(center: c, radius: outer), start, arc.sweep, true)
    ..arcTo(
      Rect.fromCircle(center: c, radius: inner),
      start + arc.sweep,
      -arc.sweep,
      false,
    )
    ..close();
}
