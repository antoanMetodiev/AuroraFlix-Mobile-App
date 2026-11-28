import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/catalog_api.dart';
import '../../core/dates.dart';
import '../../core/i18n/locale.dart';
import '../../core/library/watch_log.dart';
import '../../core/library/watch_progress.dart';
import '../../core/library/weekly_recap.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../shell/app_shell.dart';
import '../../widgets/brand_icons.dart';
import '../../widgets/empty_art.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';

const _slideDuration = Duration(seconds: 7);
const _siteUrl = 'https://auroraflix.cloud';

/// Catalog details (poster, genres, rating, year, description) for a recap title.
final _previewProvider = FutureProvider.family<CinemaRecord?, ({RecordType type, String id})>(
  (ref, key) => ref.watch(catalogApiProvider).details(key.type, key.id).catchError((_) => null),
);

/// This week's (or last week's) recap, plus the week before's total for the comparison.
final _recapProvider = Provider.family<({WeeklyRecap recap, double previousTotal})?, int>((ref, weeksAgo) {
  final progress = ref.watch(watchProgressProvider);
  if (!ref.watch(watchProgressReadyProvider)) return null;
  final log = readWatchLog(ref.read(sharedPreferencesProvider));
  return (recap: weeklyRecap(progress, log, weeksAgo), previousTotal: weeklyRecap(progress, log, weeksAgo + 1).totalSeconds);
});

String _formatTime(double seconds, Translator t) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return t('recap.minutes', {'m': minutes});
  return t('recap.hours', {'h': minutes ~/ 60, 'm': minutes % 60});
}

/// Homepage link to the recap — only once this week has something watched
/// (website: RecapPill).
class RecapPill extends ConsumerWidget {
  const RecapPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_recapProvider(0));
    if (data == null || data.recap.titles.isEmpty) return const SizedBox.shrink();
    final t = ref.watch(translatorProvider);
    // Laid out by the home screen: centred, with the seasonal effects switch on the right.
    return Center(
        child: Pressable(
          onTap: () => context.go('/week'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 9, 12, 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [BoxShadow(color: const Color(0xFFA78BFA).withValues(alpha: 0.45), blurRadius: 24, spreadRadius: -8)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.sparkles, size: 15, color: Color(0xFFC4B5FD)),
                const SizedBox(width: 10),
                Text(
                  t('recap.homePill'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground),
                ),
                const SizedBox(width: 6),
                Icon(LucideIcons.chevronRight, size: 15, color: AppColors.fg(0.5)),
              ],
            ),
          ),
        ),
    );
  }
}

