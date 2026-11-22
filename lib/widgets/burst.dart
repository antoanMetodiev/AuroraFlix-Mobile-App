import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The website's micro-animation for a like / save / new playlist
/// (components/ui/burst.tsx + .animate-pop): when [active] turns on, the
/// child pops (1 → 1.35 → 0.9 → 1) and a ring of little particles flies out
/// from its middle, with a light haptic tap. Off with reduced motion.
///
/// [trigger] can fire it without an on/off state (e.g. a playlist created):
/// every change of its value plays it once.
class Celebrate extends StatefulWidget {
  const Celebrate({
    super.key,
    required this.child,
    required this.colors,
    this.active,
    this.trigger,
    this.count = 10,
    this.distance = 28,
    this.particleSize = 5,
  });

  final Widget child;
  final List<Color> colors;
  final bool? active;
  final Object? trigger;
  final int count;
  final double distance;
  final double particleSize;

  @override
  State<Celebrate> createState() => _CelebrateState();
}

class _CelebrateState extends State<Celebrate> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void didUpdateWidget(Celebrate oldWidget) {
    super.didUpdateWidget(oldWidget);
    final turnedOn = widget.active == true && oldWidget.active == false;
    final triggered = widget.trigger != null && widget.trigger != oldWidget.trigger;
    if (turnedOn || triggered) _play();
  }

  void _play() {
    HapticFeedback.lightImpact();
    if (MediaQuery.of(context).disableAnimations) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// .animate-pop over the first ~70% of the run.
  double _popScale(double t) {
    final p = (t / 0.7).clamp(0.0, 1.0);
    if (p < 0.35) return 1 + 0.35 * (p / 0.35);
    if (p < 0.65) return 1.35 - 0.45 * ((p - 0.35) / 0.3);
    return 0.9 + 0.1 * ((p - 0.65) / 0.35);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final running = _controller.isAnimating;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.scale(scale: running ? _popScale(t) : 1, child: child),
            if (running)
              IgnorePointer(
                child: CustomPaint(
                  size: Size.zero,
                  painter: _BurstPainter(
                    progress: Curves.easeOutCubic.transform(t),
                    colors: widget.colors,
                    count: widget.count,
                    distance: widget.distance,
                    size: widget.particleSize,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.colors, required this.count, required this.distance, required this.size});

  final double progress;
  final List<Color> colors;
  final int count;
  final double distance;
  final double size;

  @override
  void paint(Canvas canvas, Size _) {
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2 + (i.isOdd ? 0.25 : 0);
      final reach = distance * (i.isOdd ? 0.75 : 1) * progress;
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: 1 - progress);
      canvas.drawCircle(Offset(math.cos(angle) * reach, math.sin(angle) * reach), size / 2 * (1 - 0.8 * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
