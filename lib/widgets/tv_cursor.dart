import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A mouse pointer driven by a TV remote, like a TV browser's: the arrows
/// move it (faster the longer they're held), OK clicks where it points (held,
/// it's a long press), and pushing it against an edge of the screen scrolls
/// whatever lies under it — a row of cards sideways, the page up and down.
///
/// It feeds ordinary mouse events into the app, so everything that reacts to
/// a finger or a mouse — buttons, carousels, the players' web pages — works
/// as it is.
class TvCursor extends StatefulWidget {
  const TvCursor({super.key, required this.child});

  final Widget child;

  @override
  State<TvCursor> createState() => _TvCursorState();
}

final _directions = {
  LogicalKeyboardKey.arrowUp: Offset(0, -1),
  LogicalKeyboardKey.arrowDown: Offset(0, 1),
  LogicalKeyboardKey.arrowLeft: Offset(-1, 0),
  LogicalKeyboardKey.arrowRight: Offset(1, 0),
};

final _clickKeys = {LogicalKeyboardKey.select, LogicalKeyboardKey.enter, LogicalKeyboardKey.numpadEnter, LogicalKeyboardKey.gameButtonA};

/// The remote's keys that drive the cursor, kept away from the focus system
/// (which would otherwise move an invisible focus around as well).
final tvCursorShortcuts = <ShortcutActivator, Intent>{
  ...WidgetsApp.defaultShortcuts,
  for (final key in [..._directions.keys, ..._clickKeys]) SingleActivator(key): const DoNothingAndStopPropagationIntent(),
};

// Out of the way of the device ids and pointer ids the engine hands out.
const _deviceId = 7331;
const _firstPointer = 1 << 20;

class _TvCursorState extends State<TvCursor> with SingleTickerProviderStateMixin {
  final _position = ValueNotifier<Offset>(Offset.zero);
  final _clock = Stopwatch()..start();
  late final Ticker _ticker = createTicker((_) => _tick());

  /// Arrow → when it went down.
  final _held = <Offset, Duration>{};
  Duration? _lastTick;

