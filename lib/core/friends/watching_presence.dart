import 'dart:async';

import 'package:flutter/widgets.dart';

import 'friends_api.dart';

const _heartbeat = Duration(seconds: 5);

/// Tells friends what you're playing (website: useWatchingPresence): once
/// playback starts, `PUT /watching` right away and every 5s while the app is
/// in the foreground; cleared when it goes to the background, when the
/// player stops or leaves.
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

  /// The title playing now, or null when nothing is.
  void update(WatchingTarget? target) {
    if (target == _target) return;
    final wasWatching = _target != null;
    _target = target;
    _timer?.cancel();
    if (target == null) {
      if (wasWatching) _clear();
      return;
    }
    _push();
    _timer = Timer.periodic(_heartbeat, (_) => _push());
  }

  void _push() {
    final target = _target;
    if (target != null && !_hidden && signedIn) _api.setWatching(target);
  }

  void _clear() {
    if (signedIn) _api.clearWatching();
  }

  void dispose() {
    _lifecycle.dispose();
    update(null);
  }
}
