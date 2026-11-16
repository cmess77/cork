import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/glass_color.dart';
import '../../domain/tasting.dart';
import '../../domain/wine.dart';
import '../theme/cork_theme.dart';
import '../theme/glass_colors.dart';

/// Board heading: condensed caps, the cellar-door chalkboard's sign-writing.
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

/// A score chalked in yellow: tabular figures, meant to sit right-aligned.
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

/// The colour a wine type uses in stats and search rows.
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

/// A 48dp tablecloth disc with the glass colour inside, so colour is judged
/// against white the WSET way. Water-white needs the hairline to read.
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

/// The signature: a dry-brush stroke in the tasting's glass colour, seeded
/// from the tasting id so it is stable across rebuilds. When [drawIn] is set
/// it draws left to right once; with animations off it appears complete.
class ChalkSwipe extends StatefulWidget {
  const ChalkSwipe({
    super.key,
    required this.color,
    required this.seed,
    this.drawIn = false,
    this.width = CorkTokens.swipeWidth,
  });

  final GlassColor? color;
  final String seed;
  final bool drawIn;
  final double width;

  @override
  State<ChalkSwipe> createState() => _ChalkSwipeState();
}

class _ChalkSwipeState extends State<ChalkSwipe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  var _drawn = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: CorkMotion.swipe,
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.drawIn && !_drawn && !MediaQuery.disableAnimationsOf(context)) {
      _drawn = true;
      _progress.value = 0;
      _progress.animateTo(1, curve: CorkMotion.emphasizedDecelerate);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    if (c == null) {
      return SizedBox(height: CorkTokens.swipeHeight, width: widget.width);
    }
    final light = Theme.of(context).brightness == Brightness.light;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) => CustomPaint(
          size: Size(widget.width, CorkTokens.swipeHeight),
          painter: _SwipePainter(
            color: glassDisplayColor(c.hue, c.intensity),
            seed: _stableHash(widget.seed),
            progress: _progress.value,
            underlay: light && c.family == GlassFamily.white ? Slate.s8 : null,
          ),
        ),
      ),
    );
  }
}

class _SwipePainter extends CustomPainter {
  _SwipePainter({
    required this.color,
    required this.seed,
    required this.progress,
    this.underlay,
  });

  final Color color;
  final int seed;
  final double progress;
  final Color? underlay;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final w = size.width * progress;
    final h = size.height;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, -1, w, h + 2));

    if (underlay != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, h - 1, size.width, 1),
        Paint()..color = underlay!,
      );
    }

    // Thin horizontal strands with ragged ends read as dry brush; a few
    // strands stop short to leave the gaps chalk leaves.
    const strands = 6;
    final strandH = h / strands;
    for (var i = 0; i < strands; i++) {
      final start = rnd.nextDouble() * 5;
      final end = size.width - rnd.nextDouble() * 7;
      final alpha = 0.65 + rnd.nextDouble() * 0.35;
      final paint = Paint()..color = color.withValues(alpha: alpha);
      final top = i * strandH;
      var x = start;
      while (x < end) {
        final run = 6 + rnd.nextDouble() * 22;
        final stop = min(x + run, end);
        canvas.drawRect(
          Rect.fromLTRB(x, top, stop, top + strandH + 0.3),
          paint,
        );
        x = stop + (rnd.nextDouble() < 0.35 ? 1 + rnd.nextDouble() * 2 : 0);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SwipePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.seed != seed ||
      old.underlay != underlay;
}

/// FNV-1a, so a swipe looks the same on every launch and device.
int _stableHash(String s) {
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  return h;
}
