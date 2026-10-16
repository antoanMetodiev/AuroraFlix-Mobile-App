import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n/locale.dart';
import '../core/theme.dart';
import 'pressable.dart';

/// The website's StatusPage for "not found": a huge dimmed 404 behind the
/// heading over a soft radial glow, then Home / Movies / Series buttons.
class NotFoundPage extends ConsumerWidget {
  const NotFoundPage({super.key, required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);

    Widget button(String label, String path, {bool primary = false}) => Pressable(
      onTap: () => context.go(path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? Colors.white : AppColors.fg(0.1),
          borderRadius: BorderRadius.circular(999),
          border: primary ? null : Border.all(color: AppColors.fg(0.15)),
          boxShadow: primary
              ? [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 8))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
            color: primary ? AppColors.onWhite : AppColors.fg(0.8),
          ),
        ),
      ),
    );

    return Padding(
      padding: padding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.08), Colors.transparent], stops: const [0, 0.6]),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
            child: Column(
              children: [
                Text(
                  '404',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 112,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -5,
                    color: AppColors.fg(0.07),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Column(
                    children: [
                      Text(
                        t('status.notFoundTitle'),
                        textAlign: TextAlign.center,
                        style: display(const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('status.notFoundDesc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.fg(0.5)),
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          button(t('status.goHome'), '/', primary: true),
                          button(t('status.browseMovies'), '/movies'),
                          button(t('status.browseSeries'), '/series'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