/// /week — "Моята седмица" (website: WeeklyRecapView).
class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key});

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  int _weeksAgo = 0;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final locale = intlLocale(ref.watch(localeProvider).name);
    final data = ref.watch(_recapProvider(_weeksAgo));
    final range = data == null
        ? ''
        : '${DateFormat.MMMMd(locale).format(data.recap.start)} – ${DateFormat.MMMMd(locale).format(data.recap.end.subtract(const Duration(days: 1)))}';

    return ColoredBox(
      color: AppColors.background,
      child: ListView(
        padding: shellContentPadding(context).add(const EdgeInsets.fromLTRB(16, 24, 16, 48)),
        children: [
          Text(
            t('recap.title'),
            textAlign: TextAlign.center,
            style: display(const TextStyle(fontSize: 36, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final ago in const [0, 1])
                    Pressable(
                      onTap: () => setState(() => _weeksAgo = ago),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: _weeksAgo == ago ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t(ago == 0 ? 'recap.thisWeek' : 'recap.lastWeek'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _weeksAgo == ago ? AppColors.onWhite : AppColors.fg(0.65),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            range,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.fg(0.5)),
          ),
          const SizedBox(height: 24),
          if (data == null)
            const Loader(minHeight: 320)
          else if (data.recap.titles.isEmpty)
            Column(
              children: [
                const EmptyIllustration(art: EmptyArt.watchlist),
                const SizedBox(height: 16),
                Text(
                  t('recap.emptyTitle'),
                  textAlign: TextAlign.center,
                  style: display(const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                Text(
                  t('recap.emptyDesc'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.fg(0.55)),
                ),
                const SizedBox(height: 20),
                _WhiteButton(icon: LucideIcons.clapperboard, label: t('watchlist.browseMovies'), onTap: () => context.go('/movies')),
              ],
            )
          else
            _RecapStory(key: ValueKey(_weeksAgo), recap: data.recap, previousTotal: data.previousTotal, range: range),
        ],
      ),
    );
  }
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.onWhite),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onWhite),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecapStory extends ConsumerStatefulWidget {
  const _RecapStory({super.key, required this.recap, required this.previousTotal, required this.range});

  final WeeklyRecap recap;
  final double previousTotal;
  final String range;

  @override
  ConsumerState<_RecapStory> createState() => _RecapStoryState();
}

class _RecapStoryState extends ConsumerState<_RecapStory> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _bar = AnimationController(vsync: this, duration: _slideDuration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _go(_index + 1);
    })
    ..forward();
  int _slideCount = 1;

  /// The story card, photographed for "Сподели".
  final _cardKey = GlobalKey();

  /// While true the progress bars are hidden, for a clean picture.
  bool _capturing = false;

  /// The card on screen as a 1080-wide PNG (website: html-to-image).
  Future<Uint8List?> _captureCard() async {
    setState(() => _capturing = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _share(List<String> lines) async {
    // The story waits on this card while it's being shared.
    final wasRunning = _bar.isAnimating;
    _bar.stop();
    final png = _captureCard();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShareSheet(lines: lines, image: png),
    );
    if (mounted && wasRunning) _bar.forward();
  }

  void _go(int index) {
    final next = index.clamp(0, _slideCount - 1);
    setState(() => _index = next);
    if (next < _slideCount - 1) {
      _bar.forward(from: 0);
    } else {
      _bar.value = 1;
    }
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final locale = intlLocale(ref.watch(localeProvider).name);
    final recap = widget.recap;

    CinemaRecord? preview(RecapTitle title) =>
        ref.watch(_previewProvider((type: title.isSeries ? RecordType.series : RecordType.movie, id: title.tmdbId))).value;
    String? posterOf(RecapTitle title) => tmdbImage(preview(title)?.posterImgURL, TmdbSize.w342) ?? title.image;
    String dayName(int i, {bool short = false}) =>
        (short ? DateFormat.E(locale) : DateFormat.EEEE(locale)).format(recap.start.add(Duration(days: i, hours: 12)));

    // Genres weighted by watch time, from the catalog details of the top titles.
    final weights = <String, double>{};
    for (final title in recap.titles.take(10)) {
      for (final genre in preview(title)?.genreList ?? const <String>[]) {
        weights[genre] = (weights[genre] ?? 0) + title.seconds + 1;
      }
    }
    final weightSum = weights.values.fold(0.0, (a, b) => a + b);
    final genres = (weights.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(4)
        .map((e) => (label: t.genre(e.key), share: weightSum > 0 ? (e.value / weightSum * 100).round() : 0))
        .toList();

    final timeText = _formatTime(recap.totalSeconds, t);
    final change = widget.previousTotal > 0 ? ((recap.totalSeconds - widget.previousTotal) / widget.previousTotal * 100).round() : null;
    final changeText = change == null
        ? t('recap.vsNew')
        : change.abs() < 5
        ? t('recap.vsSame')
        : t(change > 0 ? 'recap.vsUp' : 'recap.vsDown', {'p': change.abs()});
    final sourceNote = recap.exactShare >= 0.95
        ? t('recap.exactNote')
        : recap.exactShare > 0
        ? t('recap.mixedNote')
        : t('recap.estimate');
    final top = recap.titles.firstOrNull;
    final topSeries = recap.series.firstOrNull;
    final busiest = recap.busiestDay;
    final maxDay = recap.perDay.reduce(math.max);
    final favorite = recap.favoriteTime;
    final maxPart = recap.timeOfDay.values.reduce(math.max);

    TextStyle big(double size) => display(TextStyle(fontSize: size, fontWeight: FontWeight.w600, height: 1.1, color: Colors.white));
    final muted = TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7));
    final small = TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6));

    final slides = <({String key, String? image, Widget body})>[
      (
        key: 'intro',
        image: top?.image,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.range.toUpperCase(), style: small.copyWith(fontWeight: FontWeight.w600, letterSpacing: 2)),
            const SizedBox(height: 10),
            Text(t('recap.subtitle'), style: big(34)),
            const SizedBox(height: 22),
            SizedBox(
              height: 120,
              child: Stack(
                children: [
                  for (final (i, title) in recap.titles.take(4).indexed)
                    Positioned(
                      left: i * 56.0,
                      child: Transform.rotate(
                        angle: (i - 1.5) * 0.09,
                        child: _Poster(url: posterOf(title), width: 80),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip('⏱ $timeText'),
                _Chip('🎬 ${t('recap.titlesTitle', {'count': recap.titles.length})}'),
                _Chip('📅 ${recap.activeDays}/7'),
              ],
            ),
          ],
        ),
      ),
      (
        key: 'time',
        image: null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('recap.timeTitle'), style: muted.copyWith(fontSize: 16)),
            const SizedBox(height: 4),
            Text(timeText, style: big(44)),
            const SizedBox(height: 8),
            Text(
              changeText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: change != null && change >= 5
                    ? const Color(0xFF6EE7B7)
                    : change != null && change <= -5
                    ? const Color(0xFFFDA4AF)
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(recap.perDay[i] > 0 ? '${(recap.perDay[i] / 60).round()}' : '', style: small.copyWith(fontSize: 10)),
                            const SizedBox(height: 3),
                            Container(
                              height: maxDay > 0 ? math.max(recap.perDay[i] > 0 ? 6.0 : 2.0, recap.perDay[i] / maxDay * 90) : 2,
                              decoration: BoxDecoration(
                                color: i == busiest ? Colors.white : Colors.white.withValues(alpha: 0.35),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(dayName(i, short: true), style: small.copyWith(fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(t('recap.avgPerDay', {'time': _formatTime(recap.activeDays > 0 ? recap.totalSeconds / recap.activeDays : 0, t)}), style: muted),
            if (busiest != null) ...[
              const SizedBox(height: 2),
              Text(t('recap.longestDay', {'day': dayName(busiest), 'time': _formatTime(recap.perDay[busiest], t)}), style: muted),
            ],
            const SizedBox(height: 14),
            Text(sourceNote, style: small.copyWith(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
      ),
      if (top != null)
        (
          key: 'top',
          image: top.image,
          body: Builder(
            builder: (context) {
              final details = preview(top);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t('recap.topTitle'), style: muted.copyWith(fontSize: 16)),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Poster(url: posterOf(top), width: 104),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Pressable(
                              onTap: () => openTitle(context, top.isSeries ? RecordType.series : RecordType.movie, top.tmdbId),
                              child: Text(top.title, style: big(22)),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (details?.year != null) Text('${details!.year}   ', style: small),
                                if (details?.rating != null) ...[
                                  const FaIcon(FontAwesomeIcons.solidStar, size: 10, color: Color(0xFFFCD34D)),
                                  const SizedBox(width: 4),
                                  Text(details!.rating!.toStringAsFixed(1), style: small),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              t('recap.timeSpent', {'time': _formatTime(top.seconds, t)}),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              top.isSeries
                                  ? t('recap.episodesCount', {'count': top.episodes.length})
                                  : top.finished
                                  ? '✓ ${t('recap.finishedBadge')}'
                                  : top.percent != null
                                  ? t('recap.percentWatched', {'p': top.percent!})
                                  : '',
                              style: small,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (details?.description != null && details!.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(details.description!, maxLines: 4, overflow: TextOverflow.ellipsis, style: muted.copyWith(height: 1.5)),
                  ],
                ],
              );
            },
          ),
        ),
      if (topSeries != null)
        (
          key: 'series',
          image: topSeries.image,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('recap.topSeriesTitle'), style: muted.copyWith(fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Poster(url: posterOf(topSeries), width: 60),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(topSeries.title, style: big(22)),
                        const SizedBox(height: 4),
                        Text(t('recap.timeSpent', {'time': _formatTime(topSeries.seconds, t)}), style: small),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                t('recap.episodesFinished', {'done': topSeries.episodes.where((e) => e.finished).length, 'total': topSeries.episodes.length}),
                style: muted,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in topSeries.episodes.take(24))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: e.finished ? Colors.white : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${e.finished ? '✓ ' : ''}S${e.season} E${e.episode}${!e.finished && e.percent != null ? ' · ${e.percent}%' : ''}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: e.finished ? AppColors.onWhite : Colors.white),
                      ),
                    ),
                ],
              ),
              if (recap.series.length > 1) ...[
                const SizedBox(height: 14),
                Text('+ ${recap.series.skip(1).take(3).map((s) => s.title).join(', ')}', style: small),
              ],
            ],
          ),
        ),
      if (recap.movies.isNotEmpty)
        (
          key: 'movies',
          image: null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('recap.moviesTitle'), style: big(28)),
              const SizedBox(height: 14),
              for (final movie in recap.movies.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      _Poster(url: posterOf(movie), width: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            Text(
                              '${movie.finished
                                  ? '✓ ${t('recap.finishedBadge')}'
                                  : movie.percent != null
                                  ? t('recap.percentWatched', {'p': movie.percent!})
                                  : ''} · ${_formatTime(movie.seconds, t)}',
                              style: small.copyWith(fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            _Bar(
                              value: movie.finished ? 100 : (movie.percent ?? 0).toDouble(),
                              max: 100,
                              color: movie.finished ? const Color(0xFF6EE7B7) : Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      if (genres.isNotEmpty)
        (
          key: 'genres',
          image: null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('recap.genresTitle'), style: muted.copyWith(fontSize: 16)),
              const SizedBox(height: 4),
              Text(genres.first.label, style: big(40)),
              const SizedBox(height: 20),
              for (final g in genres)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(g.label, style: muted.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                          ),
                          Text('${g.share}%', style: small),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _Bar(value: g.share.toDouble(), max: genres.first.share.toDouble()),
                    ],
                  ),
                ),
            ],
          ),
        ),
      (
        key: 'when',
        image: null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('recap.whenTitle'), style: muted.copyWith(fontSize: 16)),
            const SizedBox(height: 4),
            Text(t('recap.favoriteTime', {'part': t('recap.${favorite.name}').toLowerCase()}), style: big(32)),
            const SizedBox(height: 18),
            for (final part in TimeOfDayPart.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(t('recap.${part.name}'), style: muted.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                        ),
                        Text((recap.timeOfDay[part] ?? 0) >= 30 ? _formatTime(recap.timeOfDay[part]!, t) : '—', style: small),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _Bar(
                      value: recap.timeOfDay[part] ?? 0,
                      max: maxPart,
                      color: part == favorite ? Colors.white : Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            if (busiest != null) Text('📅 ${t('recap.dayTitle')}: ${dayName(busiest)}', style: muted),
            if (recap.streak > 1) ...[
              const SizedBox(height: 4),
              Text('🔥 ${t('recap.streak', {'n': recap.streak})}', style: muted),
            ],
            if (recap.nightOwl) ...[const SizedBox(height: 4), Text(t('recap.nightOwl'), style: muted)],
          ],
        ),
      ),
      if (recap.inProgress.isNotEmpty)
        (
          key: 'continue',
          image: null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('recap.continueTitle'), style: big(28)),
              const SizedBox(height: 14),
              for (final title in recap.inProgress.take(4))
                Builder(
                  builder: (context) {
                    final lastEpisode = title.episodes.lastOrNull;
                    final percent = title.isSeries ? lastEpisode?.percent : title.percent;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          _Poster(url: posterOf(title), width: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                                Text(
                                  '${title.isSeries && lastEpisode != null ? 'S${lastEpisode.season} E${lastEpisode.episode} · ' : ''}${percent != null ? t('recap.percentLeft', {'p': 100 - percent}) : ''}',
                                  style: small.copyWith(fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                _Bar(value: (percent ?? 0).toDouble(), max: 100),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Pressable(
                            onTap: () => openTitle(context, title.isSeries ? RecordType.series : RecordType.movie, title.tmdbId, watch: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                              child: Text(
                                t('recap.continue'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onWhite),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      (
        key: 'summary',
        image: recap.last?.image,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('recap.summary'), style: big(32)),
            const SizedBox(height: 4),
            Text(widget.range, style: small),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.3,
              children: [
                _Stat(timeText, t('recap.statTime')),
                _Stat('${recap.titles.length}', t('recap.statTitles')),
                _Stat('${recap.movies.length}', t('recap.statMovies')),
                _Stat('${recap.episodesWatched}', t('recap.statEpisodes')),
                _Stat('${recap.moviesFinished + recap.episodesFinished}', t('recap.statFinished')),
                _Stat('${recap.activeDays}/7', t('recap.statDays')),
              ],
            ),
            if (genres.isNotEmpty) ...[const SizedBox(height: 14), Text('🎭 ${genres.take(2).map((g) => g.label).join(' · ')}', style: muted)],
            if (recap.first != null && recap.last != null && recap.first != recap.last) ...[
              const SizedBox(height: 6),
              Text('${t('recap.firstLast')} „${recap.first!.title}“, ${t('recap.endedWith')} „${recap.last!.title}“.', style: small),
            ],
          ],
        ),
      ),
    ];
    _slideCount = slides.length;
    final slide = slides[math.min(_index, slides.length - 1)];

    /// The message for the card on screen (website: shareLines).
    List<String> shareLines(String key) {
      final header = '🎬 ${t('recap.shareHeader')} (${widget.range})';
      String list(List<RecapTitle> titles) => titles.take(4).map((title) => title.title).join(', ');
      final days = busiest != null
          ? [
              t('recap.shareDaysLine', {'n': recap.activeDays, 'day': dayName(busiest)}),
            ]
          : <String>[];
      switch (key) {
        case 'time':
          return [
            header,
            t('recap.shareTimeLine', {'time': timeText}),
            ...days,
            if (change != null && change.abs() >= 5) changeText,
          ];
        case 'top':
          return [
            header,
            if (top != null) t('recap.shareTopLine', {'title': top.title, 'time': _formatTime(top.seconds, t)}),
          ];
        case 'series':
          return [
            header,
            if (topSeries != null) t('recap.shareSeriesLine', {'title': topSeries.title, 'count': topSeries.episodes.length}),
          ];
        case 'movies':
          return [
            header,
            t('recap.shareMoviesLine', {'list': list(recap.movies)}),
          ];
        case 'genres':
          return [
            header,
            t('recap.shareGenresLine', {'list': genres.map((g) => '${g.label} ${g.share}%').join(', ')}),
          ];
        case 'when':
          return [
            header,
            t('recap.shareWhenLine', {'part': t('recap.${favorite.name}').toLowerCase()}),
            ...days,
            if (recap.streak > 1) '🔥 ${t('recap.streak', {'n': recap.streak})}',
          ];
        case 'continue':
          return [
            header,
            t('recap.shareContinueLine', {'list': list(recap.inProgress)}),
          ];
        default:
          return [
            header,
            t('recap.shareTimeLine', {'time': timeText}),
            '🍿 ${t('recap.titlesTitle', {'count': recap.titles.length})} (${t('nav.movies')}: ${recap.movies.length} · ${t('sections.episodes')}: ${recap.episodesWatched})',
            if (top != null) t('recap.shareTopLine', {'title': top.title, 'time': _formatTime(top.seconds, t)}),
            if (genres.isNotEmpty) t('recap.shareGenresLine', {'list': genres.take(2).map((g) => g.label).join(', ')}),
          ];
      }
    }

    final isLast = _index >= slides.length - 1;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 9 / 16,
              child: RepaintBoundary(
                key: _cardKey,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0xFF171717)),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: KeyedSubtree(
                          key: ValueKey('bg-${slide.key}'),
                          child: slide.image != null
                              ? Opacity(
                                  opacity: 0.45,
                                  child: ImageFiltered(
                                    imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                                    child: Transform.scale(scale: 1.25, child: AuroraImage(url: slide.image)),
                                  ),
                                )
                              : const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: Alignment(-0.4, -0.6),
                                      radius: 1.2,
                                      colors: [Color(0x59A78BFA), Color(0x0038BDF8), Colors.transparent],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x66000000), Color(0x80000000), Color(0xD9000000)],
                          ),
                        ),
                      ),
                      // Tap zones: left quarter back, right quarter forward.
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _go(_index - 1)),
                          ),
                          const Expanded(flex: 2, child: SizedBox()),
                          Expanded(
                            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _go(_index + 1)),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 450),
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                                  child: child,
                                ),
                              ),
                              child: KeyedSubtree(
                                key: ValueKey(slide.key),
                                child: SizedBox(width: double.infinity, child: slide.body),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // The site's mark in the corner — it travels with the shared picture.
                      Positioned(
                        right: 20,
                        bottom: 16,
                        child: IgnorePointer(
                          child: Text(
                            'AuroraFlix · auroraflix.cloud',
                            style: display(
                              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: Colors.white.withValues(alpha: 0.45)),
                            ),
                          ),
                        ),
                      ),
                      // Story progress bars (left out of the shared picture).
                      if (!_capturing)
                        Positioned(
                          left: 16,
                          right: 16,
                          top: 16,
                          child: AnimatedBuilder(
                            animation: _bar,
                            builder: (context, _) => Row(
                              children: [
                                for (var i = 0; i < slides.length; i++)
                                  Expanded(
                                    child: Container(
                                      height: 3,
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(9)),
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: i < _index ? 1 : (i == _index ? (isLast ? 1 : _bar.value) : 0),
                                        child: Container(
                                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _RoundButton(icon: LucideIcons.chevronLeft, onTap: () => _go(_index - 1)),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${_index + 1}/${slides.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.fg(0.5)),
                  ),
                ),
                _RoundButton(icon: LucideIcons.chevronRight, onTap: () => _go(_index + 1)),
                const Spacer(),
                _WhiteButton(icon: LucideIcons.send, label: t('recap.share'), onTap: () => _share(shareLines(slide.key))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Icon(icon, size: 18, color: AppColors.fg(0.75)),
    ),
  );
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.width});

  final String? url;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * 1.5,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6))],
    ),
    clipBehavior: Clip.antiAlias,
    child: url == null ? null : AuroraImage(url: url),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          child: Text(
            value,
            style: display(const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
        ),
      ],
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.max, this.color = Colors.white});

  final double value;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 6,
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: max > 0 && value > 0 ? math.max(0.03, value / max).clamp(0, 1).toDouble() : 0,
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
      ),
    ),
  );
}

