import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/dates.dart';
import '../core/i18n/locale.dart';
import '../core/navigation.dart';
import '../core/theme.dart';
import '../core/tmdb.dart';
import '../models/models.dart';
import 'fade_in_image.dart';
import 'pressable.dart';
import 'rating_ring.dart';
import 'reveal.dart';

/// Poster tile from the catalog grids (website: CinemaRecordCard, touch
/// layout): poster with a dark vignette, rating badge top-right, and along
/// the bottom the title, its tagline, "Movie • 9 October 2026" and up
/// to two genres.
class CinemaRecordCard extends ConsumerWidget {
  const CinemaRecordCard({super.key, required this.record, this.lazy = false});

  final CinemaRecord record;

  /// Load the poster only once it's on screen — for cards past the first rows.
  final bool lazy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final rating = record.rating;

    return Pressable(
      onTap: () => openRecord(context, record),
      pressedScale: 0.97,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            // A soft light glow (website: the card's shadow) — the lists are
            // plain black, where a dark shadow wouldn't show.
            boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.14), blurRadius: 32, spreadRadius: -8, offset: const Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AuroraImage(url: tmdbImage(record.posterImgURL, TmdbSize.w500), lazy: lazy),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      // Solid at the bottom edge, still dark a third of the way up, clear
                      // by two thirds — the text there reads on any poster (website: same).
                      colors: [Color(0xFF000000), Color(0xBF000000), Colors.transparent],
                      stops: [0, 0.35, 0.7],
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
                      if (record.specialText case final tagline? when tagline.isNotEmpty) ...[
                        Text(
                          tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: display(
                            TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withValues(alpha: 0.6),
                              shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 2, offset: Offset(0, 1))],
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        record.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: display(
                          const TextStyle(
                            fontSize: 15,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: [Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(0, 1))],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(record.isSeries ? LucideIcons.tv : LucideIcons.film, size: 11, color: Colors.white.withValues(alpha: 0.8)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              [
                                record.isSeries ? t('watchlist.series') : t('watchlist.movie'),
                                // The full date ("9 октомври 2026 г."), not just the year.
                                if (record.releaseDate != null) formatReleaseDate(record.releaseDate, ref.watch(localeProvider).name),
                              ].join('  •  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.6)),
                            ),
                          ),
                        ],
                      ),
                      if (record.genreList.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        // Up to two, kept to one line — a second that
                        // doesn't fit is clipped rather than wrapping.
                        SizedBox(
                          height: 18,
                          child: ClipRect(
                            child: Wrap(
                              spacing: 4,
                              clipBehavior: Clip.hardEdge,
                              children: [
                                for (final genre in record.genreList.take(2))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                    ),
                                    child: Text(
                                      t.genre(genre),
                                      maxLines: 1,
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.75)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
  static const _eagerPosters = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);

    if (records.isEmpty) {
      return EmptyResults(title: t('common.noResults'), message: t('common.noResultsDesc'));
    }

    return InViewOnce(
      threshold: 0.05,
      builder: (context, inView) => LayoutBuilder(
        builder: (context, outer) {
          // The website's grid-cols-2 sm:3 md:4 lg:5 xl:6, up to 100rem wide
          // — two columns on a phone, more on a tablet or a TV.
          final screen = outer.maxWidth;
          final columns = screen >= 1280
              ? 6
              : screen >= 1024
              ? 5
              : screen >= 768
              ? 4
              : screen >= 640
              ? 3
              : 2;
          final wide = screen >= 640;
          final gapX = wide ? 20.0 : 12.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16, vertical: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - gapX * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gapX,
                      runSpacing: wide ? 32 : 24,
                      children: [
                        for (var i = 0; i < records.length; i++)
                          SizedBox(
                            width: width,
                            child: _CardIn(
                              visible: inView,
                              delay: _staggerStep * (i < _maxStaggered ? i : _maxStaggered),
                              // The first two rows load right away, the rest as they scroll in.
                              child: CinemaRecordCard(record: records[i], lazy: i >= _eagerPosters),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The empty state of a results list, sized for a phone: an icon, a title
/// that wraps centred (the old one-line 30px heading overflowed into an
/// awkward left-aligned break), the message under it and an optional
/// [action] (a button) at the bottom.
class EmptyResults extends StatelessWidget {
  const EmptyResults({super.key, required this.title, this.message, this.icon = LucideIcons.search, this.action});

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 320),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.fg(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Icon(icon, size: 24, color: AppColors.fg(0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: display(const TextStyle(fontSize: 24, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: -0.4)),
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.fg(0.6)),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
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
