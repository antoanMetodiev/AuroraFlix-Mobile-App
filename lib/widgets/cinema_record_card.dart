import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/i18n/locale.dart';
import '../core/navigation.dart';
import '../core/theme.dart';
import '../core/tmdb.dart';
import '../models/models.dart';
import 'fade_in_image.dart';
import 'pressable.dart';
import 'rating_ring.dart';
import 'record_actions.dart';
import 'reveal.dart';

/// Poster tile from the catalog grids (website: CinemaRecordCard, touch
/// layout): poster with a dark vignette, rating badge top-right, watchlist
/// and like buttons top-left (always visible — no hover on a phone), and the
/// title with "Movie • 2026" along the bottom.
class CinemaRecordCard extends ConsumerWidget {
  const CinemaRecordCard({super.key, required this.record});

  final CinemaRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final rating = record.rating;

    return Stack(
      children: [
        Pressable(
          onTap: () => openRecord(context, record),
          pressedScale: 0.97,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AuroraImage(url: tmdbImage(record.posterImgURL, TmdbSize.w780)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xF2000000), Color(0x1A000000), Colors.transparent],
                        ),
                      ),
                    ),
                    if (rating != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '★ ',
                                  style: TextStyle(color: ratingColor(rating)),
                                ),
                                TextSpan(text: rating.toStringAsFixed(1)),
                              ],
                            ),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            record.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              shadows: [Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(0, 1))],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                record.isSeries ? LucideIcons.tv : LucideIcons.film,
                                size: 11,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  [record.isSeries ? t('watchlist.series') : t('watchlist.movie'), ?record.year].join('  •  '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.6)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Row(
            children: [
              WatchlistButton(record: record, variant: RecordActionVariant.overlay),
              const SizedBox(width: 6),
              LikeButton(record: record, variant: RecordActionVariant.overlay),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two-column catalog grid whose cards rise in one after another once it
/// scrolls into view (website: CinemaRecordGrid + `.animate-card-in`).
class CinemaRecordGrid extends ConsumerWidget {
  const CinemaRecordGrid({super.key, required this.records});

  final List<CinemaRecord> records;

  static const _maxStaggered = 24;
  static const _staggerStep = Duration(milliseconds: 45);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);

    if (records.isEmpty) {
      return SizedBox(
        height: 384,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('common.noResults'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text(
                t('common.noResultsDesc'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.fg(0.5)),
              ),
            ],
          ),
        ),
      );
    }

    return InViewOnce(
      threshold: 0.05,
      builder: (context, inView) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const columns = 2;
            const gapX = 12.0;
            final width = (constraints.maxWidth - gapX * (columns - 1)) / columns;
            return Wrap(
              spacing: gapX,
              runSpacing: 24,
              children: [
                for (var i = 0; i < records.length; i++)
                  SizedBox(
                    width: width,
                    child: _CardIn(
                      visible: inView,
                      delay: _staggerStep * (i < _maxStaggered ? i : _maxStaggered),
                      child: CinemaRecordCard(record: records[i]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// `.animate-card-in`: from 22px lower, 96% size and transparent, over 550ms.
class _CardIn extends StatefulWidget {
  const _CardIn({required this.visible, required this.delay, required this.child});

  final bool visible;
  final Duration delay;
  final Widget child;

  @override
  State<_CardIn> createState() => _CardInState();
}

class _CardInState extends State<_CardIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: auroraEase);

  @override
  void initState() {
    super.initState();
    if (widget.visible) _start();
  }

  @override
  void didUpdateWidget(_CardIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) _start();
  }

  void _start() => Future.delayed(widget.delay, () {
    if (mounted) _controller.forward();
  });

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - _curve.value)),
          child: Transform.scale(scale: 0.96 + 0.04 * _curve.value, child: child),
        ),
      ),
      child: widget.child,
    );
  }
}
