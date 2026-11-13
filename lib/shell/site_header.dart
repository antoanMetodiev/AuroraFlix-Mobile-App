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
/// a floating, fully rounded island of dark "cinematic" glass — as wide as
/// its content, centred — with a light sheen across its top half, a thin
/// glow line along its bottom edge, a deep shadow and a soft white glow; all
/// a little stronger once the screen is scrolled. The logo, then search,
/// (signed in) friends and notifications, and the menu button.
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
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              // A deep shadow under the glass…
              BoxShadow(
                color: Colors.black.withValues(alpha: scrolled ? 0.95 : 0.9),
                blurRadius: scrolled ? 60 : 50,
                spreadRadius: -18,
                offset: Offset(0, scrolled ? 22 : 18),
              ),
              // …and a soft white glow around it.
              BoxShadow(
                color: Colors.white.withValues(alpha: scrolled ? 0.26 : 0.18),
                blurRadius: scrolled ? 28 : 22,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Glass(
            // Black at 35% → 60% once scrolled, white/15 → white/20 border (the site's bg-black/35).
            color: Colors.black.withValues(alpha: scrolled ? 0.6 : 0.35),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: scrolled ? 0.2 : 0.15)),
            child: SizedBox(
              height: _islandHeight,
              child: Stack(
                children: [
                  // Light catching the glass from above, and the glow line
                  // along the bottom edge — brighter once scrolled. Decorative.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Column(
                        children: [
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.white.withValues(alpha: 0.09), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 40,
                    right: 40,
                    bottom: 0,
                    height: 1,
                    child: IgnorePointer(
                      child: AnimatedOpacity(duration: const Duration(milliseconds: 500), opacity: scrolled ? 1 : 0.6, child: const _GlowLine()),
                    ),
                  ),
                  Padding(
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
                          active: searchOpen,
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
                          active: menuOpen,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 1px line that glows white in the middle and fades out to both ends —
/// the header island's bottom edge and the tab bar's top edge.
class _GlowLine extends StatelessWidget {
  const _GlowLine();

  @override
  Widget build(BuildContext context) => auroraGlowLine();
}

/// See [_GlowLine]; shared with the tab bar.
Widget auroraGlowLine() => DecoratedBox(
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0)]),
  ),
);

/// 40px round icon button — the header's search / friends / bell / menu
/// triggers: faint glass at rest, a white pill with a dark icon (and a soft
/// white glow) while its panel is open — the site's NAV_ICON_BUTTON. The
/// icon cross-fades when it changes (☰ ↔ ✕); a white count bubble, ringed in
/// black so it reads on the white pill too, sits on the corner when non-zero.
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
    this.active = false,
  });

  /// Its panel is open — drawn as the white pill.
  final bool active;

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
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: active ? Colors.transparent : Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: active ? 0.55 : 0),
                  blurRadius: 20,
                  spreadRadius: -6,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween(begin: 0.85, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(icon, key: ValueKey(icon), size: iconSize, color: active ? AppColors.onWhite : (iconColor ?? AppColors.fg(0.75))),
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black, width: 2, strokeAlign: BorderSide.strokeAlignOutside),
                ),
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
