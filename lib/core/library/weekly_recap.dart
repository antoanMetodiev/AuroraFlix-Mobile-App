import 'dart:math' as math;

import 'watch_log.dart';
import 'watch_progress.dart';

/// "Моята седмица" — a weekly recap of the viewer's own watching (website:
/// lib/weekly-recap.ts, same rules). The watch log (exact seconds played on
/// this device) where it has a title; otherwise how far the viewer got.
class RecapEpisode {
  const RecapEpisode(this.season, this.episode, this.finished, this.percent);
  final int season;
  final int episode;
  final bool finished;
  final int? percent;
}

class RecapTitle {
  RecapTitle({required this.isSeries, required this.tmdbId, required this.title, required this.image, required this.lastAt, required this.firstAt});

  final bool isSeries;
  final String tmdbId;
  String title;
  String? image;
  double seconds = 0;
  final List<RecapEpisode> episodes = [];
  int? percent;
  bool finished = false;
  int lastAt;
  int firstAt;

  String get key => '${isSeries ? 'tv' : 'movie'}:$tmdbId';
}

enum TimeOfDayPart { morning, afternoon, evening, night }

class WeeklyRecap {
  WeeklyRecap._({
    required this.start,
    required this.end,
    required this.totalSeconds,
    required this.exactShare,
    required this.perDay,
    required this.timeOfDay,
    required this.titles,
    required this.nightOwl,
  });

  final DateTime start;
  final DateTime end;
  final double totalSeconds;

  /// 0–1: share of [totalSeconds] measured by the watch log.
  final double exactShare;

  /// Monday … Sunday.
  final List<double> perDay;
  final Map<TimeOfDayPart, double> timeOfDay;

  /// Most watched first.
  final List<RecapTitle> titles;
  final bool nightOwl;

  List<RecapTitle> get movies => titles.where((t) => !t.isSeries).toList();
  List<RecapTitle> get series => titles.where((t) => t.isSeries).toList()
    ..sort((a, b) => b.episodes.length != a.episodes.length ? b.episodes.length - a.episodes.length : b.seconds.compareTo(a.seconds));
  int get activeDays => perDay.where((s) => s > 0).length;
  int get episodesWatched => series.fold(0, (sum, s) => sum + s.episodes.length);
  int get episodesFinished => series.fold(0, (sum, s) => sum + s.episodes.where((e) => e.finished).length);
  int get moviesFinished => movies.where((m) => m.finished).length;
  List<RecapTitle> get inProgress => titles.where((t) => !t.finished).toList()..sort((a, b) => b.lastAt - a.lastAt);
  RecapTitle? get first => titles.isEmpty ? null : (titles.toList()..sort((a, b) => a.firstAt - b.firstAt)).first;
  RecapTitle? get last => titles.isEmpty ? null : (titles.toList()..sort((a, b) => a.firstAt - b.firstAt)).last;
  int? get busiestDay {
    if (!perDay.any((s) => s > 0)) return null;
    final top = perDay.reduce(math.max);
    return perDay.indexOf(top);
  }

  int get streak {
    var best = 0, run = 0;
    for (final s in perDay) {
      run = s > 0 ? run + 1 : 0;
      best = math.max(best, run);
    }
    return best;
  }

  TimeOfDayPart get favoriteTime =>
      TimeOfDayPart.values.reduce((best, part) => (timeOfDay[part] ?? 0) > (timeOfDay[best] ?? 0) ? part : best);
}

/// Monday 00:00 (local time) of the week [weeksAgo] weeks back.
DateTime weekStart([int weeksAgo = 0, DateTime? now]) {
  final today = now ?? DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  return start.subtract(Duration(days: (start.weekday - 1) + weeksAgo * 7));
}

TimeOfDayPart _partFor(int hour) {
  if (hour >= 5 && hour < 12) return TimeOfDayPart.morning;
  if (hour >= 12 && hour < 18) return TimeOfDayPart.afternoon;
  if (hour >= 18 && hour < 23) return TimeOfDayPart.evening;
  return TimeOfDayPart.night;
}

