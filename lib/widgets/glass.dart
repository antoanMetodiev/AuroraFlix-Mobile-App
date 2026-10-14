import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Frosted-glass panel — the site's `backdrop-blur-xl` + translucent fill +
/// hairline `border-foreground/10`, used by the header, tab bar and popovers.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.color = const Color(0x66000000),
    this.borderRadius = BorderRadius.zero,
    this.border,
    this.blur = 24,
    this.shadows,
    this.padding,
  });

  final Widget child;
  final Color color;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final double blur;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Shadow sits outside the clip, or ClipRRect would cut it off.
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color,
              borderRadius: borderRadius,
              border: border ?? Border.all(color: AppColors.fg(0.1)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
