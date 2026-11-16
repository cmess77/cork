import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/badges.dart';
import '../../domain/journal.dart';
import '../format.dart';
import '../routes.dart';
import '../theme/cork_theme.dart';
import '../widgets/chalk.dart';
import '../widgets/tasting_row.dart';

/// One Material Symbol per rule id; an unknown rule gets the medal.
IconData badgeIcon(String ruleId) => switch (ruleId) {
  'first' => Icons.wine_bar_rounded,
  't10' => Icons.liquor_rounded,
  't50' => Icons.celebration_rounded,
  't100' => Icons.emoji_events_rounded,
  'g5' => Icons.eco_rounded,
  'g10' => Icons.favorite_rounded,
  'c3' => Icons.flight_takeoff_rounded,
  'c10' => Icons.public_rounded,
  'r10' => Icons.map_rounded,
  'types' => Icons.palette_rounded,
  _ => Icons.military_tech_rounded,
};

String _progressLabel(BadgeStatus s) => '${s.progress} of ${s.rule.target}';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(badgesProvider);
    final earned = [
      for (final s in statuses)
        if (s.earned) s,
    ];
    final locked = [
      for (final s in statuses)
        if (!s.earned) s,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: CorkSpace.xl),
        children: [
          if (earned.isNotEmpty) ...[
            const BoardHeading('Earned'),
            _BadgeGrid(earned),
          ],
          if (locked.isNotEmpty) ...[
            const BoardHeading('In progress'),
            _BadgeGrid(locked),
          ],
        ],
      ),
    );
  }
}

/// Two columns; each row is as tall as its taller card, so long rules and
/// large font scales never clip.
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid(this.statuses);
  final List<BadgeStatus> statuses;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
    child: Column(
      children: [
        for (var i = 0; i < statuses.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : CorkSpace.md),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _BadgeCard(statuses[i])),
                  const SizedBox(width: CorkSpace.md),
                  Expanded(
                    child: i + 1 < statuses.length
                        ? _BadgeCard(statuses[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard(this.status);
  final BadgeStatus status;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return MergeSemantics(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openSheet(context, status.rule.id),
          child: Padding(
            padding: const EdgeInsets.all(CorkSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgeMark(status),
                const SizedBox(height: CorkSpace.md),
                Text(status.rule.title, style: text.titleMedium),
                const SizedBox(height: CorkSpace.xs),
                Text(
                  status.rule.description,
                  style: text.bodySmall?.copyWith(color: muted),
                ),
                const Spacer(),
                const SizedBox(height: CorkSpace.md),
                _StatusLine(status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Earned Nov 3, 2026", or a progress bar over "7 of 10".
class _StatusLine extends StatelessWidget {
  const _StatusLine(this.status);
  final BadgeStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final earnedAt = status.earnedAt;
    if (earnedAt != null) {
      return Text('Earned ${fullDate(earnedAt)}', style: label);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: LinearProgressIndicator(
            value: status.progress / status.rule.target,
            color: theme.colorScheme.onSurfaceVariant,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
          ),
        ),
        const SizedBox(height: CorkSpace.xs),
        Text(_progressLabel(status), style: label),
      ],
    );
  }
}

/// A 48dp chalk ring with the rule's symbol: solid in chalk yellow once
/// earned, dashed and grey while locked.
class BadgeMark extends StatelessWidget {
  const BadgeMark(this.status, {super.key});
  final BadgeStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cork = theme.cork;
    final earned = status.earned;
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _RingPainter(
          color: earned ? cork.badgeEarned : cork.badgeLocked,
          dashed: !earned,
        ),
        child: SizedBox.square(
          dimension: 48,
          child: Icon(
            badgeIcon(status.rule.id),
            size: 24,
            color: earned
                ? cork.badgeEarned
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.color, required this.dashed});
  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke / 2,
    );
    if (!dashed) {
      canvas.drawOval(rect, paint);
      return;
    }
    const dashes = 16;
    const sweep = 2 * pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep - pi / 2, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.dashed != dashed;
}

void _openSheet(BuildContext context, String ruleId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 1,
      builder: (_, controller) => _BadgeSheet(
        ruleId: ruleId,
        controller: controller,
        onOpen: (entry) {
          Navigator.of(sheetContext).pop();
          openWine(context, entry.wine.id, expand: entry.tasting.id);
        },
      ),
    ),
  );
}

/// The badge, its rule, and the tastings that count toward it. Watches the
/// badges so an edit elsewhere re-derives what it shows.
class _BadgeSheet extends ConsumerWidget {
  const _BadgeSheet({
    required this.ruleId,
    required this.controller,
    required this.onOpen,
  });
  final String ruleId;
  final ScrollController controller;
  final void Function(Entry entry) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref
        .watch(badgesProvider)
        .firstWhere((s) => s.rule.id == ruleId);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final counted = status.counted;
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
            child: Row(
              children: [
                BadgeMark(status),
                const SizedBox(width: CorkSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.rule.title,
                        style: theme.textTheme.headlineSmall,
                      ),
                      Text(
                        status.rule.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CorkSpace.gutter,
              CorkSpace.lg,
              CorkSpace.gutter,
              0,
            ),
            child: _StatusLine(status),
          ),
        ),
        const SliverToBoxAdapter(child: BoardHeading('Tastings that count')),
        if (counted.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CorkSpace.gutter),
              child: Text(
                'No tastings count toward this yet.',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: counted.length,
            itemBuilder: (_, i) =>
                TastingRow(counted[i], onTap: () => onOpen(counted[i])),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: CorkSpace.xl)),
      ],
    );
  }
}
