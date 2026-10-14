import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The website's design tokens (my-app/app/globals.css): a single fixed dark
/// theme, true-black page, near-white text, one slightly elevated surface for
/// sheets/popovers. Every accent is white — translucent overlays use
/// [foreground] at an opacity instead of their own colors.
abstract final class AppColors {
  static const background = Color(0xFF000000);
  static const foreground = Color(0xFFF5F5F5);
  static const surface = Color(0xFF201F21);

  /// Tailwind's neutral-900 — the dark text on white pills.
  static const onWhite = Color(0xFF171717);

  // Secondary accents used in a few sections on the site.
  static const sky = Color(0xFF38BDF8);
  static const emerald = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);

  /// `foreground/N` from the site, e.g. `fg(0.1)` for `border-foreground/10`.
  static Color fg(double opacity) => foreground.withValues(alpha: opacity);
}

/// The site's signature easing, cubic-bezier(0.16, 1, 0.3, 1) — used for
/// every entrance (hero, cards, modals, reveals).
const Curve auroraEase = Cubic(0.16, 1, 0.3, 1);

ThemeData buildAppTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.background,
      onSurface: AppColors.foreground,
      primary: Colors.white,
      onPrimary: AppColors.onWhite,
      secondary: AppColors.sky,
      surfaceContainerHighest: AppColors.surface,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );

  return base.copyWith(
    textTheme: GoogleFonts.geistTextTheme(base.textTheme).apply(bodyColor: AppColors.foreground, displayColor: AppColors.foreground),
  );
}
