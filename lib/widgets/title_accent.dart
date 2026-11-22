import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// A title's own accent colour, taken from its poster (website:
/// components/movies/details/title-accent.tsx): the poster's most prominent
/// vivid hue, lifted to a brightness that reads on black. Null when the
/// poster has no real colour (black & white, all grey) or fails to load —
/// everything then keeps the default white.
final titleAccentProvider = FutureProvider.family<Color?, String>((ref, posterUrl) async {
  try {
    final response = await http.get(Uri.parse(posterUrl));
    if (response.statusCode != 200) return null;
    final codec = await ui.instantiateImageCodec(response.bodyBytes, targetWidth: 24, targetHeight: 36);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    if (data == null) return null;
    return _pickAccent(data.buffer.asUint8List(), 24 * 36);
  } catch (_) {
    return null;
  }
});

const _buckets = 18;

Color? _pickAccent(List<int> rgba, int pixels) {
  final weight = List<double>.filled(_buckets, 0);
  final sumSin = List<double>.filled(_buckets, 0);
  final sumCos = List<double>.filled(_buckets, 0);
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    final hsl = HSLColor.fromColor(Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]));
    if (hsl.saturation < 0.25 || hsl.lightness < 0.12 || hsl.lightness > 0.9) continue;
    final w = hsl.saturation * (1 - (hsl.lightness - 0.5).abs());
    final bucket = math.min(_buckets - 1, (hsl.hue / 360 * _buckets).floor());
    weight[bucket] += w;
    sumSin[bucket] += math.sin(hsl.hue * math.pi / 180) * w;
    sumCos[bucket] += math.cos(hsl.hue * math.pi / 180) * w;
  }
  var best = 0;
  for (var b = 1; b < _buckets; b++) {
    if (weight[b] > weight[best]) best = b;
  }
  if (weight[best] < pixels * 0.02) return null;
  final hue = (math.atan2(sumSin[best], sumCos[best]) * 180 / math.pi + 360) % 360;
  return HSLColor.fromAHSL(1, hue, 0.8, 0.62).toColor();
}

/// Hands the current title's accent down to the details screen's sections
/// (SectionHeading, the poster glow, chips, the Watch button…).
class TitleAccentScope extends InheritedWidget {
  const TitleAccentScope({super.key, required this.color, required super.child});

  /// Null outside a details screen, or before / without a colour.
  final Color? color;

  /// The accent, or white (the site's default accent) when there is none.
  static Color of(BuildContext context) => maybeOf(context) ?? Colors.white;

  static Color? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TitleAccentScope>()?.color;

  @override
  bool updateShouldNotify(TitleAccentScope old) => old.color != color;
}

/// Fades the accent in (website: the registered --title-accent property's
/// 900ms transition) and provides it to [child].
class AnimatedTitleAccent extends StatelessWidget {
  const AnimatedTitleAccent({super.key, required this.color, required this.child});

  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: Colors.white, end: color ?? Colors.white),
      duration: const Duration(milliseconds: 900),
      builder: (context, value, child) => TitleAccentScope(color: color == null ? null : value, child: child!),
      child: child,
    );
  }
}
