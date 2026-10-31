import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/effects.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/marquee.dart';
import '../../widgets/pressable.dart';
import '../../widgets/reveal.dart';
import 'home_data.dart';

const _sky300 = Color(0xFF7DD3FC);
const _sky500 = Color(0xFF0EA5E9);

/// Seconds per loop, slightly different per column so they drift against
/// each other instead of moving in lockstep.
const _columnPeriods = [46, 54, 50];

/// "Trending Movies" / "Trending Series" (website: TrendingShowcase, phone
/// layout): eyebrow, heading, the scrollable ranked list, then two endless
/// poster columns sliding in opposite directions.
class TrendingShowcase extends ConsumerWidget {
  const TrendingShowcase({super.key, required this.movies, required this.series});

  final List<CinemaRecord> movies;
  final List<CinemaRecord> series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    return Column(
      children: [
        _ShowcaseBlock(heading: t('home.trendingMovies'), text: t('home.trendingMoviesText'), items: rankTrending(movies), flipped: false),
        _ShowcaseBlock(heading: t('home.trendingShows'), text: t('home.trendingShowsText'), items: rankTrending(series), flipped: true),
      ],
    );
  }
}

class _ShowcaseBlock extends ConsumerWidget {
  const _ShowcaseBlock({required this.heading, required this.text, required this.items, required this.flipped});

  final String heading;
  final String text;
  final List<RankedItem> items;
  final bool flipped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    return InViewOnce(
      threshold: 0.15,
      builder: (context, inView) => Reveal(
        visible: inView,
        child: ClipRect(
          child: Stack(
            children: [
              // Soft sky glow behind the columns, on whichever side they sit.
              Positioned(
                top: 0,
                bottom: 0,
                left: flipped ? -120 : null,
                right: flipped ? null : -120,
                child: Center(
                  child: IgnorePointer(
                    child: Container(
                      width: 480,
                      height: 480,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: _sky500.withValues(alpha: 0.1), blurRadius: 64, spreadRadius: 60)],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.sky.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.sky.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.flame, size: 14, color: _sky300),
                          const SizedBox(width: 8),
                          Text(
                            t('home.trendingEyebrow'),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _sky300),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      heading,
                      style: display(const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.6, color: Colors.white)),
                    ),
                    const SizedBox(height: 12),
                    Text(text, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
                    const SizedBox(height: 32),
                    _RankedList(items: items),
                    const SizedBox(height: 40),
                    // The same titles as the list above — a remote skips them.
                    SizedBox(height: 460, child: ExcludeFocus(child: _PosterColumns(items: items))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every title in a box about five rows tall that scrolls; while there's
/// more below, its bottom edge fades out as the hint that it scrolls.
class _RankedList extends StatefulWidget {
  const _RankedList({required this.items});

  final List<RankedItem> items;

  @override
  State<_RankedList> createState() => _RankedListState();
}

class _RankedListState extends State<_RankedList> {
  bool _atEnd = false;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 332),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          _updateAtEnd(notification.metrics);
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _updateAtEnd(notification.metrics);
            return false;
          },
          child: EdgeFade(
            axis: Axis.vertical,
            fadeStart: false,
            fadeEnd: !_atEnd,
            end: 0.78,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: widget.items.length,
              itemBuilder: (context, index) => _RankedRow(item: widget.items[index]),
            ),
          ),
        ),
      ),
    );
  }

  void _updateAtEnd(ScrollMetrics metrics) {
    final atEnd = metrics.pixels >= metrics.maxScrollExtent - 4;
    if (atEnd != _atEnd) setState(() => _atEnd = atEnd);
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({required this.item});

  final RankedItem item;

  @override
  Widget build(BuildContext context) {
    final record = item.record;
    final rating = record.rating;

    return Pressable(
      onTap: () => openRecord(context, record),
      pressedScale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${item.rank}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.25),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  if (record.year != null) Text(record.year!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45))),
                ],
              ),
            ),
            if (rating != null && rating > 0) ...[
              const FaIcon(FontAwesomeIcons.solidStar, size: 11, color: AppColors.amber),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
            ],
          ],
        ),
      ),
    );
  }
}

/// Splits the titles round-robin into [count] columns, then repeats each
/// until it holds at least [minPerColumn], so even a short list fills the
/// column's height before it loops (website: toColumns).
List<List<RankedItem>> _toColumns(List<RankedItem> items, int count, int minPerColumn) {
  final columns = List.generate(count, (_) => <RankedItem>[]);
  for (var i = 0; i < items.length; i++) {
    columns[i % count].add(items[i]);
  }
  return [
    for (final column in columns.where((column) => column.isNotEmpty))
      [for (var i = 0; i < column.length * ((minPerColumn + column.length - 1) ~/ column.length); i++) column[i % column.length]],
  ];
}

/// Two endless poster columns — up, down — faded at the top and bottom.
class _PosterColumns extends StatelessWidget {
  const _PosterColumns({required this.items});

  final List<RankedItem> items;

  @override
  Widget build(BuildContext context) {
    final columns = _toColumns(items, 2, 4);
    const gap = 12.0;

    return EdgeFade(
      axis: Axis.vertical,
      start: 0.12,
      end: 0.88,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = (constraints.maxWidth - gap * (columns.length - 1)) / columns.length;
          final cardHeight = columnWidth * 3 / 2;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns.length; c++) ...[
                if (c > 0) const SizedBox(width: gap),
                SizedBox(
                  width: columnWidth,
                  child: Marquee(
                    axis: Axis.vertical,
                    reverse: c.isOdd,
                    itemCount: columns[c].length,
                    itemExtent: cardHeight,
                    spacing: gap,
                    period: Duration(seconds: _columnPeriods[c % _columnPeriods.length]),
                    itemBuilder: (context, index) => _PosterCard(item: columns[c][index]),
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

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.item});

  final RankedItem item;

  @override
  Widget build(BuildContext context) {
    final record = item.record;
    final rating = record.rating;

    return Pressable(
      onTap: () => openRecord(context, record),
      pressedScale: 0.97,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.9), blurRadius: 40, spreadRadius: -18, offset: const Offset(0, 18))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AuroraImage(url: tmdbImage(record.posterImgURL, TmdbSize.w342)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black, Color(0xB3000000), Colors.transparent],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#${item.rank}${record.year != null ? ' · ${record.year}' : ''}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.8, color: AppColors.sky),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        record.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      if (rating != null && rating > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const FaIcon(FontAwesomeIcons.solidStar, size: 10, color: AppColors.amber),
                            const SizedBox(width: 4),
                            Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
