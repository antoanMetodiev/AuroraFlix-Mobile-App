import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/fade_in_image.dart';

String? _youTubeId(String? url) => RegExp(r'(?:youtu\.be/|youtube\.com/watch\?v=)([\w-]+)').firstMatch(url ?? '')?.group(1);

/// How often the trailer's playback position is reported to the parent.
const _progressPoll = Duration(milliseconds: 250);

/// Once playback starts, how long before the video replaces the backdrop —
/// the website's 1200ms reveal delay, which hides YouTube's own start-up flash.
const _revealDelay = Duration(milliseconds: 1200);

/// The hero's moving background (website: HeroBackground): the title's
/// backdrop first, then — once its YouTube trailer is actually playing,
/// muted — the trailer, cropped to cover the whole hero. Remounted per title
/// by the parent, so the fade/zoom entrance plays on every switch.
class HeroBackground extends StatefulWidget {
  const HeroBackground({
    super.key,
    required this.record,
    required this.muted,
    required this.onEnded,
    required this.onReady,
    required this.onProgress,
    this.showVideo = true,
  });

  final CinemaRecord record;
  final bool muted;
  final VoidCallback onEnded;

  /// The player is up and showing — the parent's mute button stays disabled
  /// until then.
  final VoidCallback onReady;

  /// 0–1 share of the trailer played so far.
  final ValueChanged<double> onProgress;

  /// False while the home screen isn't on screen (another tab, a details
  /// page on top) — just the backdrop then, no trailer playing unseen.
  final bool showVideo;

  @override
  State<HeroBackground> createState() => _HeroBackgroundState();
}

class _HeroBackgroundState extends State<HeroBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  YoutubePlayerController? _player;
  StreamSubscription<YoutubePlayerValue>? _subscription;
  Timer? _revealTimer;
  Timer? _progressTimer;
  bool _videoReady = false;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    final videoId = _youTubeId(widget.record.trailerVideoURL);
    if (videoId == null || !widget.showVideo) return;

    final player = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        mute: true,
        showControls: false,
        showFullscreenButton: false,
        enableCaption: false,
        showVideoAnnotations: false,
        strictRelatedVideos: true,
        playsInline: true,
        pointerEvents: PointerEvents.none,
      ),
    );
    _player = player;
    _subscription = player.stream.listen(_onPlayerValue);
    // On Android / iOS the package's YoutubePlayer widget draws its WebView
    // in an overlay above the whole app (it covered the screen and took the
    // scrolling) — so there we load the player ourselves and show its
    // WebView in place, cropped like on the web.
    if (!kIsWeb) player.initWithParams(params: player.params);
  }

  void _onPlayerValue(YoutubePlayerValue value) {
    switch (value.playerState) {
      case PlayerState.playing:
        _onPlaying();
      case PlayerState.ended:
        _onEnded();
      default:
        break;
    }
  }

  void _onPlaying() {
    if (_revealTimer != null) return;
    _revealTimer = Timer(_revealDelay, () {
      if (!mounted) return;
      setState(() => _videoReady = true);
      _applyMute();
      widget.onReady();
      if (_player != null) _progressTimer = Timer.periodic(_progressPoll, (_) => _reportProgress());
    });
  }

  void _onEnded() {
    if (_ended) return;
    _ended = true;
    widget.onEnded();
  }

  Future<void> _reportProgress() async {
    final player = _player;
    if (player == null) return;
    try {
      final duration = await player.duration;
      final current = await player.currentTime;
      if (mounted && duration > 0) widget.onProgress((current / duration).clamp(0, 1).toDouble());
    } catch (_) {
      // The player can disappear mid-call when the title switches.
    }
  }

  void _applyMute() {
    final player = _player;
    if (player == null || !_videoReady) return;
    if (widget.muted) {
      player.mute();
    } else {
      player.unMute();
      // Some mobile browsers pause an autoplayed-muted video on unMute()
      // instead of just unmuting it — nudge it back into play.
      player.playVideo();
    }
  }

  @override
  void didUpdateWidget(HeroBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.muted != widget.muted) _applyMute();
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _progressTimer?.cancel();
    _subscription?.cancel();
    _player?.close();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _entrance, curve: auroraEase);
    final player = _player;

    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: 1.04, end: 1.0).animate(curved),
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The trailer sits underneath and is always painted: a platform
              // view at opacity 0 is never created on the web, so it could
              // never start. The backdrop covers it until it plays.
              if (player != null)
                IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Cover: as wide as needed for a 16:9 frame to fill
                      // the whole hero, cropped at the sides.
                      final width = constraints.maxWidth > constraints.maxHeight * 16 / 9
                          ? constraints.maxWidth
                          : constraints.maxHeight * 16 / 9;
                      return ClipRect(
                        child: OverflowBox(
                          maxWidth: width,
                          maxHeight: width * 9 / 16,
                          child: SizedBox(
                            width: width,
                            height: width * 9 / 16,
                            child: kIsWeb
                                ? YoutubePlayer(
                                    controller: player,
                                    aspectRatio: 16 / 9,
                                    enableFullScreenOnVerticalDrag: false,
                                    autoFullScreen: false,
                                    backgroundColor: Colors.black,
                                  )
                                : WebViewWidget(controller: player.webViewController),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              AnimatedOpacity(
                opacity: _videoReady ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: ColoredBox(
                  color: Colors.black,
                  child: AuroraImage(url: tmdbImage(widget.record.backgroundImgURL, TmdbSize.w1280)),
                ),
              ),
              // Dims the backdrop and the trailer alike (z-10 on the site).
              IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ),
    );
  }
}
