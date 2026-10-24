import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A quick, smooth in-page jump (website: lib/smooth-scroll.ts) — a short
/// ease-in-out whose duration grows with the distance.
///
/// The target usually sits in a lazily built ListView, so it may not exist
/// yet when the jump starts. Then the scroll eases into a steady glide
/// downwards until the target gets built, and from there eases out onto it
/// at the speed it already has — one continuous motion either way.
class SlowScroller {
  SlowScroller(TickerProvider vsync) {
    _ticker = vsync.createTicker(_tick);
  }

  static const _minDurationMs = 700.0;
  static const _maxDurationMs = 1300.0;
  static const _msPerPixel = 0.4;
  static const _cruiseSpeed = 1 / _msPerPixel; // px per ms
  static const _accelerationMs = 300.0;

  late final Ticker _ticker;
  ScrollController? _controller;
  GlobalKey? _target;
  double _topInset = 0;

  double _lastMs = 0;
  double _speed = 0;

  // The final leg, once the target's offset is known.
  double? _legFrom;
  double _legDistance = 0;
  double _legStartMs = 0;
  double _legDurationMs = 0;
  bool _legEasesIn = false;

  /// Slowly scrolls [controller] so [target] lands [topInset] below the top.
  void scrollTo(ScrollController controller, GlobalKey target, {double topInset = 0}) {
    cancel();
    if (!controller.hasClients) return;
    _controller = controller;
    _target = target;
    _topInset = topInset;
    _lastMs = 0;
    _speed = 0;
    _legFrom = null;

    final offset = _targetOffset();
    if (offset != null) _startLeg(controller.position.pixels, offset, 0, easeIn: true);
    _ticker.start();
  }

  /// Stops a running jump — call it as soon as the user touches the screen.
  void cancel() {
    if (_ticker.isActive) _ticker.stop();
  }

  void dispose() => _ticker.dispose();

  double? _targetOffset() {
    final renderObject = _target?.currentContext?.findRenderObject();
    if (renderObject == null || !renderObject.attached) return null;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return null;
    final position = _controller!.position;
    final offset = viewport.getOffsetToReveal(renderObject, 0).offset - _topInset;
    return offset.clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  void _startLeg(double from, double to, double nowMs, {required bool easeIn}) {
    final distance = to - from;
    _legFrom = from;
    _legDistance = distance;
    _legStartMs = nowMs;
    _legEasesIn = easeIn;
    _legDurationMs = easeIn
        ? (distance.abs() * _msPerPixel).clamp(_minDurationMs, _maxDurationMs)
        // Ease-out-cubic starts at 3·distance/duration px/ms — pick the
        // duration that keeps the speed the glide already had.
        : math.max(350, 3 * distance.abs() / math.max(_speed, 0.05));
  }

  void _tick(Duration elapsed) {
    final controller = _controller;
    if (controller == null || !controller.hasClients) {
      cancel();
      return;
    }
    final position = controller.position;
    final nowMs = elapsed.inMicroseconds / 1000;

    if (_legFrom == null) {
      final offset = _targetOffset();
      if (offset != null) {
        _startLeg(position.pixels, offset, nowMs, easeIn: false);
      } else {
        // Target not built yet: glide on downwards, easing up to cruise speed.
        _speed = _cruiseSpeed * math.min(1, nowMs / _accelerationMs);
        final next = math.min(position.pixels + _speed * (nowMs - _lastMs), position.maxScrollExtent);
        _lastMs = nowMs;
        position.jumpTo(next);
        if (next >= position.maxScrollExtent) cancel();
        return;
      }
    }

    final progress = math.min(1.0, (nowMs - _legStartMs) / _legDurationMs);
    final eased = _legEasesIn ? Curves.easeInOutCubic.transform(progress) : Curves.easeOutCubic.transform(progress);
    position.jumpTo(_legFrom! + _legDistance * eased);
    if (progress >= 1) cancel();
  }
}
