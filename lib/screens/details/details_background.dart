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
/// screen, which shows the background of the title it was opened from, and
/// the movies / series lists (ListBackground), which pass their own image as
/// [url].
class BlurredPageBackdrop extends StatelessWidget {
  const BlurredPageBackdrop({super.key, this.path, this.url});

  /// A TMDB image path.
  final String? path;

  /// A full image URL, used instead of [path].
  final String? url;

  @override
  Widget build(BuildContext context) {
    final url = this.url ?? tmdbImage(path, TmdbSize.w780);

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12, tileMode: TileMode.decal),
              // Keyed by url: a new image (e.g. the home screen's next pick) fades in afresh.
              child: _BackdropImage(key: ValueKey(url), url: url),
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

/// The website's BackdropImage: the image waits until it has actually
/// loaded, then rises from black while gently settling from a slight zoom
/// (1.18 → its resting 1.1, which keeps the blur's soft, see-through edges
/// off-screen). Always animates — even when the image is already cached —
/// so every visit gets the same smooth entrance. Only opacity and scale
/// animate, never the blur.
class _BackdropImage extends StatefulWidget {
  const _BackdropImage({super.key, required this.url});

  final String url;

  @override
  State<_BackdropImage> createState() => _BackdropImageState();
}

class _BackdropImageState extends State<_BackdropImage> {
  /// The site's cubic-bezier(0.22, 1, 0.36, 1) over 1.8s.
  static const _curve = Cubic(0.22, 1, 0.36, 1);
  static const _duration = Duration(milliseconds: 1800);

  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _loaded ? 1.1 : 1.18,
      duration: _duration,
      curve: _curve,
      child: AnimatedOpacity(
        opacity: _loaded ? 1 : 0,
        duration: _duration,
        curve: _curve,
        child: Image(
          image: auroraImageProvider(widget.url),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            // First frame decoded: start the entrance on the next frame, so
            // it animates from 0 even when the image was already in memory.
            if (frame != null && !_loaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_loaded) setState(() => _loaded = true);
              });
            }
            return child;
          },
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
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
