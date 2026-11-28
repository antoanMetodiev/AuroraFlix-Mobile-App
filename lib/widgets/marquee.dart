import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Endless sliding strip — the site's `.animate-marquee*` rows and columns.
/// The items are laid out twice back to back and slid by exactly one copy's
/// length per [period], so the loop has no seam. [reverse] runs it the other
/// way. Holding a finger on it pauses it (the site pauses on hover), and so
/// does scrolling it off screen.
class Marquee extends StatefulWidget {
  const Marquee({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemExtent,
    required this.spacing,
    required this.period,
    this.axis = Axis.horizontal,
    this.reverse = false,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Size of one item along [axis] (width for a row, height for a column).
  final double itemExtent;
  final double spacing;
  final Duration period;
  final Axis axis;
  final bool reverse;

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void didUpdateWidget(Marquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller
        ..duration = widget.period
        ..repeat();
    }
    if (oldWidget.itemCount != widget.itemCount) {
      for (final node in _itemFocus) {
        node.dispose();
      }
      _itemFocus = _createItemFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final node in _itemFocus) {
      node.dispose();
    }
    super.dispose();
  }

  final _visibilityKey = UniqueKey();
  bool _held = false;
  bool _onScreen = true;
  bool _focusInside = false;
  bool _nudging = false;
  double _viewportExtent = 0;

  /// Runs only while on screen, not held down and not being browsed with a
  /// remote.
  void _sync() {
    if (_held || !_onScreen || _focusInside) {
      if (!_nudging) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _pause() {
    _held = true;
    _sync();
  }

  void _resume() {
    _held = false;
    _sync();
  }

  /// One per laid-out item, both copies: a remote can land on whichever copy
  /// is on screen, and hop to its twin when the loop wraps.
  late List<FocusNode> _itemFocus = _createItemFocus();

  List<FocusNode> _createItemFocus() => List.generate(widget.itemCount * 2, (_) => FocusNode(canRequestFocus: false, skipTraversal: true));

  double get _progress => widget.reverse ? 1 - _controller.value : _controller.value;

  /// Slides the (paused) strip just enough to keep the item a remote focused
  /// in full view, since most of the strip is clipped away.
  void _bringIntoView(int slot) {
    final step = widget.itemExtent + widget.spacing;
    final copyLength = widget.itemCount * step;
    final position = slot * step;
    final visibleAt = position - _progress * copyLength;
    final margin = widget.spacing * 2;
    final target = visibleAt.clamp(margin, math.max(margin, _viewportExtent - widget.itemExtent - margin));
    if (target == visibleAt) return;

    final progress = (position - target) / copyLength;
    if (progress >= 0 && progress < 1) {
      final value = widget.reverse ? 1 - progress : progress;
      _nudging = true;
      _controller.animateTo(value, duration: const Duration(milliseconds: 250), curve: Curves.easeOut).whenCompleteOrCancel(() => _nudging = false);
      return;
    }
    // This copy can't get there — its twin, one copy's length away, can.
    // Both copies look the same, so jump straight there and move to the twin.
    final twinProgress = progress < 0 ? progress + 1 : progress - 1;
    final twin = (slot + widget.itemCount) % (widget.itemCount * 2);
    _controller.value = widget.reverse ? 1 - twinProgress : twinProgress;
    _itemFocus[twin].children.firstOrNull?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    final step = widget.itemExtent + widget.spacing;
    final copyLength = widget.itemCount * step;

    final items = [
      for (var copy = 0; copy < 2; copy++)
        for (var index = 0; index < widget.itemCount; index++)
          KeyedSubtree(
            key: ValueKey(copy * widget.itemCount + index),
            child: SizedBox(
              width: horizontal ? widget.itemExtent : null,
              height: horizontal ? null : widget.itemExtent,
              // For screen readers only the first copy is real.
              child: ExcludeSemantics(
                excluding: copy == 1,
                child: Focus(
                  focusNode: _itemFocus[copy * widget.itemCount + index],
                  onFocusChange: (focused) {
                    if (focused) _bringIntoView(copy * widget.itemCount + index);
                  },
                  child: widget.itemBuilder(context, index),
                ),
              ),
            ),
          ),
    ];

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        if (!mounted) return;
        _onScreen = info.visibleFraction > 0;
        _sync();
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) {
          _focusInside = focused;
          _sync();
        },
        child: Listener(
          onPointerDown: (_) => _pause(),
          onPointerUp: (_) => _resume(),
          onPointerCancel: (_) => _resume(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewportExtent = horizontal ? constraints.maxWidth : constraints.maxHeight;
              // Each item is positioned on its own inside a viewport-sized
              // Stack, so where it's drawn is also where it can be tapped.
              // (This used to slide one oversized Row/Column with
              // Transform.translate inside an OverflowBox — but taps are only
              // tested within the OverflowBox's own, viewport-sized bounds,
              // in unshifted coordinates, so once the strip had moved, the
              // cards on screen were outside them: tapping a cult title or a
              // trending poster did nothing.)
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = widget.reverse ? 1 - _controller.value : _controller.value;
                  final shift = -progress * copyLength;
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // Keeps the Stack viewport-sized: every item below is positioned.
                      const SizedBox.expand(),
                      for (var slot = 0; slot < items.length; slot++)
                        horizontal
                            ? Positioned(left: slot * step + shift, top: 0, child: items[slot])
                            : Positioned(top: slot * step + shift, left: 0, right: 0, child: items[slot]),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
