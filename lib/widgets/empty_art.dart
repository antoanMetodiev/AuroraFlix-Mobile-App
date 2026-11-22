import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Line-art illustrations for empty states (website:
/// components/ui/empty-illustration.tsx), drawn from inline SVG so no asset
/// files are needed, with a soft glow behind and a slow float.
enum EmptyArt { search, watchlist, playlists, friends }

class EmptyIllustration extends StatefulWidget {
  const EmptyIllustration({super.key, required this.art, this.width = 176, this.height = 128, this.accent = Colors.white});

  final EmptyArt art;
  final double width;
  final double height;

  /// The highlighted strokes (website: var(--title-accent), white by default).
  final Color accent;

  @override
  State<EmptyIllustration> createState() => _EmptyIllustrationState();
}

class _EmptyIllustrationState extends State<EmptyIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final hex = '#${(widget.accent.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final svg = _svg(widget.art, hex);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _float,
        builder: (context, child) {
          // empty-float: 0 → -8px → 0 over 5s, eased.
          final t = _float.value;
          final dy = reduced ? 0.0 : -8 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
          return Transform.translate(offset: Offset(0, dy), child: child);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.width * 0.6,
              height: widget.height * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.10), blurRadius: 48, spreadRadius: 8)],
              ),
            ),
            SvgPicture.string(svg, width: widget.width, height: widget.height),
          ],
        ),
      ),
    );
  }
}

String _svg(EmptyArt art, String accent) {
  const w = '#ffffff';
  String sparkle(double x, double y, double r) =>
      '<path d="M$x ${y - r}v${r * 2}M${x - r} ${y}h${r * 2}" stroke="$w" stroke-opacity="0.5" stroke-width="1.6"/>';
  final body = switch (art) {
    EmptyArt.search => '''
<rect x="28" y="40" width="80" height="50" rx="6" stroke="$w" stroke-opacity="0.35"/>
${[0, 1, 2, 3, 4].map((i) => '<rect x="${34 + i * 15}" y="44" width="6" height="5" rx="1" stroke="$w" stroke-opacity="0.35"/><rect x="${34 + i * 15}" y="81" width="6" height="5" rx="1" stroke="$w" stroke-opacity="0.35"/>').join()}
<circle cx="98" cy="58" r="20" stroke="$accent"/>
<path d="M112 72l18 18" stroke-width="5" stroke="$accent"/>
<path d="M91 52q7-5 13 1" stroke="$w" stroke-opacity="0.4"/>''',
    EmptyArt.watchlist => '''
<rect x="40" y="56" width="74" height="36" rx="5" transform="rotate(-8 77 74)" stroke="$w" stroke-opacity="0.3"/>
<rect x="46" y="50" width="74" height="36" rx="5" stroke="$w" stroke-opacity="0.45"/>
<path d="M58 50v36M108 50v36" stroke-dasharray="3 4" stroke="$w" stroke-opacity="0.4"/>
<path d="M72 20h24v40l-12-8-12 8z" stroke="$accent"/>''',
    EmptyArt.playlists => '''
<rect x="52" y="22" width="56" height="12" rx="4" stroke="$w" stroke-opacity="0.25"/>
<rect x="44" y="34" width="72" height="14" rx="4" stroke="$w" stroke-opacity="0.4"/>
<rect x="36" y="48" width="88" height="50" rx="7" stroke="$w" stroke-opacity="0.7"/>
<circle cx="80" cy="73" r="13" stroke="$accent"/>
<path d="M76 66l10 7-10 7z" stroke="$accent"/>''',
    EmptyArt.friends => '''
<circle cx="52" cy="42" r="11" stroke="$w" stroke-opacity="0.6"/>
<path d="M32 92q2-26 20-26t20 26" stroke="$w" stroke-opacity="0.6"/>
<circle cx="108" cy="42" r="11" stroke="$w" stroke-opacity="0.4" stroke-dasharray="4 4"/>
<path d="M88 92q2-26 20-26t20 26" stroke="$w" stroke-opacity="0.4" stroke-dasharray="4 4"/>
<path d="M70 70h20l-3 26h-14z" stroke="$accent"/>
<path d="M70 70q2-8 6-4q4-8 8 0q4-4 6 4" stroke="$accent"/>''',
  };
  return '<svg viewBox="0 0 160 120" fill="none" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      '$body${sparkle(22, 24, 4.5)}${sparkle(140, 30, 3)}${sparkle(132, 98, 4.5)}</svg>';
}
