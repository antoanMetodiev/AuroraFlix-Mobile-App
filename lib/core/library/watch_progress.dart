import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../i18n/locale.dart';

/// Where the viewer stopped in each movie / episode, kept on this device
/// (website: lib/watch-progress.ts, same keys and rules).
class ProgressTarget {
  const ProgressTarget.movie(this.tmdbId) : season = null, episode = null;
  const ProgressTarget.episode(this.tmdbId, String this.season, String this.episode);

  final String tmdbId;
  final String? season;
  final String? episode;

  bool get isSeries => season != null;

  String get key => isSeries ? 'tv:$tmdbId:$season:$episode' : 'movie:$tmdbId';

  ProgressTarget withEpisode(String season, String episode) => ProgressTarget.episode(tmdbId, season, episode);
}

class WatchProgress {
  const WatchProgress({required this.seconds, required this.duration, required this.finished, required this.updatedAt, this.title, this.image, this.approximate = false});

  final double seconds;
  final double? duration;
  final bool finished;
  final int updatedAt;

  /// What the "continue watching" row shows, as the details screen had it.
  final String? title;
  final String? image;

  /// Counted by us, the player doesn't report its position.
  final bool approximate;

  factory WatchProgress.fromJson(Map<String, dynamic> json) => WatchProgress(
    seconds: (json['seconds'] as num?)?.toDouble() ?? 0,
    duration: (json['duration'] as num?)?.toDouble(),
    finished: json['finished'] == true,
    updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    title: json['title'] as String?,
    image: json['image'] as String?,
    approximate: json['approximate'] == true,
  );

  Map<String, dynamic> toJson() => {'seconds': seconds, 'duration': duration, 'finished': finished, 'updatedAt': updatedAt, 'title': ?title, 'image': ?image, if (approximate) 'approximate': true};

  /// 0-100 for a progress bar, or null when the runtime isn't known.
  double? get percent {
    final total = duration;
    if (total == null || total <= 0) return null;
    return (seconds / total * 100).clamp(0, 100).toDouble();
  }
}

/// One title's most recent position, with the episode it's about.
class TitleProgress {
  const TitleProgress({required this.isSeries, required this.tmdbId, required this.progress, this.season, this.episode});

  final bool isSeries;
  final String tmdbId;
  final WatchProgress progress;
  final String? season;
  final String? episode;
}

const _storageKey = 'AURORAFLIX-WATCH-PROGRESS';
const _maxEntries = 300;

/// Below this it's only a look at the opening, or a player still restoring.
const _minSavedSeconds = 15;

/// Anything shorter is a pre-roll ad reporting its own clock, not the title.
const _minDurationSeconds = 120;

/// Past this share of the runtime only the credits are left.
const _finishedRatio = 0.93;

/// Jump back a little, so the viewer lands back inside the scene.
const _resumeRewindSeconds = 5;

/// The second to start from, or null for "from the beginning".
int? resumeSecondsFrom(Map<String, WatchProgress> map, ProgressTarget target) {
  final saved = map[target.key];
  if (saved == null || saved.finished) return null;
  final seconds = saved.seconds.floor() - _resumeRewindSeconds;
  return seconds < 0 ? 0 : seconds;
}

/// The most recent position in a movie, or in any episode of a series.
TitleProgress? latestProgress(Map<String, WatchProgress> map, {required bool isSeries, required String? tmdbId}) {
  if (tmdbId == null || tmdbId.isEmpty) return null;
  final prefix = '${isSeries ? 'tv' : 'movie'}:$tmdbId';
  TitleProgress? latest;
  map.forEach((key, entry) {
    if (key != prefix && !key.startsWith('$prefix:')) return;
    if (latest != null && latest!.progress.updatedAt >= entry.updatedAt) return;
    final parts = key.split(':');
    latest = TitleProgress(isSeries: isSeries, tmdbId: tmdbId, progress: entry, season: parts.length > 3 ? parts[2] : null, episode: parts.length > 3 ? parts[3] : null);
  });
  return latest;
}

