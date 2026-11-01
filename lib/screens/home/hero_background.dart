import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/catalog_api.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/fade_in_image.dart';

/// How long each still stays up before the next fades in.
const _slide = Duration(seconds: 6);

/// The cross-fade between two stills.
const _fade = Duration(milliseconds: 1500);

/// Stills per title: its own backdrop plus up to four more from the catalog.
const _maxSlides = 5;

/// How long a title stays in the hero before moving on to the next one.
final _titleMs = _slide.inMilliseconds * _maxSlides;

const _tick = Duration(milliseconds: 250);

/// The hero's backdrop (website: HeroBackground): a slideshow of the title's
/// own stills, cross-fading every 6s with a slow zoom — in place of the
/// YouTube trailers it used to play. It opens on the trending row's backdrop
/// at once; the rest come from the catalog record (get-movie-details /
/// get-series-details), each shown only once it has loaded. After 30s the
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

  late final List<String> _slides = [?tmdbImage(widget.record.backgroundImgURL, TmdbSize.w1280)];
  Timer? _clock;
  int _elapsed = 0;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(_tick, (_) => _onTick());
    _loadMoreStills();
  }

  /// Trending movie rows carry the TMDB id as movieId, series as tmdbId.
  String? get _tmdbId => widget.record.tmdbId ?? widget.record.movieId;

  Future<void> _loadMoreStills() async {
    final id = _tmdbId;
    if (id == null) return;
    try {
      final details = await ref.read(catalogApiProvider).details(widget.record.type, id);
      if (!mounted || details == null) return;
      final seen = {widget.record.backgroundImgURL};
      final extra = details.imagesList
          .where((image) => image.imageType == ImageType.backdrop && image.imageURL.isNotEmpty && seen.add(image.imageURL))
          .take(_maxSlides - 1)
          .map((image) => tmdbImage(image.imageURL, TmdbSize.w1280))
          .whereType<String>();
      for (final url in extra) {
        // Only once it's decoded, so a slide never fades in half-drawn.
        unawaited(
          precacheImage(_provider(url), context)
              .then((_) {
                if (mounted && !_slides.contains(url)) setState(() => _slides.add(url));
              })
              .catchError((_) {}),
        );
      }
    } catch (_) {
      // No catalog record / offline — the one backdrop stays.
    }
  }

  /// The same image provider AuroraImage ends up using for this URL.
  ImageProvider _provider(String url) {
    if (!kIsWeb) return CachedNetworkImageProvider(url);
    final uri = Uri.parse(url);
    return NetworkImage(uri.replace(queryParameters: {...uri.queryParameters, 'app': '1'}).toString());
  }

  void _onTick() {
    if (!widget.active || _ended) return;
    final before = (_active, _settled);
    _elapsed += _tick.inMilliseconds;
    widget.onProgress((_elapsed / _titleMs).clamp(0, 1).toDouble());
    if (_elapsed >= _titleMs) {
      _ended = true;
      widget.onEnded();
      return;
    }
    if ((_active, _settled) != before) setState(() {});
  }

  /// The previous still has finished fading out.
  bool get _settled => _elapsed % _slide.inMilliseconds >= _fade.inMilliseconds;

  int get _active => _slides.isEmpty ? 0 : (_elapsed ~/ _slide.inMilliseconds) % _slides.length;

  @override
  void dispose() {
    _clock?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _entrance, curve: auroraEase);
    final active = _active;
    // The still fading out keeps its zoom until it's gone, then resets.
    final previous = _slides.isEmpty || _settled ? -1 : (active - 1 + _slides.length) % _slides.length;

    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: 1.04, end: 1.0).animate(curved),
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < _slides.length; i++)
                AnimatedOpacity(
                  key: ValueKey(_slides[i]),
                  opacity: i == active ? 1 : 0,
                  duration: _fade,
                  curve: Curves.easeInOut,
                  child: ClipRect(
                    child: AnimatedScale(
                      scale: i == active || i == previous ? 1.08 : 1.0,
                      // Zooms in slowly while up; snaps back once faded out.
                      duration: i == active ? _slide + _fade : Duration.zero,
                      curve: Curves.linear,
                      child: AuroraImage(url: _slides[i]),
                    ),
                  ),
                ),
              // Dims the stills (z-10 on the site).
              IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: 0.45))),
            ],
          ),
        ),
      ),
    );
  }
}
