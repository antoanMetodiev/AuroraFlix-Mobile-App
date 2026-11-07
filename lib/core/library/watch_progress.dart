import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  const WatchProgress({
    required this.seconds,
    required this.duration,
    required this.finished,
    required this.updatedAt,
    this.title,
    this.image,
    this.approximate = false,
  });

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

  Map<String, dynamic> toJson() => {
    'seconds': seconds,
    'duration': duration,
    'finished': finished,
    'updatedAt': updatedAt,
    'title': ?title,
    'image': ?image,
    if (approximate) 'approximate': true,
  };

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
    latest = TitleProgress(
      isSeries: isSeries,
      tmdbId: tmdbId,
      progress: entry,
      season: parts.length > 3 ? parts[2] : null,
      episode: parts.length > 3 ? parts[3] : null,
    );
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
    latest[titleKey] = TitleProgress(
      isSeries: parts[0] == 'tv',
      tmdbId: parts[1],
      progress: entry,
      season: parts.length > 3 ? parts[2] : null,
      episode: parts.length > 3 ? parts[3] : null,
    );
  });
  return latest.values.where((entry) => !entry.progress.finished).toList()
    ..sort((a, b) => b.progress.updatedAt.compareTo(a.progress.updatedAt));
}

String formatPlaybackTime(num totalSeconds) {
  final whole = totalSeconds < 0 ? 0 : totalSeconds.floor();
  final hours = whole ~/ 3600;
  final minutes = (whole % 3600) ~/ 60;
  final seconds = (whole % 60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds' : '$minutes:$seconds';
}

class WatchProgressController extends Notifier<Map<String, WatchProgress>> {
  @override
  Map<String, WatchProgress> build() {
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

  void _write(Map<String, WatchProgress> next) {
    final newest = next.entries.toList()..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));
    state = Map.fromEntries(newest.take(_maxEntries));
    ref.read(sharedPreferencesProvider).setString(_storageKey, jsonEncode(state.map((key, value) => MapEntry(key, value.toJson()))));
  }

  void save(ProgressTarget target, double seconds, double? duration, {String? title, String? image, bool approximate = false}) {
    if (!seconds.isFinite || seconds < _minSavedSeconds) return;
    if (duration != null && duration < _minDurationSeconds) return;

    // Some players say the runtime only once, as they load.
    final knownDuration = duration ?? state[target.key]?.duration;
    _write({
      ...state,
      target.key: WatchProgress(
        seconds: seconds,
        duration: knownDuration,
        finished: knownDuration != null && seconds / knownDuration >= _finishedRatio,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        title: title,
        image: image,
        approximate: approximate,
      ),
    });
  }

  void clear(ProgressTarget target) => _write({...state}..remove(target.key));

  /// Takes a title out of "continue watching". Finished episodes stay, so a
  /// series keeps its "Watched" marks and still opens on the next one.
  void dismiss({required bool isSeries, required String tmdbId}) {
    final prefix = '${isSeries ? 'tv' : 'movie'}:$tmdbId';
    _write({...state}..removeWhere((key, entry) => !entry.finished && (key == prefix || key.startsWith('$prefix:'))));
  }
}

final watchProgressProvider = NotifierProvider<WatchProgressController, Map<String, WatchProgress>>(WatchProgressController.new);
