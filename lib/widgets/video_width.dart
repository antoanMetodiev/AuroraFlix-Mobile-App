import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How wide a 16:9 player (a movie's player, its trailer) is drawn on a wide
/// screen — a tablet or a TV: at most the website's 80rem, and never taller
/// than the screen leaves room for under the header and above the tab bar,
/// so the whole picture is in view at once. Null on a phone, where the
/// players run the full width as before.
double? wideVideoWidth(BuildContext context) {
  final screen = MediaQuery.sizeOf(context);
  if (screen.width < 640) return null;
  return math.min(math.min(screen.width - 48, 1280), (screen.height - 160) * 16 / 9);
}
