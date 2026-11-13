import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/locale.dart';
import '../../core/library/localized_titles.dart';
import '../../core/library/watch_progress.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/pressable.dart';

const _maxItems = 20;
const _cardWidth = 300.0;

/// "Continue watching" (website: ContinueWatchingSection): a sideways row of
/// paused-looking mini players, each at the spot it was left. Tapping one
/// opens that title at its player. Renders nothing with nothing started.
class ContinueWatchingSection extends ConsumerWidget {
  const ContinueWatchingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final entries = continueWatching(ref.watch(watchProgressProvider)).take(_maxItems).toList();
    final titles = LocalizedTitles.watch(ref, entries.map((entry) => (isSeries: entry.isSeries, tmdbId: entry.tmdbId)));

    final cards = <_ContinueCard>[];
    for (final entry in entries) {
      final current = titles.lookup(isSeries: entry.isSeries, tmdbId: entry.tmdbId);
      final title = current?.title ?? entry.progress.title;
      // No saved name and the catalog hasn't answered (yet): nothing to show.
      if (title == null || title.isEmpty) continue;
      cards.add(_ContinueCard(entry: entry, title: title, image: entry.progress.image ?? tmdbImage(current?.posterImgURL, TmdbSize.w780)));
    }
    if (cards.isEmpty) return const SizedBox.shrink();

    return ColoredBox(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 20),
              child: Text(t('continue.title'), style: display(const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, letterSpacing: -0.3))),
            ),
            SizedBox(
              height: _cardWidth * 9 / 16 + 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: cards.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) => cards[index],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.entry, required this.title, required this.image});

  final TitleProgress entry;
  final String title;
  final String? image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final progress = entry.progress;
    final percent = progress.percent;
    final stoppedAt = formatPlaybackTime(progress.seconds);
    final duration = progress.duration;

    final String status;
    if (duration != null) {
      final left = (duration - progress.seconds).floor();
      final hours = left ~/ 3600;
      final minutes = (left % 3600) ~/ 60;
      status = t('continue.timeLeft', {
        'time': hours > 0 ? t('continue.hoursMinutes', {'hours': hours, 'minutes': minutes}) : t('continue.minutes', {'minutes': minutes < 1 ? 1 : minutes}),
      });
    } else {
      status = t(progress.approximate ? 'continue.stoppedAround' : 'continue.stoppedAt', {'time': stoppedAt});
    }

    return SizedBox(
      width: _cardWidth,
      child: Stack(
        children: [
          Pressable(
            pressedScale: 0.98,
            onTap: () => openTitle(context, entry.isSeries ? RecordType.series : RecordType.movie, entry.tmdbId, watch: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (image != null) AuroraImage(url: image),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              stops: [0, 0.5, 1],
                              colors: [Color(0xF2000000), Color(0x26000000), Color(0x4D000000)],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              entry.season != null
                                  ? t('carousel.episodeShort', {'season': entry.season!, 'episode': entry.episode ?? ''})
                                  : t('continue.movie'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.45),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 3),
                              child: Center(child: FaIcon(FontAwesomeIcons.play, size: 19, color: Colors.white)),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 9,
                          child: ExcludeSemantics(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Scrubber(percent: percent),
                                const SizedBox(height: 7),
                                Row(
                                  children: [
                                    FaIcon(FontAwesomeIcons.play, size: 11, color: Colors.white.withValues(alpha: 0.9)),
                                    const SizedBox(width: 10),
                                    Icon(LucideIcons.audioLines, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                                    const SizedBox(width: 10),
                                    Text.rich(
                                      TextSpan(
                                        text: '${progress.approximate ? '≈ ' : ''}$stoppedAt',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                                        children: [
                                          if (duration != null)
                                            TextSpan(
                                              text: ' / ${formatPlaybackTime(duration)}',
                                              style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                                            ),
                                        ],
                                      ),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()]),
                                    ),
                                    const Spacer(),
                                    CustomPaint(size: const Size(13, 13), painter: _FullscreenCorners(Colors.white.withValues(alpha: 0.9))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: AppColors.fg(0.6))),
              ],
            ),
          ),
          // Next to the card's own tap target, so it doesn't open the title.
          Positioned(
            top: 6,
            right: 6,
            child: Semantics(
              button: true,
              label: t('continue.remove'),
              child: Pressable(
                onTap: () => ref.read(watchProgressProvider.notifier).dismiss(isSeries: entry.isSeries, tmdbId: entry.tmdbId),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.65)),
                  child: Icon(LucideIcons.x, size: 16, color: Colors.white.withValues(alpha: 0.85)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.percent});

  final double? percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final filled = constraints.maxWidth * (percent ?? 0) / 100;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(999)),
              ),
              if (percent != null) ...[
                Container(
                  width: filled,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.sky, borderRadius: BorderRadius.circular(999)),
                ),
                Positioned(
                  left: (filled - 6).clamp(0, constraints.maxWidth - 12).toDouble(),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: AppColors.sky.withValues(alpha: 0.9), blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A fullscreen icon. Drawn, because a Shorebird patch can't add a glyph to
/// the release's tree-shaken icon font.
class _FullscreenCorners extends CustomPainter {
  const _FullscreenCorners(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final arm = size.width * 0.32;
    final w = size.width;
    final h = size.height;
    for (final corner in [
      [Offset(0, arm), Offset.zero, Offset(arm, 0)],
      [Offset(w - arm, 0), Offset(w, 0), Offset(w, arm)],
      [Offset(0, h - arm), Offset(0, h), Offset(arm, h)],
      [Offset(w - arm, h), Offset(w, h), Offset(w, h - arm)],
    ]) {
      canvas.drawPoints(PointMode.polygon, corner, paint);
    }
  }

  @override
  bool shouldRepaint(_FullscreenCorners oldDelegate) => oldDelegate.color != color;
}