WeeklyRecap weeklyRecap(Map<String, WatchProgress> map, WatchLog log, [int weeksAgo = 0]) {
  final start = weekStart(weeksAgo);
  final end = DateTime(start.year, start.month, start.day + 7);
  final days = [for (var i = 0; i < 7; i++) dayKey(DateTime(start.year, start.month, start.day + i))];

  final logged = <String, double>{};
  final perDay = List<double>.filled(7, 0);
  final timeOfDay = {for (final part in TimeOfDayPart.values) part: 0.0};
  var nightOwl = false;
  for (var i = 0; i < 7; i++) {
    final day = log[days[i]];
    if (day == null) continue;
    (day['t'] ?? {}).forEach((title, seconds) {
      logged[title] = (logged[title] ?? 0) + seconds;
      perDay[i] += seconds;
    });
    (day['h'] ?? {}).forEach((hour, seconds) {
      final h = int.tryParse(hour) ?? 12;
      timeOfDay[_partFor(h)] = timeOfDay[_partFor(h)]! + seconds;
      if (h < 5 && seconds > 60) nightOwl = true;
    });
  }

  final titles = <String, RecapTitle>{};
  final estimated = <String, ({double seconds, List<int> at})>{};
  final from = start.millisecondsSinceEpoch, to = end.millisecondsSinceEpoch;
  map.forEach((key, entry) {
    if (entry.updatedAt < from || entry.updatedAt >= to) return;
    final parts = key.split(':');
    if (parts.length < 2) return;
    final isSeries = parts[0] == 'tv';
    final titleKey = '${parts[0]}:${parts[1]}';
    final seconds = math.max(0.0, entry.duration != null ? math.min(entry.seconds, entry.duration!) : entry.seconds);
    final percent = entry.percent?.round();

    final est = estimated[titleKey] ?? (seconds: 0.0, at: <int>[]);
    estimated[titleKey] = (seconds: est.seconds + seconds, at: [...est.at, entry.updatedAt]);

    final title = titles.putIfAbsent(
      titleKey,
      () => RecapTitle(isSeries: isSeries, tmdbId: parts[1], title: entry.title ?? '', image: entry.image, lastAt: entry.updatedAt, firstAt: entry.updatedAt),
    );
    if (entry.updatedAt >= title.lastAt) {
      title.lastAt = entry.updatedAt;
      if (entry.title != null) title.title = entry.title!;
      if (entry.image != null) title.image = entry.image;
    }
    title.firstAt = math.min(title.firstAt, entry.updatedAt);
    if (isSeries && parts.length > 3) {
      title.episodes.add(RecapEpisode(int.tryParse(parts[2]) ?? 0, int.tryParse(parts[3]) ?? 0, entry.finished, percent));
    } else {
      title.percent = percent;
      title.finished = entry.finished;
    }
  });

  var total = 0.0, exact = 0.0;
  for (final entry in titles.entries) {
    final title = entry.value;
    final fromLog = logged[entry.key];
    if (fromLog != null && fromLog > 0) {
      title.seconds = fromLog;
      exact += fromLog;
    } else {
      final est = estimated[entry.key]!;
      title.seconds = est.seconds;
      final share = est.seconds / est.at.length;
      for (final at in est.at) {
        final date = DateTime.fromMillisecondsSinceEpoch(at);
        perDay[date.weekday - 1] += share;
        timeOfDay[_partFor(date.hour)] = timeOfDay[_partFor(date.hour)]! + share;
        if (date.hour < 5) nightOwl = true;
      }
    }
    total += title.seconds;
    if (title.isSeries) {
      title.episodes.sort((a, b) => a.season != b.season ? a.season - b.season : a.episode - b.episode);
      title.finished = title.episodes.isNotEmpty && title.episodes.every((e) => e.finished);
    }
  }

  final list = titles.values.where((t) => t.title.isNotEmpty).toList()..sort((a, b) => b.seconds.compareTo(a.seconds));
  return WeeklyRecap._(
    start: start,
    end: end,
    totalSeconds: total,
    exactShare: total > 0 ? exact / total : 0,
    perDay: perDay,
    timeOfDay: timeOfDay,
    titles: list,
    nightOwl: nightOwl,
  );
}
