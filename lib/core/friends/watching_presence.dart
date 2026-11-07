import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../models/models.dart';
import 'friends_api.dart';

const _heartbeat = Duration(seconds: 5);

/// A player that stops moving its position this long is taken as paused.
const _stalled = Duration(seconds: 8);

/// Tells friends what you're playing (website: useWatchingPresence): once
/// playback starts, `PUT /watching` right away and every 5s while the app is
/// in the foreground; cleared when it goes to the background, when the
/// player stops or leaves. With a player that reports its position, friends
/// also see where in it you are and whether you've paused.
class WatchingPresence {
  WatchingPresence(this._api) {
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _hidden = true;
        if (_target != null) _clear();
      },
      onShow: () {
        _hidden = false;
        _push();
      },
    );
  }

  final FriendsApi _api;

  /// Kept current by the owner; signed out, nothing is sent.
  bool signedIn = false;

  late final AppLifecycleListener _lifecycle;
  WatchingTarget? _target;
  Timer? _timer;
  bool _hidden = false;

  int? _season;
  int? _episode;
  double? _position;
  double? _duration;
  DateTime _lastAdvance = DateTime.fromMillisecondsSinceEpoch(0);
  bool _saidPaused = false;
  DateTime _saidPausedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool? _lastSentPaused;

  /// The title playing now, or null when nothing is.
  void update(WatchingTarget? target) {
    if (target == _target) return;
    final wasWatching = _target != null;
    _target = target;
    _timer?.cancel();
    _season = null;
    _episode = null;
    _position = null;
    _duration = null;
    _saidPaused = false;
    if (target == null) {
      if (wasWatching) _clear();
      return;
    }
    _push();
    _timer = Timer.periodic(_heartbeat, (_) => _push());
  }

  /// What the player reported, from its own messages (see extractProgress).
  void onPlayback({double? currentTime, double? duration, bool? playing, String? season, String? episode}) {
    final target = _target;
    if (target == null) return;

    // VidFast and CineSrc can move on to the next episode inside the player.
    final nextSeason = int.tryParse(season ?? '');
    final nextEpisode = int.tryParse(episode ?? '');
    if (target.type == RecordType.series &&
        nextSeason != null &&
        nextEpisode != null &&
        (nextSeason != (_season ?? target.season) || nextEpisode != (_episode ?? target.episode))) {
      _season = nextSeason;
      _episode = nextEpisode;
      _position = null;
      _duration = null;
    }
    if (duration != null && duration > 0) _duration = duration;
    if (currentTime != null) {
      final previous = _position;
      if (previous == null || currentTime > previous) _lastAdvance = DateTime.now();
      _position = currentTime;
    }
    if (playing != null) {
      _saidPaused = !playing;
      _saidPausedAt = DateTime.now();
    }

    // A pause or a resume is worth telling friends now, not at the next beat.
    if (_position != null && _paused != _lastSentPaused) _push();
  }

  bool? get _paused {
    if (_position == null) return null;
    if (_saidPaused && !_saidPausedAt.isBefore(_lastAdvance)) return true;
    return DateTime.now().difference(_lastAdvance) > _stalled;
  }

  void _push() {
    final target = _target;
    if (target == null || _hidden || !signedIn) return;
    _lastSentPaused = _paused;
    _api.setWatching(
      target.withPlayback(season: _season, episode: _episode, position: _position, duration: _duration, paused: _lastSentPaused),
    );
  }

  void _clear() {
    if (signedIn) _api.clearWatching();
  }

  void dispose() {
    _lifecycle.dispose();
    update(null);
  }
}
