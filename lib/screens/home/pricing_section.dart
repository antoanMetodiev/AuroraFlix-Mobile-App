import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/current_user.dart';
import '../../core/i18n/locale.dart';
import '../../core/payments/payments.dart';
import '../../core/theme.dart';
import '../auth/clerk_auth_modal.dart';
import '../../widgets/effects.dart';
import '../../widgets/pressable.dart';
import '../../widgets/reveal.dart';
import '../../widgets/section_heading.dart';

class _Plan {
  const _Plan(this.id, this.features, {this.highlighted = false});

  final String id;
  final int features;
  final bool highlighted;

  String key(String suffix) => 'pricing.$id$suffix';
}

const _plans = [_Plan('free', 4), _Plan('pro', 6, highlighted: true)];

/// "Plans & Pricing" (website: PricingSection, phone layout): Free and Pro
/// cards stacked, Pro raised on the surface color with a glow and a
/// "Most Popular" pill. Rises in as it scrolls into view, cards staggered.
class PricingSection extends ConsumerWidget {
  const PricingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);

    return FilmGrain(
      child: Container(
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(16, 56, 16, 80),
        child: InViewOnce(
          builder: (context, inView) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Reveal(
                visible: inView,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeading(t('pricing.title')),
                    Transform.translate(
                      offset: const Offset(0, -16),
                      child: Text(t('pricing.subtitle'), style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.fg(0.6))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < _plans.length; i++) ...[
                if (i > 0) const SizedBox(height: 24),
                Reveal(
                  visible: inView,
                  delay: Duration(milliseconds: 110 * i),
                  child: _PlanCard(plan: _plans[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});

  final _Plan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final highlighted = plan.highlighted;
    final auth = ref.watch(authProvider);
    final isPro = ref.watch(currentUserProvider).value?.isPro ?? false;
    final checkout = ref.watch(checkoutProvider);
    final redirecting = checkout == CheckoutState.redirecting;

    // Website: Pro's button opens sign-up when signed out, starts Stripe
    // checkout (in the browser) when signed in, and goes inert once you are
    // Pro.
    final proInert = auth.isSignedIn && isPro;
    final ctaLabel = highlighted
        ? t(proInert ? 'pricing.proCtaCurrent' : (auth.isSignedIn && redirecting ? 'pricing.redirecting' : plan.key('Cta')))
        : t(isPro ? 'pricing.freeCtaIncludedInPro' : plan.key('Cta'));

    final card = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.surface : AppColors.fg(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlighted ? Colors.white.withValues(alpha: 0.4) : AppColors.fg(0.1)),
        boxShadow: highlighted ? [BoxShadow(color: Colors.white.withValues(alpha: 0.14), blurRadius: 50)] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t(plan.key('Name')), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(t(plan.key('Desc')), style: TextStyle(fontSize: 14, color: AppColors.fg(0.6))),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(t(plan.key('Price')), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Text(t(plan.key('Period')), style: TextStyle(fontSize: 14, color: AppColors.fg(0.5))),
            ],
          ),
          const SizedBox(height: 24),
          for (var i = 1; i <= plan.features; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == plan.features ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(LucideIcons.check, size: 16, color: highlighted ? Colors.white : AppColors.fg(0.4)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t(plan.key('Feature$i')), style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.fg(0.75))),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
          highlighted && !proInert
              ? Pressable(
                  onTap: !auth.isLoaded || redirecting
                      ? null
                      : auth.isSignedIn
                      ? () => ref.read(checkoutProvider.notifier).start()
                      : () => showClerkAuthModal(context, ClerkAuthMode.signUp),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Text(
                      ctaLabel,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.35, color: AppColors.onWhite),
                    ),
                  ),
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.fg(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.fg(0.15)),
                  ),
                  child: Text(
                    ctaLabel,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.35, color: AppColors.fg(0.35)),
                  ),
                ),
          if (highlighted && auth.isSignedIn && redirecting) ...[
            const SizedBox(height: 8),
            Text(t('pricing.pleaseWait'), style: TextStyle(fontSize: 12, color: AppColors.fg(0.5))),
          ],
          if (highlighted && checkout == CheckoutState.error) ...[
            const SizedBox(height: 8),
            Text(t('pricing.checkoutError'), style: const TextStyle(fontSize: 12, color: Color(0xFFF87171))),
          ],
        ],
      ),
    );

    if (!highlighted) return card;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Soft white glow rising off the top edge.
        Positioned(
          left: 24,
          right: 24,
          top: -40,
          height: 96,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 64)],
              ),
            ),
          ),
        ),
        card,
        Positioned(
          left: 24,
          top: -12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.sparkles, size: 12, color: AppColors.onWhite),
                const SizedBox(width: 4),
                Text(
                  t('pricing.mostPopular'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onWhite),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
