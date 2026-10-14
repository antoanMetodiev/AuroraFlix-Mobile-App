import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/fade_in_image.dart';

/// The details screen's background — the website's DetailsBackground: the 2nd
/// still from the gallery ("Кадри") — the 1st is usually the banner's shot —
/// lightly blurred, under a dark shade and a vignette ("shadow") toward the
/// edges; falls back to the 1st still / the banner image.
///
/// It sits behind the scrolling list and never moves; the RepaintBoundary
/// keeps the blur from being redrawn while the content scrolls over it.
class DetailsBackground extends StatelessWidget {
  const DetailsBackground({super.key, required this.record});

  final CinemaRecord record;

  @override
  Widget build(BuildContext context) => BlurredPageBackdrop(path: detailsBackgroundPath(record));
}

/// The TMDB image path a record's details screen uses as its background.
String? detailsBackgroundPath(CinemaRecord record) {
  final stills = record.imagesList.where((image) => image.imageType == ImageType.backdrop).toList();
  return stills.length > 1 ? stills[1].imageURL : (stills.firstOrNull?.imageURL ?? record.backgroundImgURL);
}

/// The blurred, shaded page background itself — also used by the actor
/// screen, which shows the background of the title it was opened from.
class BlurredPageBackdrop extends StatelessWidget {
  const BlurredPageBackdrop({super.key, required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final url = tmdbImage(path, TmdbSize.w780);

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            // Scaled up 10% so the blur's soft, see-through edges stay off-screen.
            Transform.scale(
              scale: 1.1,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12, tileMode: TileMode.decal),
                child: AuroraImage(url: url),
              ),
            ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
          // The "shadow": a vignette darkening the edges toward the page's black.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                // CSS ellipse-at-center (farthest corner): with the ellipse
                // transform below, 0.7071 of the shorter side reaches the corners.
                radius: 0.7071,
                colors: [Colors.transparent, Color(0xE6000000)],
                stops: [0.3, 1],
                transform: _EllipseTransform(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stretches a radial gradient into an ellipse with the box's own aspect
/// ratio, like CSS's radial-gradient(ellipse ...). Flutter's is a circle sized
/// by the shorter side, which would black out the ends of a tall screen.
class _EllipseTransform extends GradientTransform {
  const _EllipseTransform();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final shortest = bounds.shortestSide;
    final center = bounds.center;
    return Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(bounds.width / shortest, bounds.height / shortest, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }
}
