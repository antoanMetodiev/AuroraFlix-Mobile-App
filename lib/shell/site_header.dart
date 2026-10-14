import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/auth/auth_controller.dart';
import '../core/friends/friends_store.dart';
import '../core/i18n/locale.dart';
import '../core/theme.dart';
import '../screens/friends/notifications_panel.dart';
import '../widgets/glass.dart';
import '../widgets/language_toggle.dart';
import '../widgets/pressable.dart';

const double headerBarHeight = 64;

/// The fixed top bar — the website's SiteHeader on a phone: logo on the
/// left; search, (signed in) friends and notifications, language and the
/// menu button on the right, over a frosted strip with a hairline bottom
/// border.
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
  });

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

    return Glass(
      color: AppColors.background.withValues(alpha: 0.4),
      border: Border(bottom: BorderSide(color: AppColors.fg(0.1))),
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: SizedBox(
          height: headerBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Pressable(
                  onTap: onLogoTap,
                  semanticLabel: 'AuroraFlix',
                  child: Image.asset('assets/images/logo.webp', width: 40, height: 40, fit: BoxFit.contain),
                ),
                const Spacer(),
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
                const LanguageToggle(),
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
