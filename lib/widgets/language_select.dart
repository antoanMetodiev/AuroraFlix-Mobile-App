import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/i18n/locale.dart';
import '../core/theme.dart';
import 'pressable.dart';

/// The language picker — my-app/components/layout/language-select.tsx: a
/// pill with the current language code (text only, no flags) that opens a glass menu of every
/// language (its own name, a check on the current one).
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
            padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
            decoration: BoxDecoration(
              color: open ? Colors.white.withValues(alpha: 0.15) : AppColors.fg(0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: open ? Colors.white.withValues(alpha: 0.4) : AppColors.fg(0.1)),
              boxShadow: open ? [BoxShadow(color: Colors.white.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: -4)] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
