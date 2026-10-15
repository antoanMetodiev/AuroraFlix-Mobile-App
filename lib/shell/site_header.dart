import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/auth/auth_controller.dart';
import '../core/friends/friends_store.dart';
import '../core/i18n/locale.dart';
import '../core/theme.dart';
import '../screens/friends/notifications_panel.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';

/// Space the header reserves below the status bar — same 4rem the site's
/// body pt-16 keeps: an 8px gap above the island, the 48px island, and 8px
/// below it.
const double headerBarHeight = 64;
const double _islandHeight = 48;
const double _islandGap = 8;
const double _islandTopGap = 3;

/// The fixed top bar — the website's SiteHeader (HeaderIsland) on a phone:
/// a floating, fully rounded glass island — as wide as its content, centred —
/// with a hairline white border and a soft white glow; pale grey glass that
/// turns a little denser once the screen is scrolled. The logo, then search,
/// (signed in) friends and notifications, language and the menu button.
class SiteHeader extends ConsumerWidget {
  const SiteHeader({
    super.key,
    required this.searchOpen,
    required this.menuOpen,
    required this.onLogoTap,
    required this.onSearchTap,
    required this.onMenuTap,
    required this.onFriendsTap,
    required this.onBellTap,
    this.scrolled = false,
  });

  /// The current screen is scrolled past its very top.
  final bool scrolled;

  final bool searchOpen;
  final bool menuOpen;
  final VoidCallback onLogoTap;
  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;
  final VoidCallback onFriendsTap;
  final VoidCallback onBellTap;

  /// Space the header covers at the top of the screen.
  static double reservedHeight(BuildContext context) => headerBarHeight + MediaQuery.paddingOf(context).top;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final signedIn = ref.watch(authProvider.select((auth) => auth.isSignedIn));

    return Padding(
      // A little closer to the status bar than to the sides.
      padding: EdgeInsets.fromLTRB(_islandGap, MediaQuery.paddingOf(context).top + _islandTopGap, _islandGap, 0),
      // The island hugs its content and sits centred (as on the site), rather
      // than stretching edge to edge.
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            // No border — a stronger white glow outlines the island instead.
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: scrolled ? 0.55 : 0.45),
                blurRadius: scrolled ? 30 : 26,
                spreadRadius: -1,
              ),
            ],
          ),
          child: Glass(
            // Tailwind neutral-700 (#404040) at 30% → 45% once scrolled.
            color: const Color(0xFF404040).withValues(alpha: scrolled ? 0.45 : 0.3),
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: _islandHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Pressable(
                      onTap: onLogoTap,
                      semanticLabel: 'AuroraFlix',
                      child: Image.asset('assets/images/logo.webp', width: 36, height: 36, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 12),
                    HeaderIconButton(
                      icon: searchOpen ? LucideIcons.x : LucideIcons.search,
                      label: searchOpen ? t('nav.closeSearch') : t('nav.openSearch'),
                      onTap: onSearchTap,
                    ),
                    if (signedIn) ...[
                      const SizedBox(width: 8),
                      HeaderIconButton(
                        icon: LucideIcons.users,
                        label: t('friends.usersAria'),
                        onTap: onFriendsTap,
                        badge: ref.watch(friendsProvider.select((friends) => friends.incoming.length)),
                      ),
                      const SizedBox(width: 8),
                      HeaderIconButton(
                        icon: LucideIcons.bell,
                        label: t('friends.notificationsAria'),
                        onTap: onBellTap,
                        badge: ref.watch(notificationCountProvider),
                        badgePrefix: '+',
                      ),
                    ],
                    const SizedBox(width: 8),
                    HeaderIconButton(
                      icon: menuOpen ? LucideIcons.x : LucideIcons.menu,
                      label: menuOpen ? t('nav.closeMenu') : t('nav.openMenu'),
                      onTap: onMenuTap,
                      iconSize: 20,
                      iconColor: AppColors.foreground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 40px round icon button with a faint fill and border — the header's
/// search / friends / bell / menu triggers. The icon cross-fades when it
/// changes (☰ ↔ ✕); a white count bubble sits on the corner when non-zero.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconSize = 18,
    this.iconColor,
    this.badge = 0,
    this.badgePrefix = '',
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double iconSize;
  final Color? iconColor;
  final int badge;
  final String badgePrefix;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.fg(0.05),
              border: Border.all(color: AppColors.fg(0.1)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween(begin: 0.85, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(icon, key: ValueKey(icon), size: iconSize, color: iconColor ?? AppColors.fg(0.7)),
            ),
          ),
          if (badge > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                height: 16,
                constraints: const BoxConstraints(minWidth: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '$badgePrefix$badge',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, height: 1, color: AppColors.onWhite),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