  Size _size = Size.zero;
  bool _placed = false;
  int _viewId = 0;
  bool _added = false;
  bool _down = false;
  int _pointer = _firstPointer;
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ticker.dispose();
    _position.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    final direction = _directions[event.logicalKey];
    if (direction != null) {
      if (event is KeyDownEvent) {
        _held[direction] = _clock.elapsed;
        // A short press nudges it a little, for fine aiming.
        _moveBy(direction * (_size.shortestSide * 0.012));
        if (!_ticker.isActive) {
          _lastTick = null;
          _ticker.start();
        }
      } else if (event is KeyUpEvent) {
        _held.remove(direction);
      }
      return true;
    }
    if (_clickKeys.contains(event.logicalKey)) {
      if (event is KeyDownEvent && !_down) {
        _press();
      } else if (event is KeyUpEvent && _down) {
        _release();
      }
      return true;
    }
    return false;
  }

  void _tick() {
    final now = _clock.elapsed;
    final last = _lastTick;
    _lastTick = now;
    if (_held.isEmpty) {
      _ticker.stop();
      return;
    }
    if (last == null) return;
    final dt = (now - last).inMicroseconds / 1e6;
    var delta = Offset.zero;
    _held.forEach((direction, since) => delta += direction * (_speed((now - since).inMicroseconds / 1e6) * dt));
    _moveBy(delta);
  }

  /// Logical pixels a second, after an arrow has been held [held] seconds:
  /// still for a moment (the nudge already moved it), then from a third of
  /// the screen's height a second up to about one and a half.
  double _speed(double held) {
    final side = _size.shortestSide;
    if (held < 0.18) return 0;
    return math.min(side * 0.35 + side * 1.4 * (held - 0.18), side * 1.5);
  }

  void _moveBy(Offset delta) {
    if (_size.isEmpty || delta == Offset.zero) return;
    final wanted = _position.value + delta;
    // The tip stops short of the right and bottom edges, so the arrow
    // (drawn down and to the right of it) stays on screen.
    final next = Offset(wanted.dx.clamp(0, _size.width - 14), wanted.dy.clamp(0, _size.height - 22));
    // Whatever runs past the edge scrolls instead.
    final overflow = wanted - next;
    if (overflow.dx != 0) _scroll(Offset(overflow.dx, 0));
    if (overflow.dy != 0) _scroll(Offset(0, overflow.dy));
    if (next == _position.value) return;
    _position.value = next;
    _ensureAdded();
    _send(
      _down
          ? PointerMoveEvent(
              viewId: _viewId,
              timeStamp: _clock.elapsed,
              pointer: _pointer,
              kind: PointerDeviceKind.mouse,
              device: _deviceId,
              position: next,
              buttons: kPrimaryMouseButton,
            )
          : PointerHoverEvent(viewId: _viewId, timeStamp: _clock.elapsed, kind: PointerDeviceKind.mouse, device: _deviceId, position: next),
    );
  }

  /// Scrolls what's under the pointer, as a mouse wheel would. At the sides
  /// the pointer is often in the page's margin, just past the end of a row
  /// of cards (which draws on past its own edge), so a little further in is
  /// tried too. At the top and bottom it usually sits on the header or the
  /// tab bar, so if nothing there scrolls, the page mid-screen does.
  void _scroll(Offset delta) {
    final at = _position.value;
    final inward = delta.dx > 0 ? -1.0 : 1.0;
    final probes = delta.dx != 0 ? [at, at.translate(inward * 40, 0), at.translate(inward * 100, 0)] : [at, Offset(at.dx, _size.height / 2)];
    for (final probe in probes) {
      _scrolled = false;
      _send(
        PointerScrollEvent(
          viewId: _viewId,
          timeStamp: _clock.elapsed,
          kind: PointerDeviceKind.mouse,
          device: _deviceId,
          position: probe,
          scrollDelta: delta,
        ),
      );
      if (_scrolled) return;
    }
  }

  void _press() {
    _ensureAdded();
    _down = true;
    _pointer++;
    _send(
      PointerDownEvent(
        viewId: _viewId,
        timeStamp: _clock.elapsed,
        pointer: _pointer,
        kind: PointerDeviceKind.mouse,
        device: _deviceId,
        position: _position.value,
        buttons: kPrimaryMouseButton,
      ),
    );
  }

  void _release() {
    _down = false;
    _send(
      PointerUpEvent(
        viewId: _viewId,
        timeStamp: _clock.elapsed,
        pointer: _pointer,
        kind: PointerDeviceKind.mouse,
        device: _deviceId,
        position: _position.value,
      ),
    );
  }

  void _ensureAdded() {
    if (_added) return;
    _added = true;
    _send(PointerAddedEvent(viewId: _viewId, timeStamp: _clock.elapsed, kind: PointerDeviceKind.mouse, device: _deviceId, position: _position.value));
  }

  void _send(PointerEvent event) => GestureBinding.instance.handlePointerEvent(event);

  @override
  Widget build(BuildContext context) {
    _viewId = View.of(context).viewId;
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (_) {
        _scrolled = true;
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = constraints.biggest;
          if (!_placed && !_size.isEmpty) {
            _placed = true;
            _position.value = _size.center(Offset.zero);
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              ValueListenableBuilder<Offset>(
                valueListenable: _position,
                builder: (context, position, _) => Positioned(
                  left: position.dx,
                  top: position.dy,
                  child: const IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(size: Size(26, 42), painter: _ArrowPainter()),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The classic arrow pointer, white with a dark outline, its tip at (0, 0).
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 13;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, 18 * s)
      ..lineTo(4.4 * s, 13.8 * s)
      ..lineTo(7.4 * s, 20.6 * s)
      ..lineTo(10.2 * s, 19.4 * s)
      ..lineTo(7.3 * s, 12.8 * s)
      ..lineTo(13 * s, 12.8 * s)
      ..close();
    canvas.drawShadow(path, const Color(0xFF000000), 3, true);
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => false;
}
