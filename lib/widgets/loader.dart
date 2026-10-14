import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The website's Spinner: a ring with one bright quarter, spinning fast.
class Spinner extends StatefulWidget {
  const Spinner({super.key, this.size = 32, this.color});

  final double size;
  final Color? color;

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.fg(0.7);
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(
          value: 0.25,
          strokeWidth: widget.size >= 28 ? 3 : 2,
          color: color,
          backgroundColor: color.withValues(alpha: 0.2),
          strokeCap: StrokeCap.butt,
        ),
      ),
    );
  }
}

/// Centered big spinner with breathing room (website: Loader, `py-24`).
class Loader extends StatelessWidget {
  const Loader({super.key, this.minHeight});

  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 96),
        child: Center(child: Spinner(size: 48)),
      ),
    );
  }
}
