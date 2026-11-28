import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/fade_in_image.dart';

/// How long a title stays in the hero before moving on to the next one
/// (website: HeroBackground's TITLE_MS).
const _titleDuration = Duration(seconds: 10);

const _tick = Duration(milliseconds: 250);

/// The backdrop for this screen: w780 covers a phone (~3x lighter than
/// w1280); wider screens (tablets, TV) take w1280.
String? heroImageUrl(CinemaRecord record, BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final pixels = size.width * MediaQuery.devicePixelRatioOf(context);
  return tmdbImage(record.backgroundImgURL, pixels <= 780 ? TmdbSize.w780 : TmdbSize.w1280);
}

/// The hero's backdrop (website: HeroBackground): the title's own backdrop
/// with a slow zoom. One image per title — it used to be a slideshow of up to
/// five stills, which cost a catalog lookup and ~1 MB of extra images per
/// title (removed on the website on 2026-11-28, same here). After 10s the
/// parent moves on. Remounted per title by the parent, so the entrance plays
/// on every switch.
class HeroBackground extends ConsumerStatefulWidget {
  const HeroBackground({super.key, required this.record, required this.onEnded, required this.onProgress, this.active = true});

  final CinemaRecord record;
  final VoidCallback onEnded;

  /// 0–1 share of this title's time in the hero.
  final ValueChanged<double> onProgress;

  /// False while the home screen isn't on screen (another tab, a details
  /// page on top) — the clock stands still then.
  final bool active;

  @override
  ConsumerState<HeroBackground> createState() => _HeroBackgroundState();
}

class _HeroBackgroundState extends ConsumerState<HeroBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  Timer? _clock;
  int _elapsed = 0;
  bool _ended = false;
  // Flipped right after the first frame so the zoom eases 1 → 1.08 over the title's time.
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(_tick, (_) => _onTick());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _zoomed = true);
    });
  }

  void _onTick() {
    if (!widget.active || _ended) return;
    _elapsed += _tick.inMilliseconds;
    widget.onProgress((_elapsed / _titleDuration.inMilliseconds).clamp(0, 1).toDouble());
    if (_elapsed >= _titleDuration.inMilliseconds) {
      _ended = true;
      widget.onEnded();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _entrance, curve: auroraEase);
    final url = heroImageUrl(widget.record, context);

    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: 1.04, end: 1.0).animate(curved),
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url != null)
                ClipRect(
                  child: AnimatedScale(
                    scale: _zoomed ? 1.08 : 1.0,
                    duration: _titleDuration,
                    curve: Curves.linear,
                    child: AuroraImage(url: url),
                  ),
                ),
              // Dims the backdrop (z-10 on the site).
              IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: 0.45))),
            ],
          ),
        ),
      ),
    );
  }
}
