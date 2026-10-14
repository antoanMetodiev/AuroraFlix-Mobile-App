import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/i18n/locale.dart';
import '../core/theme.dart';
import 'pressable.dart';

/// Same small flags as the website's LanguageSelect (drawn as SVG, scaled to
/// cover a circle).
const _flags = {
  AppLocale.bg:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 18" preserveAspectRatio="xMidYMid slice">'
      '<rect width="30" height="6" fill="#ffffff"/><rect y="6" width="30" height="6" fill="#00966e"/>'
      '<rect y="12" width="30" height="6" fill="#d62612"/></svg>',
  AppLocale.el:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 27 18" preserveAspectRatio="xMidYMid slice">'
      '<rect width="27" height="18" fill="#0d5eaf"/><rect y="2" width="27" height="2" fill="#ffffff"/>'
      '<rect y="6" width="27" height="2" fill="#ffffff"/><rect y="10" width="27" height="2" fill="#ffffff"/>'
      '<rect y="14" width="27" height="2" fill="#ffffff"/><rect width="10" height="10" fill="#0d5eaf"/>'
      '<rect x="4" width="2" height="10" fill="#ffffff"/><rect y="4" width="10" height="2" fill="#ffffff"/></svg>',
  AppLocale.es:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 20" preserveAspectRatio="xMidYMid slice">'
      '<rect width="30" height="20" fill="#aa151b"/><rect y="5" width="30" height="10" fill="#f1bf00"/></svg>',
  AppLocale.en:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 30" preserveAspectRatio="xMidYMid slice">'
      '<rect width="60" height="30" fill="#012169"/>'
      '<path d="M0,0 L60,30 M60,0 L0,30" stroke="#ffffff" stroke-width="6"/>'
      '<path d="M0,0 L60,30 M60,0 L0,30" stroke="#c8102e" stroke-width="2.5"/>'
      '<path d="M30,0 V30 M0,15 H60" stroke="#ffffff" stroke-width="10"/>'
      '<path d="M30,0 V30 M0,15 H60" stroke="#c8102e" stroke-width="6"/></svg>',
};

class _Flag extends StatelessWidget {
  const _Flag(this.locale, {required this.size});

  final AppLocale locale;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SvgPicture.string(_flags[locale]!, fit: BoxFit.cover),
    );
  }
}

/// The language picker — my-app/components/layout/language-select.tsx: a
/// pill with the current flag and code that opens a glass menu of every
/// language (flag, its own name, a check on the current one).
class LanguageSelect extends ConsumerWidget {
  const LanguageSelect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final t = ref.watch(translatorProvider);

    return MenuAnchor(
      alignmentOffset: const Offset(-120, 10),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surface.withValues(alpha: 0.97)),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(16),
        shadowColor: const WidgetStatePropertyAll(Colors.black),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
      ),
      menuChildren: [
        for (final option in AppLocale.values)
          _LanguageItem(option: option, active: option == locale, onTap: () => ref.read(localeProvider.notifier).set(option)),
      ],
      builder: (context, controller, _) {
        final open = controller.isOpen;
        return Pressable(
          onTap: () => open ? controller.close() : controller.open(),
          semanticLabel: t('nav.languageAria'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 40,
            padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
            decoration: BoxDecoration(
              color: open ? Colors.white.withValues(alpha: 0.15) : AppColors.fg(0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: open ? Colors.white.withValues(alpha: 0.4) : AppColors.fg(0.1)),
              boxShadow: open ? [BoxShadow(color: Colors.white.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: -4)] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Flag(locale, size: 28),
                const SizedBox(width: 8),
                Text(
                  locale.name.toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.foreground),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(LucideIcons.chevronDown, size: 14, color: open ? AppColors.foreground : AppColors.fg(0.6)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LanguageItem extends StatelessWidget {
  const _LanguageItem({required this.option, required this.active, required this.onTap});

  final AppLocale option;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onTap,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        minimumSize: const WidgetStatePropertyAll(Size(212, 48)),
        backgroundColor: WidgetStatePropertyAll(active ? Colors.white.withValues(alpha: 0.1) : Colors.transparent),
        overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.06)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
      child: Row(
        children: [
          _Flag(option, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Translator.nativeNames[option]!,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.fg(0.85)),
              ),
              Text(
                option.name.toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: AppColors.fg(0.4)),
              ),
            ],
          ),
          const SizedBox(width: 24),
          AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(LucideIcons.check, size: 14, color: AppColors.onWhite),
            ),
          ),
        ],
      ),
    );
  }
}
