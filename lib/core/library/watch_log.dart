import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Real watch time, for the weekly recap (website: lib/watch-log.ts): how
/// many seconds of each title were actually played, per day and per hour.
/// Between two saves of the same movie / episode, the position moving
/// forward by about as much as the clock did counts as watched; a seek
/// doesn't. Kept on this device, for the last [_logDays] days.
///
/// Shape: `{ "YYYY-MM-DD": { "t": {"movie:<id>": secs}, "h": {"21": secs} } }`
typedef WatchLog = Map<String, Map<String, Map<String, double>>>;

const _key = 'AURORAFLIX-WATCH-LOG';
const _logDays = 70;
const _maxGapMs = 3 * 60 * 1000;

final _lastSave = <String, ({double seconds, int at})>{};

String dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

WatchLog readWatchLog(SharedPreferences prefs) {
  try {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (day, value) => MapEntry(
        day,
        (value as Map<String, dynamic>).map(
          (part, entries) => MapEntry(part, (entries as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()))),
        ),
      ),
    );
  } catch (_) {
    return {};
  }
}

/// [progressKey] is `movie:<id>` or `tv:<id>:<season>:<episode>`.
void recordWatchTime(SharedPreferences prefs, String progressKey, double seconds) {
  if (!seconds.isFinite) return;
  final now = DateTime.now();
  final at = now.millisecondsSinceEpoch;
  final previous = _lastSave[progressKey];
  _lastSave[progressKey] = (seconds: seconds, at: at);
  if (previous == null) return;

  final gapMs = at - previous.at;
  final advanced = seconds - previous.seconds;
  if (gapMs <= 0 || gapMs > _maxGapMs || advanced <= 0 || advanced > gapMs / 1000 + 10) return;

  final log = readWatchLog(prefs);
  final day = log.putIfAbsent(dayKey(now), () => {'t': {}, 'h': {}});
  final parts = progressKey.split(':');
  final titleKey = '${parts[0]}:${parts[1]}';
  final titles = day.putIfAbsent('t', () => {});
  final hours = day.putIfAbsent('h', () => {});
  titles[titleKey] = (titles[titleKey] ?? 0) + advanced;
  hours['${now.hour}'] = (hours['${now.hour}'] ?? 0) + advanced;

  final cutoff = dayKey(now.subtract(const Duration(days: _logDays)));
  log.removeWhere((key, _) => key.compareTo(cutoff) < 0);
  prefs.setString(_key, jsonEncode(log));
}
