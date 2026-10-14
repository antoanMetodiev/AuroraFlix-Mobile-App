import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/locale.dart';
import '../core/theme.dart';

/// EN | BG pill — the active option is a white chip with a soft glow, the
/// other dimmed text (my-app/components/layout/language-toggle.tsx).
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final t = ref.watch(translatorProvider);

    return Semantics(
      label: t('nav.languageAria'),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.fg(0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.fg(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in AppLocale.values)
              GestureDetector(
                onTap: () => ref.read(localeProvider.notifier).set(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: option == locale ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: option == locale
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.55),
                              blurRadius: 10,
                              spreadRadius: -2,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: option == locale ? AppColors.onWhite : AppColors.fg(0.5),
                    ),
                    child: Text(option.name.toUpperCase()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
