import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Header dropdown panel (search, menu): fades and scales in from the corner
/// it's anchored to — the site's `scale-95 opacity-0` → `scale-100
/// opacity-100` over 200ms — and ignores touches (and focus) while closed.
class Popover extends StatelessWidget {
  const Popover({super.key, required this.open, required this.child, this.alignment = Alignment.topRight, this.width, this.bare = false});

  final bool open;
  final Widget child;
  final Alignment alignment;
  final double? width;

  /// The child draws its own panel (e.g. the Clerk-styled account menu).
  final bool bare;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 200);

    return IgnorePointer(
      ignoring: !open,
      child: ExcludeFocus(
        excluding: !open,
        child: AnimatedOpacity(
          opacity: open ? 1 : 0,
          duration: duration,
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: open ? 1 : 0.95,
            alignment: alignment,
            duration: duration,
            curve: Curves.easeOut,
            child: bare
                ? SizedBox(width: width, child: child)
                : Container(
                    width: width,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.fg(0.1)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 45, offset: const Offset(0, 20))],
                    ),
                    child: child,
                  ),
          ),
        ),
      ),
    );
  }
}
