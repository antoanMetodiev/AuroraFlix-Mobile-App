import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/dates.dart';
import '../../core/i18n/locale.dart';
import '../../core/payments/payments.dart';
import '../../core/theme.dart';
import '../../shell/app_shell.dart';
import '../../widgets/footer.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';
import '../home/home_scroll.dart';

/// "Subscription" (website: SubscriptionView): the current plan, when it
/// renews or ends, and "Manage subscription" (Stripe's billing portal) — or
/// the way to Pro from Free.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _openingPortal = false;
  bool _portalError = false;

  Future<void> _openPortal() async {
    setState(() {
      _portalError = false;
      _openingPortal = true;
    });
    final ok = await ref.read(paymentsApiProvider).openPortal();
    if (!mounted) return;
    setState(() {
      _openingPortal = false;
      _portalError = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final auth = ref.watch(authProvider);
    final subscription = ref.watch(subscriptionProvider);
    final padding = shellContentPadding(context);
    final minHeight = MediaQuery.sizeOf(context).height - padding.top - padding.bottom;

    if (!auth.isLoaded || (auth.isSignedIn && subscription.isLoading)) {
      return Padding(padding: padding, child: const Loader());
    }

    if (!auth.isSignedIn) {
      return ListView(
        padding: padding,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t('subscription.signInTitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('subscription.signInDesc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.fg(0.6)),
                  ),
                ],
              ),
            ),
          ),
          const SiteFooter(),
        ],
      );
    }

    final info = subscription.value;
    final isPro = info?.isPro ?? false;
    final locale = intlLocale(ref.watch(localeProvider).name);
    final periodEnd = info?.currentPeriodEnd == null ? null : DateFormat.yMMMMd(locale).format(info!.currentPeriodEnd!);

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: AppColors.surface,
      edgeOffset: padding.top,
      onRefresh: () => ref.refresh(subscriptionProvider.future),
      child: ListView(
        padding: padding,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('subscription.title'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
                  const SizedBox(height: 8),
                  Text(t('subscription.subtitle'), style: TextStyle(fontSize: 14, color: AppColors.fg(0.5))),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.fg(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.fg(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t('subscription.currentPlan').toUpperCase(),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2.4, color: AppColors.fg(0.4)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isPro ? t('pricing.proName') : t('pricing.freeName'),
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            if (isPro)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (info!.cancelAtPeriodEnd ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  info.cancelAtPeriodEnd ? t('subscription.statusCanceling') : t('subscription.statusActive'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: info.cancelAtPeriodEnd ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (isPro && periodEnd != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            info!.cancelAtPeriodEnd
                                ? t('subscription.endsOn', {'date': periodEnd})
                                : t('subscription.renewsOn', {'date': periodEnd}),
                            style: TextStyle(fontSize: 14, color: AppColors.fg(0.6)),
                          ),
                        ],
                        if (!isPro) ...[
                          const SizedBox(height: 16),
                          Text(t('subscription.freeDesc'), style: TextStyle(fontSize: 14, color: AppColors.fg(0.6))),
                        ],
                        const SizedBox(height: 24),
                        Pressable(
                          onTap: isPro
                              ? (_openingPortal ? null : _openPortal)
                              : () {
                                  // Website: a link to /#pricing.
                                  context.go('/');
                                  ref.read(homeScrollRequestProvider.notifier).request(HomeAnchor.pricing);
                                },
                          child: Opacity(
                            opacity: _openingPortal ? 0.7 : 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isPro) ...[
                                    const Icon(LucideIcons.creditCard, size: 16, color: AppColors.onWhite),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    isPro ? (_openingPortal ? t('pricing.redirecting') : t('subscription.manage')) : t('pricing.proCta'),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onWhite),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_portalError) ...[
                          const SizedBox(height: 12),
                          Text(t('subscription.portalError'), style: const TextStyle(fontSize: 12, color: Color(0xFFF87171))),
                        ],
                      ],
                    ),
                  ),
                  if (isPro) ...[
                    const SizedBox(height: 24),
                    Text(t('subscription.manageHint'), style: TextStyle(fontSize: 12, color: AppColors.fg(0.4))),
                  ],
                ],
              ),
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }
}
