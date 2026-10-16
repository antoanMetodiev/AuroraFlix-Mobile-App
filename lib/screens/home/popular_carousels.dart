import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/pressable.dart';
import '../../widgets/rating_ring.dart';
import '../../widgets/reveal.dart';
import '../../widgets/section_heading.dart';

const _autoplay = Duration(seconds: 5);
const _visibleSideCards = 3;
const _cardWidth = 170.0;
const _stageHeight = 300.0;

/// "Popular Movies" / "Popular Shows" — both 3D coverflows.
class PopularCarousels extends ConsumerWidget {
  const PopularCarousels({super.key, required this.movies, required this.series});

  final List<CinemaRecord> movies;
  final List<CinemaRecord> series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    return Column(
      children: [
        _Coverflow(heading: t('home.popularMovies'), items: movies),
        _Coverflow(heading: t('home.popularShows'), items: series),
      ],
    );
  }
}

/// 3D coverflow (website: PopularCarousels' Coverflow): the active title
/// large in the middle, neighbours fanned out to each side in perspective,
/// the active poster — blurred — glowing behind the stage. Auto-advances
/// every 5s while on screen (paused while touched); arrows, tapping a side
/// card and swiping move it; the centre card and "Watch now" open the title.
class _Coverflow extends ConsumerStatefulWidget {
  const _Coverflow({required this.heading, required this.items});

  final String heading;
  final List<CinemaRecord> items;

  @override
  ConsumerState<_Coverflow> createState() => _CoverflowState();
}

class _CoverflowState extends ConsumerState<_Coverflow> {
  int _active = 0;
  bool _inView = false;
  bool _paused = false;
  Timer? _timer;

  int get _count => widget.items.length;

  void _go(int delta) => setState(() => _active = (_active + delta + _count) % _count);

