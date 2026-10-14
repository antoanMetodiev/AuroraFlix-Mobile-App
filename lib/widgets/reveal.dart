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

/// The site's `.reveal` / `.reveal-hidden`: fades in and rises 28px into
/// place over 600ms once [visible] turns true, optionally after [delay].
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.visible, required this.child, this.delay = Duration.zero, this.offset = 28});

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
        duration: const Duration(milliseconds: 600),
        curve: auroraEase,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: offset, end: shown ? 0 : offset),
          duration: const Duration(milliseconds: 600),
          curve: auroraEase,
          builder: (context, dy, child) => Transform.translate(offset: Offset(0, dy), child: child),
          child: child,
        ),
      ),
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
