import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The site's `.bg-grain`: a fine noise texture laid over flat dark sections
/// at 3.5% opacity (overlay blend), so they don't read as sterile flat black.
/// One 180×180 tile is generated once and repeated.
class FilmGrain extends StatefulWidget {
  const FilmGrain({super.key, required this.child});

  final Widget child;

  @override
  State<FilmGrain> createState() => _FilmGrainState();
}

class _FilmGrainState extends State<FilmGrain> {
  static Future<ui.Image>? _tile;
  ui.Image? _image;

  static Future<ui.Image> _makeTile() {
    const size = 180;
    final random = math.Random(7);
    final pixels = Uint8List(size * size * 4);
    for (var i = 0; i < size * size; i++) {
      final v = random.nextInt(256);
      pixels[i * 4] = v;
      pixels[i * 4 + 1] = v;
      pixels[i * 4 + 2] = v;
      pixels[i * 4 + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, size, size, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  @override
  void initState() {
    super.initState();
    (_tile ??= _makeTile()).then((image) {
      if (mounted) setState(() => _image = image);
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Stack(
      children: [
        widget.child,
        if (image != null)
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _GrainPainter(image))),
          ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ImageShader(image, TileMode.repeated, TileMode.repeated, Matrix4.identity().storage)
      ..blendMode = BlendMode.overlay
      ..color = Colors.white.withValues(alpha: 0.035);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.image != image;
}

/// Fades a child to transparent along an axis — the site's `.edge-fade-x`,
/// `.edge-fade-y` and `.edge-fade-bottom` masks. [stops] are where the fully
/// opaque band starts and ends (0–1).
class EdgeFade extends StatelessWidget {
  const EdgeFade({
    super.key,
    required this.child,
    this.axis = Axis.horizontal,
    this.start = 0.05,
    this.end = 0.95,
    this.fadeStart = true,
    this.fadeEnd = true,
  });

  final Widget child;
  final Axis axis;
  final double start;
  final double end;
  final bool fadeStart;
  final bool fadeEnd;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
        end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
        colors: [fadeStart ? Colors.transparent : Colors.black, Colors.black, Colors.black, fadeEnd ? Colors.transparent : Colors.black],
        stops: [0, fadeStart ? start : 0, fadeEnd ? end : 1, 1],
      ).createShader(rect),
      child: child,
    );
  }
}
