import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// ignore: unused_import — PAYMENTS / ASSISTANT DISABLED: their menu items use it.
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth/auth_controller.dart';
import '../core/i18n/locale.dart';
import '../core/theme.dart';
import '../widgets/language_toggle.dart';
import '../widgets/user_avatar.dart';
import '../widgets/pressable.dart';

const _linkedInUrl = 'https://www.linkedin.com/in/antoan-metodiev-875518303';

/// The hamburger sheet's contents — the website's mobile menu: what doesn't
/// fit in the tab bar (pricing, AI assistant), then account + language, then
/// the LinkedIn / credit line.
class NavMenu extends ConsumerWidget {
  const NavMenu({
    super.key,
    required this.onPricing,
    required this.onAssistant,
    required this.onSignIn,
    required this.onSignUp,
    required this.onAvatar,
    required this.onClose,
  });

  final VoidCallback onPricing;
  final VoidCallback onAssistant;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  /// Signed in: the avatar in place of Sign in / Sign up opens the account menu.
  final VoidCallback onAvatar;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final auth = ref.watch(authProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PAYMENTS DISABLED — nobody is charged for now (same on the website).
        // _MenuItem(icon: LucideIcons.crown, label: t('nav.pricing'), onTap: onPricing),
        // ASSISTANT DISABLED — off for now, on the website too.
        // // The assistant is signed-in only, like on the website.
        // if (auth.isSignedIn) _MenuItem(icon: LucideIcons.sparkles, label: t('assistant.title'), onTap: onAssistant),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(height: 1, thickness: 1, color: AppColors.fg(0.1)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              if (!auth.isLoaded)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.fg(0.1)),
                )
              else if (auth.isSignedIn)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Pressable(
                    onTap: onAvatar,
                    child: UserAvatar(user: auth.user!, size: 32),
                  ),
                )
              else ...[
                _SignInButton(label: t('nav.signIn'), onTap: onSignIn),
                const SizedBox(width: 4),
                _SignUpButton(label: t('nav.signUp'), onTap: onSignUp),
              ],
              const Spacer(),
              const LanguageToggle(),
            ],
          ),
        ),
        _MenuItem(
          leading: FaIcon(FontAwesomeIcons.linkedin, size: 17, color: AppColors.fg(0.75)),
          label: 'LinkedIn',
          onTap: () {
            onClose();
            launchUrl(Uri.parse(_linkedInUrl), mode: LaunchMode.externalApplication);
          },
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  // ignore: unused_element_parameter — PAYMENTS / ASSISTANT DISABLED: their menu items pass it.
  const _MenuItem({this.icon, this.leading, required this.label, required this.onTap});

  final IconData? icon;
  final Widget? leading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.97,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            leading ?? Icon(icon, size: 17, color: AppColors.fg(0.75)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.fg(0.75)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.fg(0.7)),
        ),
      ),
    );
  }
}

class _SignUpButton extends StatelessWidget {
  const _SignUpButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.55), blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 4))],
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onWhite),
        ),
      ),
    );
  }
}
