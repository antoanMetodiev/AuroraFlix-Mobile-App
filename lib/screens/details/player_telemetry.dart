import '../../core/library/watch_progress.dart';

// What each player posts to its parent page about playback (website:
// lib/player-telemetry.ts, captured from the players themselves). Providers:
// 1 vidsrc2.ru, 2 VidFast, 3 CineSrc, 4 VidLink, 5 EmbedMaster, 6 VidSpark,
// 7 our own БГ аудио page. The second БГ аудио source (8) posts nothing.

const _origins = {
  1: 'https://vidsrc2.ru',
  2: 'https://vidfast.vc',
  3: 'https://cinesrc.st',
  4: 'https://vidlink.pro',
  6: 'https://vidspark.to',
};

const _embedmasterSource = 'embedmaster_player';

class ProgressUpdate {
  const ProgressUpdate({this.currentTime, this.duration, this.playing, this.season, this.episode});

  final double? currentTime;
  final double? duration;

  /// Said outright by some players; the others only stop moving their time.
  final bool? playing;
  final String? season;
  final String? episode;
}

double? _number(Object? value) => value is num && value.isFinite ? value.toDouble() : null;

String? _id(Object? value) {
  if (value is! num && value is! String) return null;
  final text = value is num ? value.toInt().toString() : value as String;
  return int.tryParse(text) == null ? null : text;
}

/// The position (and, when the provider says, the episode) in one message.
ProgressUpdate? extractProgress(int provider, String origin, Object? data) {
  if (data is! Map) return null;

  // embedmaster.link redirects to a player domain of theirs that may change,
  // and 7 is our own page: both are told apart by their own marker.
  if (provider == 5) {
    if (data['source'] != _embedmasterSource) return null;
    final value = _number(data['info']);
    return switch (data['event']) {
      'duration' => ProgressUpdate(duration: value),
      'time' || 'seek' => ProgressUpdate(currentTime: value),
      _ => null,
    };
  }
  if (provider == 7) {
    if (data['type'] != 'BG_AUDIO_PROGRESS') return null;
    return ProgressUpdate(currentTime: _number(data['currentTime']), duration: _number(data['duration']));
  }

  if (origin != _origins[provider]) return null;
  final inner = data['data'];
  final fields = inner is Map ? inner : data;
  final season = _id(fields['season']);
  final episode = _id(fields['episode']);
  final bothIds = season != null && episode != null;

  switch (provider) {
    case 1:
      if (data['type'] != 'PLAYER_EVENT' || inner is! Map) return null;
      final status = inner['player_status'];
      return ProgressUpdate(
        currentTime: _number(inner['player_progress']),
        duration: _number(inner['player_duration']),
        playing: status is String ? status == 'playing' : null,
      );
    case 2 || 4:
      if (data['type'] != 'PLAYER_EVENT' || inner is! Map) return null;
      return ProgressUpdate(
        currentTime: _number(inner['currentTime']),
        duration: _number(inner['duration']),
        playing: inner['playing'] is bool ? inner['playing'] as bool : null,
        season: bothIds ? season : null,
        episode: bothIds ? episode : null,
      );
    case 3:
      final type = data['type'];
      if (type is! String || !type.startsWith('cinesrc:')) return null;
      return ProgressUpdate(
        // A next-episode message's time, if any, belongs to the episode it left.
        currentTime: type == 'cinesrc:nextepisode' ? null : _number(data['currentTime']),
        duration: type == 'cinesrc:nextepisode' ? null : _number(data['duration']),
        playing: switch (type) {
          'cinesrc:play' => true,
          'cinesrc:pause' => false,
          _ => null,
        },
        season: bothIds ? season : null,
        episode: bothIds ? episode : null,
      );
    case 6:
      if (data['source'] != 'vidspark-player') return null;
      return ProgressUpdate(
        currentTime: _number(data['currentTime']),
        duration: _number(data['duration']),
        season: bothIds ? season : null,
        episode: bothIds ? episode : null,
      );
  }
  return null;
}

/// EmbedMaster has told us it's ready for a seek: it knows the runtime.
bool isEmbedmasterReady(Object? data) => data is Map && data['source'] == _embedmasterSource && data['event'] == 'duration';

/// The message EmbedMaster's player takes to jump to a position, in seconds.
Map<String, Object> embedmasterSeekCommand(int seconds) => {'source': 'embedmaster_player_command', 'command': 'seek', 'value': seconds};

const _saveEvery = Duration(seconds: 10);

/// A bigger runtime change on a series means the player moved to another episode.
const _episodeDurationTolerance = 120;

/// Saves the position the active player reports (website:
/// useWatchProgressRecorder). One recorder per run of a player.
class WatchProgressRecorder {
  WatchProgressRecorder({required ProgressTarget target, required this.provider, required this.save}) : _current = target;

  final int provider;
  final void Function(ProgressTarget target, double seconds, double? duration) save;

  ProgressTarget _current;
  double? _duration;
  double? _lockedDuration;
  bool _lost = false;
  double? _pending;
  DateTime? _lastSave;

  void onMessage(String origin, Object? data) {
    final update = extractProgress(provider, origin, data);
    if (update == null) return;

    // VidFast and CineSrc can advance to the next episode inside the player.
    final season = update.season;
    final episode = update.episode;
    if (_current.isSeries && season != null && episode != null && (season != _current.season || episode != _current.episode)) {
      flush();
      _current = _current.withEpisode(season, episode);
      _duration = null;
      _lockedDuration = null;
      _lost = false;
    }

    final duration = update.duration;
    if (duration != null) {
      _duration = duration;
      // Without an episode number in the messages, a different runtime is the
      // only sign of a new episode. Better to stop than to save its position
      // under the previous one.
      if (_current.isSeries && duration >= 120) {
        final locked = _lockedDuration;
        if (locked == null) {
          _lockedDuration = duration;
        } else if ((duration - locked).abs() > _episodeDurationTolerance) {
          _lost = true;
          _pending = null;
        }
      }
    }

    final currentTime = update.currentTime;
    if (_lost || currentTime == null) return;

    _pending = currentTime;
    final last = _lastSave;
    if (last == null || DateTime.now().difference(last) >= _saveEvery) flush();
  }

  void flush() {
    final pending = _pending;
    if (pending == null) return;
    save(_current, pending, _duration);
    _pending = null;
    _lastSave = DateTime.now();
  }
}