/// One entry per title, newest first: the position it was last left at. A
/// title whose latest position is finished is done (a series opens on its
/// next episode by itself), so it isn't offered.
List<TitleProgress> continueWatching(Map<String, WatchProgress> map) {
  final latest = <String, TitleProgress>{};
  map.forEach((key, entry) {
    final parts = key.split(':');
    if (parts.length < 2) return;
    final titleKey = '${parts[0]}:${parts[1]}';
    final current = latest[titleKey];
    if (current != null && current.progress.updatedAt >= entry.updatedAt) return;
    latest[titleKey] = TitleProgress(isSeries: parts[0] == 'tv', tmdbId: parts[1], progress: entry, season: parts.length > 3 ? parts[2] : null, episode: parts.length > 3 ? parts[3] : null);
  });
  return latest.values.where((entry) => !entry.progress.finished).toList()..sort((a, b) => b.progress.updatedAt.compareTo(a.progress.updatedAt));
}

String formatPlaybackTime(num totalSeconds) {
  final whole = totalSeconds < 0 ? 0 : totalSeconds.floor();
  final hours = whole ~/ 3600;
  final minutes = (whole % 3600) ~/ 60;
  final seconds = (whole % 60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds' : '$minutes:$seconds';
}

/// Whose positions: `known` false until sign-in is known, then the signed-in
/// user's id, or null for this device's.
typedef ProgressAccount = ({bool known, String? userId});

final progressAccountProvider = Provider<ProgressAccount>((ref) {
  final auth = ref.watch(authProvider);
  return (known: auth.isLoaded, userId: auth.isSignedIn ? auth.user?.id : null);
});

/// Coming back to the app refreshes the account's positions, at most this often.
const _reloadAfter = Duration(seconds: 30);

/// Where the viewer stopped (website: lib/watch-progress.ts). Signed out it's
/// kept on the device; signed in it belongs to the account (lumo-user-svc's
/// /watch-progress) and follows it to every device. The two never mix:
/// signing in neither copies the device's positions to the account nor
/// touches them, and signing out shows them again as they were.
class WatchProgressController extends Notifier<Map<String, WatchProgress>> {
  String? _userId;
  bool _ready = false;

  /// Saved while the account's positions were loading: they win over what loads.
  Map<String, WatchProgress> _early = {};

  /// Changes made before sign-in was known, replayed once it is.
  final List<void Function()> _pending = [];
  DateTime _lastLoad = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether the saved positions can be read yet: right away signed out, once
  /// the account's have loaded signed in.
  bool get ready => _ready;

  @override
  Map<String, WatchProgress> build() {
    final account = ref.watch(progressAccountProvider);
    _userId = account.userId;
    _ready = false;
    _early = {};
    if (!account.known) return const {};

    if (_pending.isNotEmpty) {
      final replay = List.of(_pending);
      _pending.clear();
      Future.microtask(() {
        for (final run in replay) {
          run();
        }
      });
    }

    final userId = account.userId;
    if (userId == null) {
      _ready = true;
      return _readLocal();
    }
    final lifecycle = AppLifecycleListener(
      onResume: () {
        if (_userId == userId && DateTime.now().difference(_lastLoad) > _reloadAfter) _load(userId);
      },
    );
    ref.onDispose(lifecycle.dispose);
    Future.microtask(() => _load(userId));
    return const {};
  }

  bool get _signedIn => _userId != null;

  /// Before sign-in is known, a change waits for it.
  void _whenKnown(void Function() run) {
    if (ref.read(progressAccountProvider).known) {
      run();
    } else {
      _pending.add(run);
    }
  }

  Map<String, WatchProgress> _readLocal() {
    final raw = ref.read(sharedPreferencesProvider).getString(_storageKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map<String, dynamic>) entry.key: WatchProgress.fromJson(entry.value as Map<String, dynamic>),
      };
    } catch (_) {
      return const {};
    }
  }

  static Map<String, WatchProgress> _newest(Map<String, WatchProgress> map) {
    final newest = map.entries.toList()..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));
    return Map.fromEntries(newest.take(_maxEntries));
  }

  /// Signed out: the whole map goes back on the device.
  void _writeLocal(Map<String, WatchProgress> next) {
    state = _newest(next);
    ref.read(sharedPreferencesProvider).setString(_storageKey, jsonEncode(state.map((key, value) => MapEntry(key, value.toJson()))));
  }

  Future<void> _load(String userId) async {
    _lastLoad = DateTime.now();
    final data = await ref.read(apiClientProvider).getJson('/watch-progress');
    if (_userId != userId) return;
    if (data == null) {
      // Nothing to resume from, but this screen's own saves still go through.
      if (_ready) return;
      state = _early;
    } else {
      final loaded = <String, WatchProgress>{
        for (final json in ApiClient.unwrapList(data))
          if (json['key'] is String) json['key'] as String: WatchProgress.fromJson(json),
      };
      state = _newest({...loaded, ..._early});
    }
    _early = {};
    _ready = true;
  }

  void _saveToAccount(String key, WatchProgress entry) {
    if (!_ready) _early = {..._early, key: entry};
    state = _newest({...state, key: entry});
    unawaited(ref.read(apiClientProvider).send('PUT', '/watch-progress', body: {'key': key, ...entry.toJson()}));
  }

  void _removeFromAccount(List<String> keys) {
    if (keys.isEmpty) return;
    _early = {..._early}..removeWhere((key, _) => keys.contains(key));
    state = {...state}..removeWhere((key, _) => keys.contains(key));
    final api = ref.read(apiClientProvider);
    // A long series' worth of keys, a URL at a time.
    for (var i = 0; i < keys.length; i += 100) {
      final query = keys.skip(i).take(100).map((key) => 'key=${Uri.encodeQueryComponent(key)}').join('&');
      unawaited(api.send('DELETE', '/watch-progress?$query'));
    }
  }

  void save(ProgressTarget target, double seconds, double? duration, {String? title, String? image, bool approximate = false}) {
    if (!seconds.isFinite || seconds < _minSavedSeconds) return;
    if (duration != null && duration < _minDurationSeconds) return;

    final updatedAt = DateTime.now().millisecondsSinceEpoch;
    _whenKnown(() {
      // Some players say the runtime only once, as they load.
      final knownDuration = duration ?? state[target.key]?.duration;
      final entry = WatchProgress(
        seconds: seconds,
        duration: knownDuration,
        finished: knownDuration != null && seconds / knownDuration >= _finishedRatio,
        updatedAt: updatedAt,
        title: title,
        image: image,
        approximate: approximate,
      );
      if (_signedIn) {
        _saveToAccount(target.key, entry);
      } else {
        _writeLocal({...state, target.key: entry});
      }
    });
  }

  void clear(ProgressTarget target) => _whenKnown(() {
    if (_signedIn) {
      _removeFromAccount([target.key]);
    } else {
      _writeLocal({...state}..remove(target.key));
    }
  });

  /// Takes a title out of "continue watching". Finished episodes stay, so a
  /// series keeps its "Watched" marks and still opens on the next one.
  void dismiss({required bool isSeries, required String tmdbId}) => _whenKnown(() {
    final prefix = '${isSeries ? 'tv' : 'movie'}:$tmdbId';
    final dismissed = [
      for (final MapEntry(:key, :value) in state.entries)
        if (!value.finished && (key == prefix || key.startsWith('$prefix:'))) key,
    ];
    if (_signedIn) {
      _removeFromAccount(dismissed);
    } else {
      _writeLocal({...state}..removeWhere((key, _) => dismissed.contains(key)));
    }
  });
}

final watchProgressProvider = NotifierProvider<WatchProgressController, Map<String, WatchProgress>>(WatchProgressController.new);

/// Whether [watchProgressProvider] can be read yet (see [WatchProgressController.ready]).
final watchProgressReadyProvider = Provider<bool>((ref) {
  ref.watch(watchProgressProvider);
  return ref.read(watchProgressProvider.notifier).ready;
});
