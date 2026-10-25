import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:visibility_detector/visibility_detector.dart';

import '../core/theme.dart';

/// Network image that shows a soft shimmer while loading and fades in once
/// it's there — the website's FadeInImage + SHIMMER_BLUR_DATA_URL. Cached on
/// disk, so a poster seen once never re-downloads.
class AuroraImage extends StatelessWidget {
  const AuroraImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.lazy = false,
  });

  final String? url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  /// Hold off downloading until the image is actually on screen — the
  /// website's loading="lazy", for long grids built all at once (a Wrap),
  /// where most posters start far below the fold. The shimmer shows until then.
  final bool lazy;

  @override
  Widget build(BuildContext context) {
    final source = url;
    if (source == null || source.isEmpty) return const Shimmer();
    if (lazy) return _LazyLoad(child: _image(source));
    return _image(source);
  }

  Widget _image(String source) {

    // In the browser (where the app is tested), an image the website already
    // loaded sits in Chrome's cache without its CORS header, so the CORS
    // fetch Flutter makes fails. The <img>-element fallback for that is a
    // trap: every such image becomes an HTML element with its own canvas
    // layer, and a grid of 30 posters freezes the page. A query parameter
    // gives each URL its own cache entry instead (the CDNs ignore it).
    // Native builds never hit any of this.
    if (kIsWeb) {
      final uri = Uri.parse(source);
      final bustable = const {'image.tmdb.org', 'res.cloudinary.com', 'img.clerk.com'}.contains(uri.host);
      return Image.network(
        bustable ? uri.replace(queryParameters: {...uri.queryParameters, 'app': '1'}).toString() : source,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        webHtmlElementStrategy: bustable ? WebHtmlElementStrategy.never : WebHtmlElementStrategy.fallback,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return Stack(
            fit: StackFit.passthrough,
            children: [
              if (frame == null) const Shimmer(),
              AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 450), curve: auroraEase, child: child),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) => ColoredBox(color: AppColors.fg(0.05)),
      );
    }

    return CachedNetworkImage(
      imageUrl: source,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 450),
      fadeInCurve: auroraEase,
      placeholder: (context, url) => const Shimmer(),
      errorWidget: (context, url, error) => ColoredBox(color: AppColors.fg(0.05)),
    );
  }
}

/// Shows a [Shimmer] until any part of [child]'s box is on screen, then
/// [child] for good (it isn't unloaded again on scrolling away).
class _LazyLoad extends StatefulWidget {
  const _LazyLoad({required this.child});

  final Widget child;

  @override
  State<_LazyLoad> createState() => _LazyLoadState();
}

class _LazyLoadState extends State<_LazyLoad> {
  final _key = UniqueKey();
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    if (_visible) return widget.child;
    return VisibilityDetector(
      key: _key,
      onVisibilityChanged: (info) {
        if (!_visible && mounted && info.visibleFraction > 0) setState(() => _visible = true);
      },
      child: const Shimmer(),
    );
  }
}

/// Loading placeholder: a faint light band sweeping across a dark tile.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.borderRadius = BorderRadius.zero});

  final BorderRadius borderRadius;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final x = _controller.value * 3 - 1.5;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(x - 1, -0.3),
              end: Alignment(x + 1, 0.3),
              colors: [AppColors.fg(0.04), AppColors.fg(0.10), AppColors.fg(0.04)],
            ),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
