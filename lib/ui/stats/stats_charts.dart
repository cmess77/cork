import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../domain/scales.dart';
import '../../domain/stats.dart';
import '../../domain/tasting.dart';
import '../format.dart';
import '../theme/cork_theme.dart';

final _tickMonth = DateFormat("MMM ''yy");
final _spokenMonth = DateFormat('MMMM y');

/// Mean of a non-empty tally on the 0.1 score grid.
Score meanScore(Tally t) => Score.fromTenths((t.tenthsSum / t.count).round());

TextStyle? _tabular(TextStyle? s) =>
    s?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

double _rampDiameter(int value, int max) {
  const ramp = CorkTokens.scoreDotRamp;
  if (max <= 1) return ramp[ramp.length ~/ 2];
  final step = ((value - 1) / (max - 1) * (ramp.length - 1)).round();
  return ramp[step.clamp(0, ramp.length - 1)];
}

class TrendChart extends StatelessWidget {
  const TrendChart(this.months, {super.key});
  final List<MonthTally> months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spoken = [
      for (final m in months)
        '${_spokenMonth.format(m.month)}: average '
            '${meanScore(m.tally).format()} from '
            '${countLabel(m.tally.count, 'tasting')}',
    ].join('; ');
    return Semantics(
      container: true,
      label: 'Average over time. $spoken.',
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: CustomPaint(
          painter: _TrendPainter(
            months: months,
            line: theme.cork.score,
            axis: scheme.onSurfaceVariant,
            grid: scheme.outlineVariant,
            halo: scheme.surfaceContainerLow,
            label: _tabular(
              theme.textTheme.labelSmall,
            )!.copyWith(color: scheme.onSurfaceVariant),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.months,
    required this.line,
    required this.axis,
    required this.grid,
    required this.halo,
    required this.label,
    required this.textScaler,
  });

  final List<MonthTally> months;
  final Color line;
  final Color axis;
  final Color grid;
  final Color halo;
  final TextStyle label;
  final TextScaler textScaler;

  TextPainter _text(String s) => TextPainter(
    text: TextSpan(text: s, style: label),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    const maxDot = 22.0;
    final yLabels = [for (var v = 1; v <= 5; v++) _text('$v')];
    final xLabelHeight = _text('0').height;
    final left = yLabels.map((t) => t.width).reduce(max) + CorkSpace.sm;
    final right = size.width - maxDot / 2;
    const top = maxDot / 2;
    final bottom = size.height - xLabelHeight - CorkSpace.sm;
    double yOf(double score) => bottom - (score - 1) / 4 * (bottom - top);

    final axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var v = 1; v <= 5; v++) {
      final y = yOf(v.toDouble());
      canvas.drawLine(
        Offset(left, y),
        Offset(right + maxDot / 2, y),
        v == 1 ? axisPaint : gridPaint,
      );
      final t = yLabels[v - 1];
      t.paint(canvas, Offset(left - CorkSpace.sm - t.width, y - t.height / 2));
    }
    canvas.drawLine(Offset(left, top), Offset(left, bottom), axisPaint);

    int ordinal(DateTime m) => m.year * 12 + m.month;
    final first = ordinal(months.first.month);
    final span = max(1, ordinal(months.last.month) - first);
    final plotLeft = left + maxDot / 2;
    double xOf(DateTime m) =>
        plotLeft + (ordinal(m) - first) / span * (right - plotLeft);

    final points = [
      for (final m in months)
        Offset(xOf(m.month), yOf(m.tally.tenthsSum / m.tally.count / 10)),
    ];
    canvas.drawPath(
      Path()..addPolygon(points, false),
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final most = months.map((m) => m.tally.count).reduce(max);
    for (final (i, m) in months.indexed) {
      final r = _rampDiameter(m.tally.count, most) / 2;
      canvas.drawCircle(points[i], r + 1.5, Paint()..color = halo);
      canvas.drawCircle(points[i], r, Paint()..color = line);
    }

    final ticks = min(months.length, 4);
    var lastEnd = double.negativeInfinity;
    for (var k = 0; k < ticks; k++) {
      final m = months[(k * (months.length - 1) / max(1, ticks - 1)).round()];
      final t = _text(_tickMonth.format(m.month));
      final x = (xOf(m.month) - t.width / 2).clamp(left, size.width - t.width);
      if (x < lastEnd + CorkSpace.sm) continue;
      t.paint(canvas, Offset(x, bottom + CorkSpace.sm));
      lastEnd = x + t.width;
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      !identical(old.months, months) ||
      old.line != line ||
      old.axis != axis ||
      old.grid != grid ||
      old.halo != halo ||
      old.label != label ||
      old.textScaler != textScaler;
}

String _binLabel(ScoreBin b) => Score.fromTenths(b.fromTenths).format();

String _binRange(ScoreBin b) => b.fromTenths >= Score.max.tenths
    ? _binLabel(b)
    : '${_binLabel(b)} to ${Score.fromTenths(b.fromTenths + 4).format()}';

class ScoreDotPlot extends StatelessWidget {
  const ScoreDotPlot(this.bins, {super.key});
  final List<ScoreBin> bins;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final most = bins.map((b) => b.count).fold(0, max);
    const maxDot = 22.0;
    return Semantics(
      container: true,
      label:
          'Score distribution. '
          '${[for (final b in bins) '${_binRange(b)}: ${b.count}'].join('; ')}.',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (final b in bins)
              Expanded(
                child: Column(
                  children: [
                    SizedBox.square(
                      dimension: maxDot,
                      child: Center(
                        child: b.count == 0
                            ? null
                            : Container(
                                width: _rampDiameter(b.count, most),
                                height: _rampDiameter(b.count, most),
                                decoration: BoxDecoration(
                                  color: theme.cork.score,
                                  shape: BoxShape.circle,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: CorkSpace.sm),
                    Text(
                      '${b.count}',
                      style: _tabular(text.labelMedium),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      _binLabel(b),
                      style: _tabular(
                        text.labelSmall,
                      )?.copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SweetnessBars extends StatelessWidget {
  const SweetnessBars(this.counts, {super.key});
  final Map<Sweetness, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final most = counts.values.fold(0, max);
    return Semantics(
      container: true,
      label:
          'Sweetness. '
          '${[for (final s in Sweetness.values) '${s.label}: ${counts[s] ?? 0}'].join('; ')}.',
      child: ExcludeSemantics(
        child: Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final s in Sweetness.values)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      right: CorkSpace.md,
                      top: CorkSpace.xs,
                      bottom: CorkSpace.xs,
                    ),
                    child: Text(s.label, style: text.bodyMedium),
                  ),
                  CountBar(
                    fraction: most == 0 ? 0 : (counts[s] ?? 0) / most,
                    color: theme.colorScheme.secondary,
                    height: CorkSpace.md,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: CorkSpace.md),
                    child: Text(
                      '${counts[s] ?? 0}',
                      style: _tabular(text.bodyMedium),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class CountBar extends StatelessWidget {
  const CountBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = CorkSpace.xs,
  });
  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FractionallySizedBox(
      widthFactor: fraction.clamp(0.0, 1.0),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
      ),
    ),
  );
}
