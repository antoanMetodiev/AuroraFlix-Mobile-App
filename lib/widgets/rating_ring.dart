import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A rating's tone — emerald (great) → lime → amber → rose (poor); same
/// bands as the website's RatingRing.
({Color from, Color to}) _tone(double value) {
  if (value >= 8) return (from: const Color(0xFF6EE7B7), to: const Color(0xFF10B981));
  if (value >= 6.5) return (from: const Color(0xFFD9F99D), to: const Color(0xFF84CC16));
  if (value >= 5) return (from: const Color(0xFFFDE68A), to: const Color(0xFFF59E0B));
  return (from: const Color(0xFFFDA4AF), to: const Color(0xFFE11D48));
}

/// TMDB rating colour (website: getRatingColor()).
Color ratingColor(double value) => _tone(value).to;

enum RatingRingSize { xs, sm, md }

/// The TMDB rating as a ring (website: RatingRing): a dark glass disc, a
/// faint full track, and an arc filled to the score with a two-tone gradient
/// and a soft glow in the rating's colour; "7.8" in the middle with the
/// decimal set smaller.
class RatingRing extends StatelessWidget {
  const RatingRing({super.key, required this.value, this.size = RatingRingSize.md});

  final double value;
  final RatingRingSize size;

  @override
  Widget build(BuildContext context) {
    final rating = value.isNaN ? 0.0 : value.clamp(0, 10).toDouble();
    final tone = _tone(rating);
    final (box, stroke, whole, decimal) = switch (size) {
      RatingRingSize.xs => (34.0, 3.0, 12.0, 8.0),
      RatingRingSize.sm => (44.0, 3.5, 15.0, 10.0),
      RatingRingSize.md => (58.0, 4.0, 20.0, 12.0),
    };
    final parts = rating.toStringAsFixed(1).split('.');

    return Semantics(
      label: 'TMDB ${rating.toStringAsFixed(1)} / 10',
      child: Container(
        width: box,
        height: box,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.4, -0.5),
            radius: 0.9,
            colors: [Color(0x29FFFFFF), Color(0xB8000000)],
            stops: [0, 0.7],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 14, spreadRadius: -2, offset: const Offset(0, 4)),
            BoxShadow(color: tone.to.withValues(alpha: 0.7), blurRadius: 18, spreadRadius: -6),
          ],
        ),
        child: CustomPaint(
          painter: _RingPainter(fraction: rating / 10, from: tone.from, to: tone.to, stroke: stroke),
          child: Center(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: parts[0],
                    style: TextStyle(fontSize: whole),
                  ),
                  TextSpan(
                    text: '.${parts[1]}',
                    style: TextStyle(fontSize: decimal, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: -0.3,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.from, required this.to, required this.stroke});

  final double fraction;
  final Color from;
  final Color to;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    // 1px inside the disc's border, like the website's r = (box - stroke) / 2 - 1.
    final arcRect = (Offset.zero & size).deflate(stroke / 2 + 1);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.12),
    );
    if (fraction <= 0) return;

    final sweep = math.pi * 2 * fraction;
    final gradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [from, to]);
    // The glow: the same arc, blurred, under the sharp one.
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = to.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(arcRect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.from != from || old.to != to || old.stroke != stroke;
}
