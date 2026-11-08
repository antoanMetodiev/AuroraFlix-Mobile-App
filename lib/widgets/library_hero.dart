import 'package:flutter/material.dart';

import '../core/theme.dart';

/// One stat card of [LibraryHero].
class LibraryStat {
  const LibraryStat({required this.icon, required this.label, required this.value, this.progress});

  final IconData icon;
  final String label;
  final String value;

  /// 0–1: fills a thin bar under the value (e.g. how full the list is).
  final double? progress;
}

final _eyebrow = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.8, color: AppColors.fg(0.45));

/// The top of the Watchlist and Playlists screens (website: LibraryHero): a
/// big gradient title, the subtitle, an optional action (e.g. "New
/// playlist") and the stat cards, two a row on a phone. The blurred poster
/// behind the page is the screen's own (see BlurredPageBackdrop).
class LibraryHero extends StatelessWidget {
  const LibraryHero({super.key, required this.title, required this.subtitle, required this.stats, this.action});

  final String title;
  final String subtitle;
  final List<LibraryStat> stats;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white.withValues(alpha: 0.65)],
          ).createShader(bounds),
          child: Text(
            title,
            style: display(
              const TextStyle(
                fontSize: 36,
                height: 1.02,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.8,
                shadows: [Shadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 4))],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(subtitle, style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.fg(0.6))),
        if (action != null) ...[const SizedBox(height: 20), action!],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 640 ? (stats.length == 3 ? 3 : 4) : 2;
              final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final stat in stats) SizedBox(width: width, child: _StatCard(stat: stat)),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final LibraryStat stat;

  @override
  Widget build(BuildContext context) {
    final progress = stat.progress;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Big faint icon in the corner.
          Positioned(right: -18, bottom: -18, child: Icon(stat.icon, size: 72, color: Colors.white.withValues(alpha: 0.05))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: -6, offset: const Offset(0, 6))],
                ),
                child: Icon(stat.icon, size: 16, color: AppColors.onWhite),
              ),
              const SizedBox(height: 12),
              Text(stat.label.toUpperCase(), style: _eyebrow, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(stat.value, style: const TextStyle(fontSize: 18, height: 1.3, fontWeight: FontWeight.w700)),
              if (progress != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 4,
                    color: Colors.white.withValues(alpha: 0.1),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress.clamp(0, 1).toDouble(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 10)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
