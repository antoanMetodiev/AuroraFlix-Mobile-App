import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Section title with the glowing white bar in front of it — the website's
/// SectionHeading (`mb-6`, `h-6 w-1` bar, `text-xl font-bold`).
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.padding = EdgeInsets.zero, this.spacing = 24, this.icon});

  final String text;
  final EdgeInsetsGeometry padding;

  /// Space below the heading (`mb-6`; 0 where it shares a row).
  final double spacing;

  /// Dimmed icon before the text (the comments heading has one).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding.add(EdgeInsets.only(bottom: spacing)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.45), blurRadius: 12)],
            ),
          ),
          const SizedBox(width: 12),
          if (icon != null) ...[Icon(icon, size: 20, color: AppColors.fg(0.6)), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              text,
              style: display(const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: AppColors.foreground)),
            ),
          ),
        ],
      ),
    );
  }
}
