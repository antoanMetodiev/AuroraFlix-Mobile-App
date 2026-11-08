import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/i18n/locale.dart';
import '../core/library/watchlist.dart';
import '../core/tmdb.dart';
import 'fade_in_image.dart';
import 'pressable.dart';
import 'rating_ring.dart';

/// A saved title's poster (website: LibraryPosterCard) in the filmography
/// cards' style: type badge, rating ring, title over a dark fade. When it
/// can be removed, the remove button takes the rating ring's place (the
/// site does the same on a phone, where there's no hover).
class LibraryPosterCard extends ConsumerWidget {
  const LibraryPosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onRemove,
    this.removeLabel = '',
    this.lazy = false,
    this.compact = false,
  });

  final LibraryItem item;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String removeLabel;

  /// Load the poster only once it's on screen (see AuroraImage.lazy).
  final bool lazy;

  /// Smaller type and badges — for the denser playlist grids.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final rating = double.tryParse(item.tmdbRating ?? '');
    final poster = tmdbImage(item.posterImgURL, compact ? TmdbSize.w342 : TmdbSize.w500);
    final isSeries = item.isSeries;

    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Pressable(
            onTap: onTap,
            pressedScale: 0.97,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (poster != null) AuroraImage(url: poster, lazy: lazy),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xE6000000), Color(0x1A000000), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isSeries ? LucideIcons.tv : LucideIcons.clapperboard, size: compact ? 10 : 11, color: Colors.white.withValues(alpha: 0.9)),
                          const SizedBox(width: 4),
                          Text(
                            (isSeries ? t('watchlist.series') : t('watchlist.movie')).toUpperCase(),
                            style: TextStyle(
                              fontSize: compact ? 9 : 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onRemove == null && rating != null && rating > 0)
                    Positioned(top: 8, right: 8, child: RatingRing(value: rating, size: RatingRingSize.xs)),
                  Positioned(
                    left: compact ? 10 : 12,
                    right: compact ? 10 : 12,
                    bottom: compact ? 10 : 12,
                    child: Text(
                      item.title ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12 : 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 8,
              right: 8,
              child: Pressable(
                onTap: onRemove,
                semanticLabel: removeLabel,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.7),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Icon(LucideIcons.trash2, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
