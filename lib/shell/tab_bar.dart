import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/locale.dart';
import '../core/theme.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';
import 'nav_tabs.dart';

/// Height of the floating bar itself, without the bottom gap / safe area —
/// screens pad their scroll content by [AuroraTabBar.reservedHeight].
const double _barHeight = 60;
const double _gap = 12;

/// The floating bottom navigation from the website's MobileTabBar: the same
/// glass island as the header (pale grey glass, hairline white border, soft
/// white glow), inset from the screen edges. One white pill slides — with a
/// little overshoot — to the active tab's icon.
class AuroraTabBar extends ConsumerWidget {
  const AuroraTabBar({super.key, required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// Space the bar covers at the bottom of the screen.
  static double reservedHeight(BuildContext context) => _barHeight + _gap * 2 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(_gap, 0, _gap, _gap + bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.28), blurRadius: 20, spreadRadius: -2)],
        ),
        child: Glass(
          // Tailwind neutral-700 (#404040) at 45%, like the site.
          color: const Color(0xFF404040).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: SizedBox(
            height: _barHeight - 12,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = constraints.maxWidth / navTabs.length;
                final hasActive = currentIndex >= 0 && currentIndex < navTabs.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 500),
                      curve: _pillCurve,
                      left: tabWidth * (hasActive ? currentIndex : 0) + (tabWidth - _pillWidth) / 2,
                      top: _pillTop,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: hasActive ? 1 : 0,
                        child: Container(
                          width: _pillWidth,
                          height: _pillHeight,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.6),
                                blurRadius: 16,
                                spreadRadius: -3,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var index = 0; index < navTabs.length; index++)
                          Expanded(
                            child: _TabItem(
                              tab: navTabs[index],
                              label: t(navTabs[index].shortLabelKey ?? navTabs[index].labelKey),
                              active: index == currentIndex,
                              onTap: () => onSelect(index),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The site's cubic-bezier(0.34, 1.36, 0.64, 1) — eases in with a small overshoot.
const Curve _pillCurve = Cubic(0.34, 1.36, 0.64, 1);
const double _pillWidth = 44;
const double _pillHeight = 32;

/// The icon box's top inside a tab (the tab column is top-aligned).
const double _pillTop = 0;

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.label, required this.active, required this.onTap});

  final NavTab tab;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 300);

    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Column(
        // Top-aligned (not centred) so the icon box sits exactly at _pillTop.
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: _pillHeight,
            width: _pillWidth,
            child: TweenAnimationBuilder<Color?>(
              duration: duration,
              tween: ColorTween(end: active ? AppColors.onWhite : AppColors.fg(0.85)),
              builder: (context, color, _) => Icon(tab.icon, size: 17, color: color),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: duration,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.fg(0.8)),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
