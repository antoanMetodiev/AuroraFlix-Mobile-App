import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/bg_audio.dart';
import '../../core/config.dart';
import '../../core/friends/friends_api.dart';
import '../../core/friends/watching_presence.dart';
import '../../core/i18n/locale.dart';
import '../../core/library/watch_progress.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/embed_frame/embed_frame.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';
import '../../widgets/reveal.dart';
import '../../widgets/video_width.dart';
import 'player_telemetry.dart';
import 'player_urls.dart';

/// Our own Bulgarian subtitles for a movie or one episode, if the subtitles
/// services have them — the website's /api/subtitles/{tmdbId} and
/// /api/subtitles/{tmdbId}/{season}/{episode} routes (they send CORS
/// headers so the players can fetch them from their own origin). Keyed by
/// that path (see [_subtitlePath]).
final _subtitleUrlProvider = FutureProvider.family<String?, String>((ref, path) async {
  final url = '$siteUrl$path';
  try {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    return response.statusCode == 200 ? url : null;
  } catch (_) {
    return null;
  }
});

/// Our own БГ аудио player (core/bg_audio.dart) — not an embed: listed
/// first and selected when the movie has a Bulgarian dub, and ad-free.
const _bgAudioPlayer = 7;

/// The second dub source: filmi2k's embed as it is, after ours when both exist.
const _bgAudioPlayer2 = 8;

/// The players that can be told where to start: by their URL, EmbedMaster (5)
/// by a message, ours (7) by its fragment.
const _resumablePlayers = {1, 2, 3, 4, 5, 6, 7};

/// How often the time is counted for a player that reports nothing.
const _estimateTick = Duration(seconds: 10);

const _vidlinkStartTimeout = Duration(seconds: 15);
const _vidlinkFallback = 1;

/// The movie / episode player (website: PlayerSection): a picker of up to
/// six providers (a captions icon where our Bulgarian subtitles are in),
/// banners for the ad-free and upload-your-subtitles players, and the
/// player itself — poster and a Play button first, then the provider's
/// embed, edge to edge.
class PlayerSection extends ConsumerStatefulWidget {
  const PlayerSection({super.key, required this.videoUrl, required this.title, this.poster});

  final String videoUrl;
  final String title;
  final String? poster;

  @override
  ConsumerState<PlayerSection> createState() => _PlayerSectionState();
}

class _PlayerSectionState extends ConsumerState<PlayerSection> {
  ProviderId _active = 1;
  bool _hasStarted = false;
  bool _frameLoading = true;
  bool _userChangedPlayer = false;

  /// Whether vidsrc2.ru's URL carries our subtitles — decided once, when the
  /// check resolves, and not if it's already playing (that would reload it).
  bool _vidsrcUsesOurSubs = false;
  ProviderId? _autoSwitchedFrom;

  /// The dub's stream wouldn't play (bg-player.html said so) — the БГ аудио
  /// player is dropped for this movie.
  bool _bgAudioFailed = false;

  // VidLink watchdog (see the website): its stream often just spins forever,
  // so if no real playback is reported in time we move to vidsrc2.ru.
  Timer? _vidlinkTimer;
  bool _vidlinkPlaying = false;
  double? _vidlinkLastPosition;
  double _vidlinkPlayed = 0;

  late final _presence = WatchingPresence(ref.read(friendsApiProvider));

  late final WatchProgressController _progress;
  final _frameHandle = EmbedFrameHandle();

  /// Where this run starts. Read only while nothing plays: it goes into the
  /// player's URL, so following the live position would keep reloading it.
  int? _resumeSeconds;
  WatchProgressRecorder? _recorder;
  bool _embedmasterSought = false;

  /// БГ аудио 2 reports nothing, so its position is counted from the viewer's
  /// first touch in it. A pause can't be seen from here: it's only an estimate.
  Timer? _estimateTimer;
  bool _estimateEngaged = false;
  double _estimatedPosition = 0;

