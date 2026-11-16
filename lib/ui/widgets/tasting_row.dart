import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/ids.dart';
import '../../domain/journal.dart';
import '../../domain/tasting.dart';
import '../format.dart';
import '../theme/cork_theme.dart';
import 'chalk.dart';

/// The label photo, or the glass swatch when there is none (or it is gone).
class TastingThumb extends ConsumerWidget {
  const TastingThumb(this.tasting, {super.key, this.size = 56});
  final Tasting tasting;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final swatch = SizedBox.square(
      dimension: size,
      child: Center(child: GlassSwatch(tasting.color, size: size * 6 / 7)),
    );
    final photo = tasting.photo;
    if (photo == null) return swatch;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: CorkRadius.card,
      child: Image.file(
        ref.watch(photoStoreProvider).fileFor(photo),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * dpr).round(),
        errorBuilder: (_, _, _) => swatch,
        semanticLabel: 'Label photo',
      ),
    );
  }
}

/// A feed row: thumb, wine name over its chalk swipe, winery and vintage,
/// when and where, and the score tight to the right gutter.
class TastingRow extends ConsumerWidget {
  const TastingRow(
    this.entry, {
    super.key,
    this.onTap,
    this.onLongPress,
    this.datedTitle = false,
  });

  final Entry entry;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Wine detail rows lead with the date and vintage instead of the name.
  final bool datedTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:tasting, :wine) = entry;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final TastingId? lastSaved = ref.watch(lastSavedProvider);
    final title = datedTitle
        ? [
            fullDate(tasting.tastedAt),
            tasting.vintage?.format(),
          ].whereType<String>().join(' · ')
        : wine.name;
    final line2 = datedTitle
        ? (tasting.place ?? timeLabel(tasting.tastedAt))
        : wineryAndVintage(wine, tasting.vintage);
    final line3 = datedTitle ? null : whenAndWhere(tasting);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 88),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CorkSpace.gutter,
            vertical: CorkSpace.md,
          ),
          child: Row(
            children: [
              TastingThumb(tasting),
              const SizedBox(width: CorkSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    ChalkSwipe(
                      color: tasting.color,
                      seed: tasting.id.value,
                      drawIn: lastSaved == tasting.id,
                    ),
                    const SizedBox(height: CorkSpace.xs),
                    if (line2.isNotEmpty)
                      Text(
                        line2,
                        style: text.bodyMedium?.copyWith(color: muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (line3 != null)
                      Text(
                        line3,
                        style: text.bodySmall?.copyWith(color: muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: CorkSpace.md),
              ScoreText(tasting.score),
            ],
          ),
        ),
      ),
    );
  }
}
