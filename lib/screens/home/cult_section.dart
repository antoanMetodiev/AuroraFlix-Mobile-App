import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../widgets/effects.dart';
import '../../widgets/marquee.dart';
import '../../widgets/pressable.dart';
import '../../widgets/reveal.dart';
import '../../widgets/section_heading.dart';
import 'home_data.dart';

const _gap = 16.0;

/// The website's w-[150px] sm:w-[180px] lg:w-[215px].
double _cardWidthFor(double screenWidth) => screenWidth >= 1024 ? 215 : (screenWidth >= 640 ? 180 : 150);

/// "Cult Movies" / "Cult Shows" (website: TrendingSection): two endless
/// poster rows of hand-picked titles, sliding in opposite directions with
/// faded edges. Each rises in as it scrolls into view.
class CultSection extends ConsumerWidget {
  const CultSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    return Container(
      padding: const EdgeInsets.only(top: 56, bottom: 32),
      child: Column(
        children: [
          _CultBlock(heading: t('home.cultMovies'), items: cultMovies, reverse: false),
          const SizedBox(height: 56),
          _CultBlock(heading: t('home.cultShows'), items: cultSeries, reverse: true),
        ],
      ),
    );
  }
}

class _CultBlock extends StatelessWidget {
  const _CultBlock({required this.heading, required this.items, required this.reverse});

  final String heading;
  final List<MarqueeItem> items;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    // One loop = one copy of the row; the site scrolls a doubled row by
    // 50% in 80s, i.e. one copy per 80s.
    const period = Duration(seconds: 80);
    final cardWidth = _cardWidthFor(MediaQuery.sizeOf(context).width);
    // Poster (2:3) + gap + title line.
    final rowHeight = cardWidth * 3 / 2 + 8 + 24 + 16;

    return InViewOnce(
      builder: (context, inView) => Reveal(
        visible: inView,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(heading, padding: const EdgeInsets.symmetric(horizontal: 16)),
            SizedBox(
              height: rowHeight,
              child: EdgeFade(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Marquee(
                    itemCount: items.length,
                    itemExtent: cardWidth,
                    spacing: _gap,
                    period: period,
                    reverse: reverse,
                    itemBuilder: (context, index) => _CultCard(item: items[index], width: cardWidth),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CultCard extends StatelessWidget {
  const _CultCard({required this.item, required this.width});

  final MarqueeItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => openTitle(context, item.type, item.tmdbId),
      child: Column(
        children: [
          Container(
            width: width,
            height: width * 3 / 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 22)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(item.image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.35, color: AppColors.fg(0.85)),
          ),
        ],
      ),
    );
  }
}