  late final _lifecycle = AppLifecycleListener(onHide: () => _recorder?.flush());

  ProgressTarget? _progressTarget(VidsrcRef? vidsrcRef) => switch (vidsrcRef) {
    MovieRef() => ProgressTarget.movie(vidsrcRef.tmdbId),
    TvRef(:final season, :final episode) => ProgressTarget.episode(vidsrcRef.tmdbId, season, episode),
    null => null,
  };

  /// A new run of the active player: recording starts over with it.
  void _startRecording() {
    _endRecording();
    final target = _progressTarget(_ref);
    if (target == null) return;
    _embedmasterSought = false;
    // Kept here: the last save can come just after this screen has gone.
    final progress = _progress;
    final title = widget.title;
    final image = widget.poster;
    _recorder = WatchProgressRecorder(
      target: target,
      provider: _active,
      save: (target, seconds, duration) => progress.save(target, seconds, duration, title: title, image: image),
    );
    if (_active == _bgAudioPlayer2) {
      _estimateEngaged = false;
      _estimatedPosition = (_resumeSeconds ?? 0).toDouble();
      _estimateTimer = Timer.periodic(_estimateTick, (_) {
        if (!_estimateEngaged || WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
        _estimatedPosition += _estimateTick.inSeconds;
        progress.save(target, _estimatedPosition, null, title: title, image: image, approximate: true);
      });
    }
  }

  void _endRecording() {
    _recorder?.flush();
    _recorder = null;
    _estimateTimer?.cancel();
    _estimateTimer = null;
  }

  @override
  void initState() {
    super.initState();
    _progress = ref.read(watchProgressProvider.notifier);
    _lifecycle;
  }

  VidsrcRef? get _ref => VidsrcRef.parse(widget.videoUrl);

  /// What friends see you watching — only once Play was pressed.
  WatchingTarget? _watchingTarget(VidsrcRef? vidsrcRef) {
    if (!_hasStarted || vidsrcRef == null || widget.title.isEmpty) return null;
    return switch (vidsrcRef) {
      MovieRef() => WatchingTarget(tmdbId: vidsrcRef.tmdbId, type: RecordType.movie, title: widget.title),
      TvRef(:final season, :final episode) => WatchingTarget(
        tmdbId: vidsrcRef.tmdbId,
        type: RecordType.series,
        title: widget.title,
        season: int.tryParse(season),
        episode: int.tryParse(episode),
      ),
    };
  }

  @override
  void didUpdateWidget(PlayerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _endRecording();
      _bgAudioFailed = false;
      _hasStarted = false;
      _autoSwitchedFrom = null;
      _frameLoading = true;
      _stopVidlinkWatchdog();
      // Another episode: its subtitles are checked from scratch. When that
      // check already resolved earlier (back to an episode seen before),
      // build()'s listener won't fire again, so apply the answer here.
      _vidsrcUsesOurSubs = false;
      final path = _subtitlePath();
      final cached = path == null ? null : ref.read(_subtitleUrlProvider(path));
      if (path == null) {
        _onSubtitlesResolved(null);
      } else if (cached != null && cached.hasValue) {
        _onSubtitlesResolved(cached.value);
      }
    }
  }