/// "Сподели" for the card on screen (website: RecapShareSheet): a picture of
/// exactly that card and a message written for it, then Instagram /
/// Facebook / WhatsApp / Telegram / Reddit, or copy the text.
///
/// Every network gets the picture through the system share sheet (with the
/// message, except Instagram, which takes pictures only) — the only way to
/// hand another app an image. If the picture couldn't be made, the chat
/// networks fall back to their text share links.
class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.lines, required this.image});

  final List<String> lines;
  final Future<Uint8List?> image;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  Uint8List? _png;
  bool _ready = false;
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    widget.image.then((png) {
      if (mounted) setState(() => (_png = png, _ready = true));
    });
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  String _text(Translator t) => [...widget.lines, '', '${t('recap.shareCta')} $_siteUrl'].join('\n');

  Future<void> _shareTo(ShareNetwork network, Translator t) async {
    final text = _text(t);
    final png = _png;
    if (png != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(png, mimeType: 'image/png', name: 'auroraflix-week.png')],
          fileNameOverrides: const ['auroraflix-week.png'],
          text: network == ShareNetwork.instagram ? null : text,
        ),
      );
      return;
    }
    final encoded = Uri.encodeComponent(text);
    final site = Uri.encodeComponent(_siteUrl);
    final url = switch (network) {
      ShareNetwork.instagram => 'https://www.instagram.com/',
      ShareNetwork.facebook => 'https://www.facebook.com/sharer/sharer.php?u=$site&quote=$encoded',
      ShareNetwork.whatsapp => 'https://wa.me/?text=$encoded',
      ShareNetwork.telegram => 'https://t.me/share/url?url=$site&text=${Uri.encodeComponent(widget.lines.join('\n'))}',
      ShareNetwork.reddit => 'https://www.reddit.com/submit?url=$site&title=${Uri.encodeComponent(widget.lines.firstOrNull ?? 'AuroraFlix')}',
    };
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
  }

  Future<void> _copy(Translator t) async {
    await Clipboard.setData(ClipboardData(text: _text(t)));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final text = _text(t);

    return Container(
      margin: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 40),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(9)),
              ),
            ),
            const SizedBox(height: 16),
            Text(t('recap.shareThisCard'), style: display(const TextStyle(fontSize: 24, fontWeight: FontWeight.w600))),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The picture that will be sent.
                Container(
                  width: 104,
                  height: 104 * 16 / 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFF171717),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _png != null
                      ? Image.memory(_png!, fit: BoxFit.cover)
                      : Center(
                          child: _ready
                              ? Text('—', style: TextStyle(color: AppColors.fg(0.4)))
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Spinner(size: 22),
                                    const SizedBox(height: 8),
                                    Text(
                                      t('recap.preparing'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 10, color: AppColors.fg(0.5)),
                                    ),
                                  ],
                                ),
                        ),
                ),
                const SizedBox(width: 14),
                // The message that goes with it, as the other person will see it.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('recap.shareWillSend'), style: TextStyle(fontSize: 12, color: AppColors.fg(0.55))),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B3B2E),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(4),
                          ),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: SelectableText(text, style: const TextStyle(fontSize: 13, height: 1.45, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final network in ShareNetwork.values)
                  Pressable(
                    onTap: () => _shareTo(network, t),
                    child: Column(
                      children: [
                        NetworkTile(network: network, size: 54),
                        const SizedBox(height: 8),
                        Text(
                          networkLabels[network]!,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.fg(0.75)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Pressable(
              onTap: () => _copy(t),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(color: _copied ? const Color(0xFF6EE7B7) : Colors.white, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_copied ? LucideIcons.check : LucideIcons.download, size: 16, color: AppColors.onWhite),
                    const SizedBox(width: 8),
                    Text(
                      _copied ? t('recap.copied') : t('recap.copyText'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onWhite),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
