import 'package:flutter/material.dart';

/// Endless sliding strip — the site's `.animate-marquee*` rows and columns.
/// The items are laid out twice back to back and slid by exactly one copy's
/// length per [period], so the loop has no seam. [reverse] runs it the other
/// way. Holding a finger on it pauses it (the site pauses on hover).
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pause() => _controller.stop();
  void _resume() {
    if (!_controller.isAnimating) _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    final copyLength = widget.itemCount * (widget.itemExtent + widget.spacing);

    final items = [
      for (var copy = 0; copy < 2; copy++)
        for (var index = 0; index < widget.itemCount; index++)
          Padding(
            padding: horizontal ? EdgeInsets.only(right: widget.spacing) : EdgeInsets.only(bottom: widget.spacing),
            child: SizedBox(
              width: horizontal ? widget.itemExtent : null,
              height: horizontal ? null : widget.itemExtent,
              // Only the first copy is real; the second is decoration.
              child: ExcludeSemantics(excluding: copy == 1, child: widget.itemBuilder(context, index)),
            ),
          ),
    ];

    return Listener(
      onPointerDown: (_) => _pause(),
      onPointerUp: (_) => _resume(),
      onPointerCancel: (_) => _resume(),
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = widget.reverse ? 1 - _controller.value : _controller.value;
            final shift = -progress * copyLength;
            return Transform.translate(offset: horizontal ? Offset(shift, 0) : Offset(0, shift), child: child);
          },
          child: OverflowBox(
            alignment: horizontal ? Alignment.centerLeft : Alignment.topCenter,
            maxWidth: horizontal ? double.infinity : null,
            maxHeight: horizontal ? null : double.infinity,
            child: horizontal
                ? Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: items)
                : Column(mainAxisSize: MainAxisSize.min, children: items),
          ),
        ),
      ),
    );
  }
}
