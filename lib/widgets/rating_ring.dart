import 'dart:math' as math;

import 'package:flutter/material.dart';

/// TMDB rating color bands — same thresholds as the website's getRatingColor().
Color ratingColor(double value) {
  if (value >= 8) return const Color(0xFF16A34A);
  if (value >= 6.5) return const Color(0xFF65A30D);
  if (value >= 5) return const Color(0xFFF59E0B);
  return const Color(0xFFDC2626);
}

enum RatingRingSize { xs, sm, md }

/// Circular TMDB rating: a colored arc filled to rating × 10 %, over a faint
/// track, around the number (website: RatingRing / `.rating-ring`).
class RatingRing extends StatelessWidget {
  const RatingRing({super.key, required this.value, this.size = RatingRingSize.md, this.border});

  final double value;
  final RatingRingSize size;

  /// The hero and details header outline it (`border-2 border-white/55`).
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final rating = value.isNaN ? 0.0 : value.clamp(0, 10).toDouble();
    final (dimension, thickness) = switch (size) {
      RatingRingSize.xs => (32.0, 3.0),
      RatingRingSize.sm => (40.0, 4.0),
      RatingRingSize.md => (56.0, 5.0),
    };

    final ring = Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.45),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: CustomPaint(
        painter: _RingPainter(fraction: rating / 10, color: ratingColor(rating), thickness: thickness),
        child: Center(
          child: Container(
            width: dimension - thickness * 2,
            height: dimension - thickness * 2,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.55)),
            child: Text(
              rating.toStringAsFixed(1),
              style: TextStyle(fontSize: size == RatingRingSize.xs ? 11 : 12, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ),
        ),
      ),
    );

    if (border == null) return ring;
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.fromBorderSide(border!)),
      child: ring,
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.color, required this.thickness});

  final double fraction;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(thickness / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = color;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color || old.thickness != thickness;
}
