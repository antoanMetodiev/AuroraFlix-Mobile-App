import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/i18n/locale.dart';
import 'pressable.dart';

/// The title page's main call to action (website: WatchNowButton) — a white
/// pill next to the watchlist/like buttons that glides down to the player
/// (for a series: the player + episode list).
class WatchNowButton extends ConsumerWidget {
  const WatchNowButton({super.key, required this.isSeries, required this.onTap});

  final bool isSeries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);

    return Pressable(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 6, right: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 28, spreadRadius: -6, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: Color(0xFF171717), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: isSeries
                  ? const Icon(LucideIcons.listVideo, size: 15, color: Colors.white)
                  : const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(
              t(isSeries ? 'episodes.jump' : 'player.watchNow'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF171717)),
            ),
          ],
        ),
      ),
    );
  }
}
