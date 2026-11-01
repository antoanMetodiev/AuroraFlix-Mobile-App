import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../shell/app_shell.dart';
import '../../widgets/footer.dart';
import '../../widgets/reveal.dart';
import 'cult_section.dart';
import 'hero_section.dart';
import 'home_data.dart';
import 'home_scroll.dart';
import 'last_viewed_section.dart';
// PAYMENTS DISABLED: import 'pricing_section.dart';
import 'trending_showcase.dart';

/// The home screen — the website's app/page.tsx, section for section and in
/// the same order: hero, pricing, last viewed, trending showcase, cult rows,
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

    return ColoredBox(
      color: Colors.black,
      child: RefreshIndicator(
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
            // PAYMENTS DISABLED — nobody is charged for now (same on the website).
            // PricingSection(key: _pricingKey),
            const RevealOnScroll(child: LastViewedSection()),
            if (trending != null) TrendingShowcase(movies: trending.movies, series: trending.series),
            const CultSection(),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }
}
