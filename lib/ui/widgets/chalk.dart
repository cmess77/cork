import 'package:flutter/material.dart';

import '../../domain/glass_color.dart';
import '../../domain/tasting.dart';
import '../../domain/wine.dart';
import '../theme/cork_theme.dart';
import '../theme/glass_colors.dart';

class BoardHeading extends StatelessWidget {
  const BoardHeading(this.text, {super.key, this.padding});
  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding:
        padding ??
        const EdgeInsets.fromLTRB(
          CorkSpace.gutter,
          CorkSpace.xl,
          CorkSpace.gutter,
          CorkSpace.sm,
        ),
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).cork.boardHeading,
      ),
    ),
  );
}

class ScoreText extends StatelessWidget {
  const ScoreText(this.score, {super.key, this.style});
  final Score score;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    score.format(),
    textAlign: TextAlign.right,
    style: style ?? Theme.of(context).cork.scoreNumeral,
    semanticsLabel: 'Score ${score.format()}',
  );
}

Color typeSeriesColor(BuildContext context, WineType type) {
  final t = Theme.of(context).cork;
  return switch (type) {
    WineType.red => t.typeRed,
    WineType.white => t.typeWhite,
    WineType.rose => t.typeRose,
    WineType.sparkling => t.typeSparkling,
    WineType.dessert || WineType.fortified => t.typeDessert,
  };
}

class TypeDot extends StatelessWidget {
  const TypeDot(this.type, {super.key, this.size = 12});
  final WineType type;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: typeSeriesColor(context, type),
      shape: BoxShape.circle,
    ),
  );
}

class GlassSwatch extends StatelessWidget {
  const GlassSwatch(
    this.color, {
    super.key,
    this.size = 48,
    this.selected = false,
  });
  final GlassColor? color;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = color;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: glassTablecloth,
        border: Border.all(color: Slate.s8, width: 1),
        boxShadow: selected
            ? [BoxShadow(color: scheme.primary, spreadRadius: 3)]
            : null,
      ),
      alignment: Alignment.center,
      child: c == null
          ? Icon(Icons.wine_bar_outlined, size: size * 0.5, color: Slate.s7)
          : Container(
              width: size * 0.75,
              height: size * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glassDisplayColor(c.hue, c.intensity),
              ),
            ),
    );
  }
}
