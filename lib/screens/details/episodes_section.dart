import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/catalog_api.dart';
import '../../core/dates.dart';
import '../../core/i18n/locale.dart';
import '../../core/library/watch_progress.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/loader.dart';
import '../../widgets/modern_select.dart';
import '../../widgets/pressable.dart';
import '../../widgets/reveal.dart';
import '../../widgets/section_heading.dart';

/// Episodes ordered by season, then episode number (website: orderEpisodes).
List<Episode> orderEpisodes(List<Episode> episodes) => [...episodes]
  ..sort((a, b) {
    final season = (int.tryParse(a.season ?? '') ?? 0).compareTo(int.tryParse(b.season ?? '') ?? 0);
    return season != 0 ? season : (int.tryParse(a.episodeNumber ?? '') ?? 0).compareTo(int.tryParse(b.episodeNumber ?? '') ?? 0);
  });

const _cooldown = Duration(minutes: 1);
const _cooldownKey = 'lastCheckForNewEpisodesGlobal';

/// "Episodes" (website: EpisodesSection): season picker, the "Waiting for a
/// new episode?" callout with its one-minute-cooldown check, and a card per
/// episode that plays it.
class EpisodesSection extends ConsumerStatefulWidget {
  const EpisodesSection({super.key, required this.series, required this.onSelect, this.initialSeason});

  final CinemaRecord series;

  /// Opens on this season: the one the viewer got to.
  final String? initialSeason;
  final ValueChanged<Episode> onSelect;

  @override
  ConsumerState<EpisodesSection> createState() => _EpisodesSectionState();
}

class _EpisodesSectionState extends ConsumerState<EpisodesSection> {
  late final List<Episode> _ordered = orderEpisodes(widget.series.allEpisodes);
  late final List<String> _seasons = {
    for (final episode in _ordered)
      if (episode.season != null) episode.season!,
  }.toList()..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
  late String _season = _seasons.contains(widget.initialSeason) ? widget.initialSeason! : (_seasons.firstOrNull ?? '1');

  Duration _remaining = Duration.zero;
  bool _checking = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final last = ref.read(sharedPreferencesProvider).getInt(_cooldownKey);
    final left = last == null ? Duration.zero : _cooldown - DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last));
    final next = left.isNegative ? Duration.zero : left;
    if (mounted && next.inSeconds != _remaining.inSeconds) setState(() => _remaining = next);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _checkForNew() async {
    if (_remaining > Duration.zero || _checking) return;
    setState(() => _checking = true);
    await ref.read(catalogApiProvider).checkForNewEpisodes(widget.series.id, widget.series.title);
    await ref.read(sharedPreferencesProvider).setInt(_cooldownKey, DateTime.now().millisecondsSinceEpoch);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _remaining = _cooldown;
    });
    // New episodes take time to appear — briefly show "checking", then home.
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    if (_ordered.isEmpty) return const SizedBox.shrink();

    final seasonEpisodes = _ordered.where((episode) => episode.season == _season).toList();
    final progress = ref.watch(watchProgressProvider);
    final seriesTmdbId = widget.series.tmdbId;
    final minutes = _remaining.inMinutes;
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return InViewOnce(
      threshold: 0.1,
      builder: (context, inView) => Reveal(
        visible: inView,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  SectionHeading(t('sections.episodes'), spacing: 0),
                  if (_seasons.length > 1)
                    ModernSelect(
                      value: _season,
                      options: [for (final season in _seasons) SelectOption(season, '${t('sections.season')} $season')],
                      onChanged: (season) => setState(() => _season = season),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.only(bottom: 32),
                padding: const EdgeInsets.all(16),
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
                          child: const Icon(LucideIcons.bellRing, size: 20, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('episodes.newTitle'),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              Text(t('episodes.newHint'), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_remaining > Duration.zero)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.clock, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 8),
                            Text(
                              '${t('episodes.checking')} $minutes:$seconds',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      )
                    else
                      Pressable(
                        onTap: _checking ? null : _checkForNew,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.55),
                                blurRadius: 24,
                                spreadRadius: -4,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _checking
                                  ? const Spinner(size: 16, color: AppColors.onWhite)
                                  : const Icon(LucideIcons.refreshCw, size: 16, color: AppColors.onWhite),
                              const SizedBox(width: 8),
                              Text(
                                _checking ? t('episodes.pleaseWait') : t('episodes.checkForNew'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onWhite),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (final episode in seasonEpisodes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _EpisodeCard(
                    episode: episode,
                    progress: seriesTmdbId == null || episode.season == null || episode.episodeNumber == null
                        ? null
                        : progress[ProgressTarget.episode(seriesTmdbId, episode.season!, episode.episodeNumber!).key],
                    minutesLabel: t('common.minutes'),
                    onTap: () => widget.onSelect(episode),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeCard extends ConsumerWidget {
  const _EpisodeCard({required this.episode, required this.progress, required this.minutesLabel, required this.onTap});

  final Episode episode;
  final WatchProgress? progress;
  final String minutesLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final description = episode.description != null && episode.description!.length > 219
        ? '${episode.description!.substring(0, 219)}..'
        : episode.description;
    final rating = double.tryParse(episode.tmdbRating ?? '');
    final finished = progress?.finished ?? false;
    final percent = finished ? null : progress?.percent;

    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.fg(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.fg(0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (episode.posterImgURL != null) AuroraImage(url: tmdbImage(episode.posterImgURL, TmdbSize.w780)),
                  // Touch has no hover — the play badge always shows, softly.
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.9)),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 3),
                        child: Center(child: FaIcon(FontAwesomeIcons.play, size: 15, color: Colors.black)),
                      ),
                    ),
                  ),
                  if (finished)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.check, size: 13, color: AppColors.emerald),
                            const SizedBox(width: 4),
                            Text(
                              ref.watch(translatorProvider)('episodes.watched'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (percent != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 4,
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.25),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percent / 100,
                          child: const ColoredBox(color: AppColors.sky),
                        ),
                      ),
                    ),
                  if (rating != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          '★ ${rating.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${episode.episodeNumber ?? ''}. ',
                          style: TextStyle(color: AppColors.fg(0.5)),
                        ),
                        TextSpan(text: episode.episodeTitle ?? ''),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      formatReleaseDate(episode.airDate, ref.watch(localeProvider).name),
                      if (episode.runtime != null) '• ${episode.runtime} $minutesLabel',
                    ].join(' '),
                    style: TextStyle(fontSize: 12, color: AppColors.fg(0.45)),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 1.6, color: AppColors.fg(0.6)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
