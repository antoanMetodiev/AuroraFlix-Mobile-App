import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../shell/app_shell.dart';
import '../../widgets/footer.dart';
import '../../widgets/reveal.dart';
import 'continue_watching_section.dart';
import 'cult_section.dart';
import 'home_backdrop.dart';
import 'hero_section.dart';
import 'home_data.dart';
import 'home_scroll.dart';
import 'last_viewed_section.dart';
// PAYMENTS DISABLED: import 'pricing_section.dart';
import 'trending_showcase.dart';
import 'seasonal.dart';
import '../recap/recap_screen.dart';

/// The home screen — the website's app/page.tsx, section for section and in
/// the same order: hero, pricing, continue watching, last viewed, trending showcase, cult rows,
/// footer.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  final _pricingKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls so the section sits just under the fixed header.
  void _scrollTo(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box == null || !_scroll.hasClients) return;
    final reveal = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;
    final target = (reveal - shellContentPadding(context).top).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 700), curve: auroraEase);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeScrollRequestProvider, (previous, next) {
      if (next?.anchor == HomeAnchor.pricing) {
        // After the tab switch has painted.
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_pricingKey));
      }
    });

    final hero = ref.watch(heroItemsProvider);
    final trending = ref.watch(trendingProvider).value;
    final padding = shellContentPadding(context);

    // Everything below the hero sits on the Watchlist's blurred-poster
    // background instead of flat black: a random trending title, a new one
    // every time this tab is opened (see HomeBackdrop).
    final posters = [
      for (final record in [...?trending?.movies, ...?trending?.series])
        if (record.posterImgURL != null) record.posterImgURL!,
    ];

    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        Positioned.fill(child: HomeBackdrop(posters: posters)),
        RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        edgeOffset: padding.top,
        onRefresh: () async {
          ref.invalidate(trendingProvider);
          await ref.read(heroItemsProvider.future);
        },
        child: ListView(
          controller: _scroll,
          // No top padding: the hero runs up under the floating header.
          padding: padding.copyWith(top: 0),
          children: [
            hero.when(
              data: (items) => HeroSection(items: items),
              // Same height as the real hero, so nothing below jumps when it lands.
              loading: () => SizedBox(height: math.max(MediaQuery.sizeOf(context).height * 0.85 - 64, 560) + padding.top),
              error: (_, _) => const HeroSection(items: []),
            ),
            // Melts the hero's black bottom edge into the blurred background
            // below it. Takes no space: it hangs below the hero, under the
            // sections that follow (they paint after it).
            SizedBox(
              height: 0,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: 160,
                child: IgnorePointer(
                  child: Container(
                    height: 160,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // PAYMENTS DISABLED — nobody is charged for now (same on the website).
            // PricingSection(key: _pricingKey),
            const RecapPill(),
            const RevealOnScroll(child: ContinueWatchingSection()),
            const RevealOnScroll(child: LastViewedSection()),
            if (trending != null) TrendingShowcase(movies: trending.movies, series: trending.series),
            // The season's themed row (seasonal.dart) — nothing outside a season.
            const SeasonalSection(),
            const CultSection(),
            const SiteFooter(),
          ],
        ),
      ),
        // Snow / embers / hearts over the home screen, in season.
        const Positioned.fill(child: SeasonalEffects()),
      ],
    );
  }
}