  void _restartTimer() {
    _timer?.cancel();
    if (!_inView || _paused || _count < 2) return;
    _timer = Timer.periodic(_autoplay, (_) => _go(1));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    final t = ref.watch(translatorProvider);
    final current = widget.items[_active];

    return InViewOnce(
      threshold: 0.25,
      builder: (context, inView) {
        if (inView && !_inView) {
          _inView = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _restartTimer());
        }
        return Reveal(
          visible: inView,
          child: Listener(
            onPointerDown: (_) {
              _paused = true;
              _restartTimer();
            },
            onPointerUp: (_) {
              _paused = false;
              _restartTimer();
            },
            child: ClipRect(
              child: Stack(
                children: [
                  // Ambient glow — the active poster, blurred, cross-fading.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 96,
                    bottom: 0,
                    child: IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 1000),
                        child: Opacity(
                          key: ValueKey(current.id),
                          opacity: 0.6,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32, tileMode: TileMode.decal),
                            child: Transform.scale(
                              scale: 1.1,
                              child: SizedBox.expand(child: AuroraImage(url: tmdbImage(current.posterImgURL, TmdbSize.w342))),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(radius: 0.9, colors: [Colors.transparent, AppColors.background], stops: [0.2, 0.75]),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 56, bottom: 24),
                    child: Column(
                      children: [
                        SectionHeading(widget.heading, padding: const EdgeInsets.symmetric(horizontal: 16)),
                        _Stage(
                          items: widget.items,
                          active: _active,
                          onSelect: (offset) => offset == 0 ? openRecord(context, current) : _go(offset),
                          onSwipe: _go,
                          previousLabel: t('carousel.scrollLeft'),
                          nextLabel: t('carousel.scrollRight'),
                        ),
                        const SizedBox(height: 24),
                        _ActiveInfo(key: ValueKey('info-${current.id}'), record: current, rank: _active + 1),
                        const SizedBox(height: 24),
                        _Dots(count: _count, active: _active, onSelect: (index) => setState(() => _active = index)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.items,
    required this.active,
    required this.onSelect,
    required this.onSwipe,
    required this.previousLabel,
    required this.nextLabel,
  });

  final List<CinemaRecord> items;
  final int active;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onSwipe;
  final String previousLabel;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final count = items.length;

    // Shortest way round, so the last card sits to the left of the first.
    int offsetOf(int index) {
      var offset = index - active;
      if (offset > count / 2) offset -= count;
      if (offset < -count / 2) offset += count;
      return offset;
    }

    // Paint far cards first so nearer ones overlap them.
    final order = List.generate(count, (index) => index)..sort((a, b) => offsetOf(b).abs().compareTo(offsetOf(a).abs()));

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > 40) onSwipe(velocity < 0 ? 1 : -1);
      },
      child: SizedBox(
        width: double.infinity,
        height: _stageHeight,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (final index in order)
              _CoverCard(key: ValueKey(items[index].id), record: items[index], offset: offsetOf(index), onTap: () => onSelect(offsetOf(index))),
            Positioned(
              left: 8,
              child: _ArrowButton(icon: LucideIcons.chevronLeft, label: previousLabel, onTap: () => onSwipe(-1)),
            ),
            Positioned(
              right: 8,
              child: _ArrowButton(icon: LucideIcons.chevronRight, label: nextLabel, onTap: () => onSwipe(1)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One poster on the stage, animating to its slot whenever the active card
/// changes: slid out by 62% of its width per step, pushed back 120px and
/// turned 32° per step, dimmed with distance, hidden past three steps.
class _CoverCard extends StatelessWidget {
  const _CoverCard({super.key, required this.record, required this.offset, required this.onTap});

  final CinemaRecord record;
  final int offset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = offset.abs();
    final hidden = distance > _visibleSideCards;
    final isActive = offset == 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: offset.toDouble()),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        final d = value.abs();
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 1 / 1400)
          // Flutter's z axis points away from the viewer (CSS's points toward
          // it), so the site's translateZ(-120px) / rotateY(-32deg) flip sign.
          ..translateByDouble(value * _cardWidth * 0.62, 0, d * 120, 1)
          ..rotateY(value * 32 * math.pi / 180);
        return Opacity(
          opacity: (hidden ? 0.0 : 1 - d * 0.18).clamp(0.0, 1.0),
          child: Transform(transform: matrix, alignment: Alignment.center, child: child),
        );
      },
      child: IgnorePointer(
        ignoring: hidden,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: _cardWidth,
            height: _cardWidth * 3 / 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: isActive ? 0.25 : 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isActive ? 0.95 : 0.9),
                  blurRadius: isActive ? 60 : 40,
                  spreadRadius: -15,
                  offset: Offset(0, isActive ? 30 : 20),
                ),
                if (isActive) BoxShadow(color: Colors.white.withValues(alpha: 0.25), blurRadius: 45, spreadRadius: -5),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AuroraImage(url: tmdbImage(record.posterImgURL, TmdbSize.w342)),
                  AnimatedOpacity(
                    opacity: isActive ? 0 : (0.15 + distance * 0.15).clamp(0, 0.6),
                    duration: const Duration(milliseconds: 500),
                    child: const ColoredBox(color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// "#1 · MOVIE · 2026", title, rating and Watch now — rises in on change.
class _ActiveInfo extends ConsumerWidget {
  const _ActiveInfo({super.key, required this.record, required this.rank});

  final CinemaRecord record;
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final type = record.isSeries ? t('watchlist.series') : t('watchlist.movie');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 8 * (1 - value)), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text(
              '#$rank · $type${record.year != null ? ' · ${record.year}' : ''}'.toUpperCase(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2.4, color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 8),
            Text(
              record.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: display(const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (record.rating != null) ...[RatingRing(value: record.rating!, size: RatingRingSize.sm), const SizedBox(width: 16)],
                Pressable(
                  onTap: () => openRecord(context, record),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: -4, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.play, size: 12, color: AppColors.onWhite),
                        const SizedBox(width: 6),
                        Text(
                          t('hero.watchNow'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onWhite),
                        ),
                      ],
                    ),
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

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active, required this.onSelect});

  final int count;
  final int active;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == active ? 24 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: i == active ? 1 : 0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
      ],
    );
  }
}
