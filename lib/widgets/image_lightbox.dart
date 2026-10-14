import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/tmdb.dart';
import 'fade_in_image.dart';
import 'pressable.dart';

enum LightboxShape { backdrop, poster, actor }

/// Full-screen image viewer (website: BigImageLightbox): the picture on a
/// deep black vignette with a white glow, swipe sideways to page
/// through the set, ✕ in the corner; tap outside to close.
Future<void> showImageLightbox(
  BuildContext context, {
  required List<String> paths,
  required int initialIndex,
  required LightboxShape shape,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => _Lightbox(paths: paths, initialIndex: initialIndex, shape: shape),
    transitionBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
}

class _Lightbox extends StatefulWidget {
  const _Lightbox({required this.paths, required this.initialIndex, required this.shape});

  final List<String> paths;
  final int initialIndex;
  final LightboxShape shape;

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late int _index = widget.initialIndex;

  void _go(int delta) => setState(() => _index = (_index + delta + widget.paths.length) % widget.paths.length);

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final (widthFactor, aspect) = switch (widget.shape) {
      LightboxShape.backdrop => (0.9, 60 / 32),
      LightboxShape.poster => (0.85, 26 / 37),
      LightboxShape.actor => (0.8, 22 / 35),
    };
    final canNavigate = widget.paths.length > 1;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [Color(0xF2000000), Colors.black], stops: [0.2, 0.8]),
              ),
            ),
          ),
        ),
        Center(
          child: GestureDetector(
            onHorizontalDragEnd: canNavigate
                ? (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity.abs() > 50) _go(velocity < 0 ? 1 : -1);
                  }
                : null,
            child: SizedBox(
              width: screen.width * widthFactor,
              child: AspectRatio(
                aspectRatio: aspect,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withValues(alpha: 0.05),
                          boxShadow: [
                            BoxShadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 15)),
                            BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 60),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: AuroraImage(key: ValueKey(_index), url: tmdbImage(widget.paths[_index], TmdbSize.w1280)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 20,
          right: 20,
          child: Pressable(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
              child: const Icon(LucideIcons.x, size: 20, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
