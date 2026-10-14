import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/auth/auth_controller.dart';
// PAYMENTS DISABLED: import '../core/i18n/locale.dart';
import '../screens/auth/clerk_ui.dart';
import '../widgets/user_avatar.dart';

/// Clerk's UserButton popover as the website shows it: who's signed in,
/// then Manage account, Subscription (the site's own extra item) and Sign
/// out, with "Secured by clerk" underneath.
class UserMenu extends ConsumerWidget {
  const UserMenu({super.key, required this.onManageAccount, required this.onSubscription, required this.onSignOut});

  final VoidCallback onManageAccount;
  final VoidCallback onSubscription;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PAYMENTS DISABLED: only the Subscription item used it.
    // final t = ref.watch(translatorProvider);
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final divider = Container(height: 1, color: Colors.white.withValues(alpha: 0.08));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 16))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                UserAvatar(user: user, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user.fullName.isNotEmpty)
                        Text(
                          user.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      if (user.email != null)
                        Text(
                          user.email!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          divider,
          _Item(icon: LucideIcons.settings, label: 'Manage account', onTap: onManageAccount),
          divider,
          // PAYMENTS DISABLED — nobody is charged for now (same on the website).
          // _Item(icon: LucideIcons.creditCard, label: t('nav.subscription'), onTap: onSubscription),
          // divider,
          _Item(icon: LucideIcons.logOut, label: 'Sign out', onTap: onSignOut),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: Colors.white.withValues(alpha: 0.025),
            child: const ClerkSecuredBy(),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.65)),
            const SizedBox(width: 26),
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}
