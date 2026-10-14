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

/// The floating bottom navigation from the website's MobileTabBar: a
/// frosted, rounded pill inset from the screen edges; the active tab's icon
/// sits in a glowing white chip.
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
      child: Glass(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 45, spreadRadius: -8, offset: const Offset(0, 20))],
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: SizedBox(
          height: _barHeight - 12,
          child: Row(
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
        ),
      ),
    );
  }
}

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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            height: 30,
            width: 36,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: active ? 0.6 : 0),
                  blurRadius: 14,
                  spreadRadius: -3,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TweenAnimationBuilder<Color?>(
              duration: duration,
              tween: ColorTween(end: active ? AppColors.onWhite : AppColors.fg(0.5)),
              builder: (context, color, _) => Icon(tab.icon, size: 17, color: color),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: duration,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? AppColors.foreground : AppColors.fg(0.45)),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
