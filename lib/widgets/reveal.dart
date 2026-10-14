import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core/theme.dart';

/// Fires once, the first time enough of [child] scrolls into view — the
/// website's useInViewOnce(threshold). The builder gets `inView`.
class InViewOnce extends StatefulWidget {
  const InViewOnce({super.key, required this.builder, this.threshold = 0.2});

  final Widget Function(BuildContext context, bool inView) builder;
  final double threshold;

  @override
  State<InViewOnce> createState() => _InViewOnceState();
}

class _InViewOnceState extends State<InViewOnce> {
  final _key = UniqueKey();
  bool _inView = false;

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(context, _inView);
    if (_inView) return child;

    return VisibilityDetector(
      key: _key,
      onVisibilityChanged: (info) {
        // Very tall content (a whole results grid) never reaches a fraction
        // threshold, so a solid 200px on screen counts too.
        final seen = info.visibleFraction >= widget.threshold || info.visibleBounds.height >= 200;
        if (!_inView && mounted && seen) {
          setState(() => _inView = true);
        }
      },
      child: child,
    );
  }
}

/// The site's `.reveal` / `.reveal-hidden`: floats up into place — fades
/// in, rises [offset] (56px) and grows from 98% — over 900ms once [visible]
/// turns true, optionally after [delay].
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.visible, required this.child, this.delay = Duration.zero, this.offset = 56});

  final bool visible;
  final Widget child;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return _DelayedFlag(
      value: visible,
      delay: delay,
      builder: (shown) => AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: const Duration(milliseconds: 900),
        curve: auroraEase,
        child: TweenAnimationBuilder<double>(
          // 0 = hidden (lowered, 98%), 1 = in place.
          tween: Tween(begin: 0, end: shown ? 1 : 0),
          duration: const Duration(milliseconds: 900),
          curve: auroraEase,
          builder: (context, progress, child) => Transform.translate(
            offset: Offset(0, offset * (1 - progress)),
            child: Transform.scale(scale: 0.98 + 0.02 * progress, child: child),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A section that floats up the first time it scrolls into view — the
/// website's `Reveal` wrapper, for sections without their own entrance.
class RevealOnScroll extends StatelessWidget {
  const RevealOnScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InViewOnce(
      threshold: 0.12,
      builder: (context, inView) => Reveal(visible: inView, child: child),
    );
  }
}

class _DelayedFlag extends StatefulWidget {
  const _DelayedFlag({required this.value, required this.delay, required this.builder});

  final bool value;
  final Duration delay;
  final Widget Function(bool value) builder;

  @override
  State<_DelayedFlag> createState() => _DelayedFlagState();
}

class _DelayedFlagState extends State<_DelayedFlag> {
  late bool _value = widget.value;

  @override
  void didUpdateWidget(_DelayedFlag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    if (!widget.value || widget.delay == Duration.zero) {
      _value = widget.value;
      return;
    }
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _value = widget.value);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(_value);
}