  /// Leaving the page — another tab, or a screen pushed on top (both keep
  /// this one alive offstage) — resets the player to its Play button, so
  /// nothing keeps playing out of sight and "watching" isn't shown to
  /// friends. A fullscreen video also covers the page, but that's still
  /// watching it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStarted && !TickerMode.valuesOf(context).enabled && !isEmbedFullscreen) {
      // Not in the middle of this build: the save rebuilds what shows it.
      final recorder = _recorder;
      _recorder = null;
      _estimateTimer?.cancel();
      _estimateTimer = null;
      Future.microtask(() => recorder?.flush());
      _hasStarted = false;
      _frameLoading = true;
      _stopVidlinkWatchdog();
    }
  }

  @override
  void dispose() {
    _stopVidlinkWatchdog();
    _estimateTimer?.cancel();
    _lifecycle.dispose();
    final recorder = _recorder;
    Future.microtask(() => recorder?.flush());
    _presence.dispose();
    setLeavePageGuard(false);
    super.dispose();
  }

  /// The website route with our subtitles for this movie / episode.
  String? _subtitlePath() {
    final ref = _ref;
    if (ref == null || ref.tmdbId.isEmpty) return null;
    final tmdbId = Uri.encodeComponent(ref.tmdbId);
    return switch (ref) {
      MovieRef() => '/api/subtitles/$tmdbId',
      TvRef(:final season, :final episode) => '/api/subtitles/$tmdbId/$season/$episode',
    };
  }

  /// No subtitles for this episode: EmbedMaster and VidLink only exist with
  /// ours, so a viewer left on one of them goes back to vidsrc2.ru.
  void _onSubtitlesResolved(String? url) {
    if (url == null) {
      if (_active == 4 || _active == 5) _active = 1;
      return;
    }
    if (!_hasStarted || _active != 1) _vidsrcUsesOurSubs = true;
    if (!_hasStarted && !_userChangedPlayer && _active != _bgAudioPlayer && _active != _bgAudioPlayer2) _active = 5;
  }

  /// The movie's dub, once resolved: its player becomes the selected one,
  /// unless the viewer already started or picked another.
  void _onBgAudioResolved(String? master, String? filmi2k) {
    final dub = master != null ? _bgAudioPlayer : (filmi2k != null ? _bgAudioPlayer2 : null);
    if (dub != null && !_hasStarted && !_userChangedPlayer) _active = dub;
    if ((master == null && _active == _bgAudioPlayer) || (filmi2k == null && _active == _bgAudioPlayer2)) _active = dub ?? 1;
  }

  Map<ProviderId, String?> _urls(VidsrcRef? ref, String? subtitleUrl, String? bgAudioMaster, String? filmi2k) {
    final startAt = _resumeSeconds == null || _resumeSeconds == 0 ? null : _resumeSeconds;
    return {
      _bgAudioPlayer: bgAudioMaster == null ? null : bgPlayerUrl(bgAudioMaster, subtitleUrl: subtitleUrl, title: widget.title, startAt: startAt),
      _bgAudioPlayer2: filmi2k,
      1: widget.videoUrl.isEmpty ? null : vidsrcUrl(widget.videoUrl, subtitleUrl: _vidsrcUsesOurSubs ? subtitleUrl : null, startAt: startAt),
      2: ref == null ? null : vidfastUrl(ref, startAt: startAt),
      3: ref == null ? null : cinesrcUrl(ref, startAt: startAt),
      4: ref == null || subtitleUrl == null ? null : vidlinkUrl(ref, subtitleUrl, startAt: startAt),
      5: ref == null || subtitleUrl == null ? null : embedmasterUrl(ref, subtitleUrl),
      6: ref == null ? null : vidsparkUrl(ref, startAt: startAt),
    };
  }

  void _readResume() {
    final target = _progressTarget(_ref);
    _resumeSeconds = target == null ? null : resumeSecondsFrom(ref.read(watchProgressProvider), target);
  }

  void _select(ProviderId provider) => setState(() {
    final wasPlaying = _hasStarted;
    if (wasPlaying) _endRecording();
    _userChangedPlayer = true;
    _autoSwitchedFrom = null;
    _active = provider;
    _frameLoading = true;
    _stopVidlinkWatchdog();
    _readResume();
    if (wasPlaying) _startRecording();
    if (_hasStarted && provider == 4) _startVidlinkWatchdog();
  });

  void _start() => setState(() {
    _hasStarted = true;
    _startRecording();
    if (_active == 4) _startVidlinkWatchdog();
  });

  void _startOver() {
    final target = _progressTarget(_ref);
    if (target != null) _progress.clear(target);
    _resumeSeconds = null;
    _start();
  }

  void _startVidlinkWatchdog() {
    _vidlinkPlaying = false;
    _vidlinkLastPosition = null;
    _vidlinkPlayed = 0;
    _vidlinkTimer?.cancel();
    _vidlinkTimer = Timer(_vidlinkStartTimeout, () {
      if (!mounted || _vidlinkPlaying || _active != 4) return;
      setState(() {
        _autoSwitchedFrom = 4;
        _active = _vidlinkFallback;
        _frameLoading = true;
      });
    });
  }

  void _stopVidlinkWatchdog() {
    _vidlinkTimer?.cancel();
    _vidlinkTimer = null;
  }

  /// A real step forward in VidLink's `PLAYER_EVENT` timeupdates — a jump
  /// is a seek (e.g. restoring progress) and doesn't count as playing.
  void _onFrameMessage(String origin, Object? data) {
    if (_active == _bgAudioPlayer && data is Map && data['type'] == 'BG_AUDIO_FAILED') {
      setState(() {
        _bgAudioFailed = true;
        _active = 1;
        _frameLoading = true;
        _readResume();
        _startRecording();
      });
      return;
    }
    if (_hasStarted) _recorder?.onMessage(origin, data);
    final resume = _resumeSeconds;
    if (_hasStarted && _active == 5 && resume != null && resume > 0 && !_embedmasterSought && isEmbedmasterReady(data)) {
      _embedmasterSought = true;
      _frameHandle.post(embedmasterSeekCommand(resume));
    }
    if (_active != 4 || _vidlinkPlaying || origin != vidlinkOrigin || data is! Map) return;
    final inner = data['data'];
    if (data['type'] != 'PLAYER_EVENT' || inner is! Map || inner['event'] != 'timeupdate') return;
    final position = inner['currentTime'];
    if (position is! num) return;
    final last = _vidlinkLastPosition;
    if (last != null) {
      final step = position - last;
      if (step > 0 && step <= 5) _vidlinkPlayed += step;
    }
    _vidlinkLastPosition = position.toDouble();
    if (_vidlinkPlayed >= 1) {
      _vidlinkPlaying = true;
      _stopVidlinkWatchdog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final vidsrcRef = _ref;
    final subtitlePath = _subtitlePath();

    String? subtitleUrl;
    if (subtitlePath != null) {
      subtitleUrl = ref.watch(_subtitleUrlProvider(subtitlePath)).value;
      ref.listen(_subtitleUrlProvider(subtitlePath), (previous, next) {
        if (next.hasValue) setState(() => _onSubtitlesResolved(next.value));
      });
    }

    String? bgAudioMaster;
    String? filmi2k;
    if (vidsrcRef is MovieRef) {
      final source = ref.watch(bgAudioSourceProvider(vidsrcRef.tmdbId)).value;
      bgAudioMaster = _bgAudioFailed ? null : source?.master;
      filmi2k = source?.filmi2kEmbedUrl;
      ref.listen(bgAudioSourceProvider(vidsrcRef.tmdbId), (previous, next) {
        if (next.hasValue) setState(() => _onBgAudioResolved(_bgAudioFailed ? null : next.value?.master, next.value?.filmi2kEmbedUrl));
      });
    }

    // Signed in, the positions are the account's, once they've loaded.
    ref.watch(watchProgressReadyProvider);
    if (!_hasStarted) _readResume();

    final hasOwn = subtitleUrl != null;
    final embeds = hasOwn ? const [5, 1, 4, 2, 3, 6] : const [1, 2, 3, 6];
    final order = [if (bgAudioMaster != null) _bgAudioPlayer, if (filmi2k != null) _bgAudioPlayer2, ...embeds];
    final urls = _urls(vidsrcRef, subtitleUrl, bgAudioMaster, filmi2k);
    final activeSrc = urls[_active] ?? urls[1];
    final sandboxed = sandboxedPlayers.contains(_active) && urls[_active] != null;
    // Ours plays no ads: no sandbox needed, and nothing to guard against.
    final ownPlayer = _active == _bgAudioPlayer && urls[_bgAudioPlayer] != null;

    setLeavePageGuard(_hasStarted && !sandboxed && !ownPlayer && activeSrc != null);
    _presence
      ..signedIn = ref.watch(authProvider.select((auth) => auth.isSignedIn))
      ..update(_watchingTarget(vidsrcRef));

    return InViewOnce(
      builder: (context, inView) => Reveal(
        visible: inView,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.videoUrl.isNotEmpty && vidsrcRef != null && order.length > 1)
                _PlayerPicker(
                  order: order,
                  active: _active,
                  badge: (provider) => (
                    bgSubtitles: hasOwn && (const {3, 4, 5, 6, _bgAudioPlayer}.contains(provider) || (provider == 1 && _vidsrcUsesOurSubs)),
                    bgAudio: provider == _bgAudioPlayer || provider == _bgAudioPlayer2,
                  ),
                  onSelect: _select,
                ),
              if (widget.videoUrl.isNotEmpty && (sandboxed || ownPlayer)) _NoAdsBanner(key: ValueKey(activeSrc)),
              if (widget.videoUrl.isNotEmpty && _active == 6 && urls[6] != null && subtitleUrl != null)
                _UploadSubtitlesGuide(
                  subtitleUrl: subtitleUrl,
                  uploadButton: 'Upload Subtitles',
                  stepImages: const {2: 'assets/player-guide/vidspark-cc.webp', 3: 'assets/player-guide/vidspark-upload.webp'},
                ),
              if (widget.videoUrl.isNotEmpty && _active == 3 && urls[3] != null && subtitleUrl != null)
                _UploadSubtitlesGuide(
                  subtitleUrl: subtitleUrl,
                  uploadButton: 'Upload Subtitle',
                  stepImages: const {2: 'assets/player-guide/cinesrc-cc.webp'},
                ),
              // On phones the player runs edge to edge, past the padding; on
              // a wide screen (a TV) it's capped so it fits the screen whole.
              SizedBox(
                height: (wideVideoWidth(context) ?? MediaQuery.sizeOf(context).width) * 9 / 16,
                child: OverflowBox(
                  maxWidth: wideVideoWidth(context) ?? MediaQuery.sizeOf(context).width,
                  minWidth: wideVideoWidth(context) ?? MediaQuery.sizeOf(context).width,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 60, offset: const Offset(0, 20))],
                      ),
                      child: widget.videoUrl.isEmpty || activeSrc == null
                          ? Center(
                              child: Text(t('player.pickEpisode'), style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.4))),
                            )
                          : !_hasStarted
                          ? _StartButton(
                              poster: widget.poster,
                              label: t('player.play'),
                              onTap: _start,
                              resumeLabel: _resumeSeconds == null ? null : t('player.resumeFrom', {'time': formatPlaybackTime(_resumeSeconds!)}),
                              startOverLabel: t('player.startOver'),
                              onStartOver: _startOver,
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                Listener(
                                  onPointerDown: (_) => _estimateEngaged = true,
                                  child: EmbedFrame(
                                  key: ValueKey(activeSrc),
                                  url: activeSrc,
                                  sandbox: sandboxed ? playerSandbox : null,
                                  uiScale: _active == 2 ? vidfastUiScale : 1,
                                  noReferrer: _active == _bgAudioPlayer2,
                                  handle: _frameHandle,
                                  onLoaded: () {
                                    if (mounted) setState(() => _frameLoading = false);
                                  },
                                  onMessage: _onFrameMessage,
                                  ),
                                ),
                                if (_frameLoading)
                                  const IgnorePointer(
                                    child: ColoredBox(
                                      color: Colors.black,
                                      child: Center(child: Spinner(size: 44)),
                                    ),
                                  ),
                                if (_resumeSeconds != null && _autoSwitchedFrom == null && !_resumablePlayers.contains(_active))
                                  _TimedNotice(
                                    key: ValueKey('resume:$activeSrc'),
                                    icon: LucideIcons.clock,
                                    iconColor: AppColors.sky,
                                    duration: const Duration(seconds: 10),
                                    title: t('player.resumeManual', {'time': formatPlaybackTime(_resumeSeconds!)}),
                                  ),
                                if (_autoSwitchedFrom != null && _active == _vidlinkFallback)
                                  _TimedNotice(
                                    icon: LucideIcons.monitorPlay,
                                    iconColor: AppColors.sky,
                                    duration: const Duration(seconds: 8),
                                    title: t('player.autoSwitched', {
                                      'from': order.indexOf(_autoSwitchedFrom!) + 1,
                                      'to': order.indexOf(_active) + 1,
                                    }),
                                  ),
                                if ((_active == 5 && urls[5] != null) || (_active == 4 && urls[4] != null))
                                  _TimedNotice(
                                    key: ValueKey('hint:$activeSrc'),
                                    icon: LucideIcons.captions,
                                    iconColor: AppColors.emerald,
                                    duration: const Duration(seconds: 15),
                                    title: t('player.manualSubsTitle'),
                                    body: t(_active == 5 ? 'player.manualSubsSteps' : 'player.manualSubsStepsNoServer'),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Badge = ({bool bgSubtitles, bool bgAudio});

/// "Choose a player" card with one pill per provider (the app shows no
/// "no ads" / subtitle-mode tags on them, unlike the website).
class _PlayerPicker extends ConsumerWidget {
  const _PlayerPicker({required this.order, required this.active, required this.badge, required this.onSelect});

  final List<ProviderId> order;
  final ProviderId active;
  final _Badge Function(ProviderId) badge;
  final ValueChanged<ProviderId> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final columns = order.length == 4 ? 2 : 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
                child: const Icon(LucideIcons.monitorPlay, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('player.choose'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(t('player.hint'), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < order.length; i++)
                    SizedBox(
                      width: width,
                      child: _PlayerPill(
                        label: '${t('player.player')} ${i + 1}',
                        active: order[i] == active,
                        badge: badge(order[i]),
                        onTap: () => onSelect(order[i]),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlayerPill extends ConsumerWidget {
  const _PlayerPill({required this.label, required this.active, required this.badge, required this.onTap});

  final String label;
  final bool active;
  final _Badge badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 38,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active ? Colors.transparent : Colors.white.withValues(alpha: 0.2)),
              boxShadow: active
                  ? [BoxShadow(color: Colors.white.withValues(alpha: 0.55), blurRadius: 24, spreadRadius: -4, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.onWhite : Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                if (badge.bgSubtitles) ...[
                  const SizedBox(width: 6),
                  Icon(LucideIcons.captions, size: 16, color: active ? const Color(0xFF059669) : AppColors.emerald),
                ],
                if (badge.bgAudio) ...[
                  const SizedBox(width: 4),
                  Icon(LucideIcons.audioLines, size: 16, color: active ? const Color(0xFF0284C7) : AppColors.sky),
                ],
              ],
            ),
          ),
        ),
        // "БГ аудио" on the pill's top edge, like the website's tags.
        if (badge.bgAudio)
          Positioned(
            top: -9,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.sky, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  ref.watch(translatorProvider)('player.bgAudio').toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Color(0xFF0A0A0A)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NoAdsBanner extends ConsumerWidget {
  const _NoAdsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.emerald.withValues(alpha: 0.15), AppColors.emerald.withValues(alpha: 0.07), Colors.transparent]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.emerald.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
            ),
            child: const Icon(LucideIcons.shieldCheck, size: 20, color: Color(0xFF6EE7B7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('player.noAds'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFA7F3D0)),
                ),
                Text(t('player.noAdsDetail'), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Step-by-step "load our Bulgarian subtitles into this player's own menu"
/// (CineSrc / VidSpark take no subtitle file from outside).
class _UploadSubtitlesGuide extends ConsumerStatefulWidget {
  const _UploadSubtitlesGuide({required this.subtitleUrl, required this.uploadButton, this.stepImages = const {}});

  final String subtitleUrl;
  final String uploadButton;
  final Map<int, String> stepImages;

  @override
  ConsumerState<_UploadSubtitlesGuide> createState() => _UploadSubtitlesGuideState();
}

class _UploadSubtitlesGuideState extends ConsumerState<_UploadSubtitlesGuide> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    const emerald200 = Color(0xFFA7F3D0);

    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Pressable(
            onTap: () => setState(() => _open = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.captions, size: 16, color: emerald200),
                  const SizedBox(width: 8),
                  Text(
                    t('player.uploadGuideReopen'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: emerald200),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final steps = [
      t('player.uploadGuideStep1'),
      t('player.uploadGuideStep2'),
      t('player.uploadGuideStep3', {'button': widget.uploadButton}),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.emerald.withValues(alpha: 0.2), AppColors.emerald.withValues(alpha: 0.08), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.emerald.withValues(alpha: 0.2)),
                child: const Icon(LucideIcons.captions, size: 20, color: Color(0xFF6EE7B7)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('player.uploadGuideTitle'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    Text(t('player.uploadGuideIntro'), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              Pressable(
                pressedScale: 1,
                onTap: () => setState(() => _open = false),
                child: Icon(LucideIcons.x, size: 18, color: Colors.white.withValues(alpha: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            Container(
              margin: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF059669)),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i], style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
                        if (widget.stepImages[i + 1] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset(widget.stepImages[i + 1]!, width: 288)),
                          ),
                        if (i == 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Pressable(
                              onTap: () => launchUrl(Uri.parse(widget.subtitleUrl), mode: LaunchMode.externalApplication),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(color: AppColors.emerald.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.download, size: 16, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      t('player.uploadSubsDownload'),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Poster, dimmed, with a big glass Play button — the player's idle state.
class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.poster,
    required this.label,
    required this.onTap,
    required this.resumeLabel,
    required this.startOverLabel,
    required this.onStartOver,
  });

  final String? poster;
  final String label;
  final VoidCallback onTap;

  /// "Continue from 47:12", when there's a saved position.
  final String? resumeLabel;
  final String startOverLabel;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _playButton(),
        if (resumeLabel != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xCC000000), Colors.transparent]),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 32, 12, 10),
                child: Row(
                  children: [
                    const Icon(LucideIcons.clock, size: 18, color: AppColors.sky),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        resumeLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Pressable(
                      onTap: onStartOver,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.rotateCcw, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(startOverLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _playButton() {
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        pressedScale: 1,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (poster != null) AuroraImage(url: poster),
            ColoredBox(color: Colors.black.withValues(alpha: 0.5)),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 28, offset: const Offset(0, 8))],
                ),
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Center(child: FaIcon(FontAwesomeIcons.play, size: 24, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small dark card near the top of the player that hides itself after a
/// while (or on ✕) — "switched players" and "turn subtitles on yourself".
class _TimedNotice extends StatefulWidget {
  const _TimedNotice({super.key, required this.icon, required this.iconColor, required this.duration, required this.title, this.body});

  final IconData icon;
  final Color iconColor;
  final Duration duration;
  final String title;
  final String? body;

  @override
  State<_TimedNotice> createState() => _TimedNoticeState();
}

class _TimedNoticeState extends State<_TimedNotice> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Positioned(
      top: 48,
      left: 12,
      right: 12,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 448),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 28, offset: const Offset(0, 8))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, size: 20, color: widget.iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    if (widget.body != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(widget.body!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
                      ),
                  ],
                ),
              ),
              Pressable(
                pressedScale: 1,
                onTap: () => setState(() => _visible = false),
                child: Icon(LucideIcons.x, size: 16, color: Colors.white.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
