import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/catalog_api.dart';
import '../../core/library/last_viewed.dart';
import '../../core/library/watch_progress.dart';
import '../../core/slow_scroll.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../shell/app_shell.dart';
import '../../widgets/footer.dart';
import '../../widgets/loader.dart';
import '../../widgets/reveal.dart';
import '../../widgets/status_page.dart';
import 'comments_section.dart';
import 'details_background.dart';
import 'facts_section.dart';
import 'details_sections.dart';
import 'episodes_section.dart';
import 'player_section.dart';
import 'similar_titles_section.dart';

typedef _DetailsKey = ({RecordType type, String id});

final _detailsProvider = FutureProvider.family<CinemaRecord?, _DetailsKey>((ref, key) => ref.watch(catalogApiProvider).details(key.type, key.id));

/// A movie's or series' page (website: CinemaRecordDetailsPage): header,
/// trailer, cast, images, the player (and episodes for a series), comments,
/// footer. Opening it records it in "Last Viewed".
class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key, required this.type, required this.id, this.glideToPlayer = false});

  final RecordType type;
  final String id;

  /// Opened from "Continue watching": go straight on to the player.
  final bool glideToPlayer;

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final _slowScroll = SlowScroller(this);
  final _playerKey = GlobalKey();
  final _episodesKey = GlobalKey();
  bool _tracked = false;

  /// For a series: the episode playing (the series record itself has no
  /// playable URL — the first episode is the default).
  String? _episodeUrl;

  /// The season of the episode it opened on, when the viewer has been here.
  String? _resumeSeason;
  bool _resumeChecked = false;

  /// Opens a series on the episode the viewer was on, or on the next one once
  /// it's finished.
  void _resumeEpisode(CinemaRecord record) {
    // Signed in, the positions are the account's, once they've loaded.
    if (_resumeChecked || !ref.read(watchProgressReadyProvider)) return;
    _resumeChecked = true;
    if (!record.isSeries) return;
    final latest = latestProgress(ref.read(watchProgressProvider), isSeries: true, tmdbId: record.tmdbId);
    if (latest == null) return;
    final ordered = orderEpisodes(record.allEpisodes);
    final index = ordered.indexWhere(
      (episode) => int.tryParse(episode.season ?? '') == int.tryParse(latest.season ?? '') && int.tryParse(episode.episodeNumber ?? '') == int.tryParse(latest.episode ?? ''),
    );
    if (index < 0) return;
    final episode = latest.progress.finished && index + 1 < ordered.length ? ordered[index + 1] : ordered[index];
    _episodeUrl = episode.videoURL;
    _resumeSeason = episode.season;
  }

  @override
  void dispose() {
    _slowScroll.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The header's "Watch now" / "Go to episodes": a slow glide down to the
  /// player, which lands just under the floating header.
  void _glideToPlayer() {
    _slowScroll.scrollTo(_scroll, _playerKey, topInset: shellContentPadding(context).top + 8);
  }

  void _playEpisode(Episode episode) {
    setState(() => _episodeUrl = episode.videoURL);
    Future.delayed(const Duration(milliseconds: 100), _scrollToPlayer);
  }

  /// Brings the player up to the top, like the site does after an episode
  /// is picked. The ListView builds its children lazily, so once a season's
  /// (tall) episode list has been scrolled far enough, the player above it
  /// isn't built any more and has no context to scroll to. In that case
  /// scroll to the top of the episodes section first — the player sits
  /// right above it, so it gets built — and then on to the player.
  Future<void> _scrollToPlayer() async {
    const duration = Duration(milliseconds: 600);

    if (!mounted) return;

    if (_playerKey.currentContext == null) {
      final episodesContext = _episodesKey.currentContext;
      if (episodesContext == null || !episodesContext.mounted) return;
      await Scrollable.ensureVisible(episodesContext, duration: duration, curve: auroraEase);
      await WidgetsBinding.instance.endOfFrame;
    }

    final playerContext = _playerKey.currentContext;
    if (playerContext != null && playerContext.mounted) {
      await Scrollable.ensureVisible(playerContext, duration: duration, curve: auroraEase);
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(_detailsProvider((type: widget.type, id: widget.id)));
    ref.watch(watchProgressReadyProvider);

    return ColoredBox(
      color: AppColors.background,
      child: details.when(
        loading: () => Padding(
          padding: shellContentPadding(context),
          child: const Center(child: Spinner(size: 48)),
        ),
        error: (_, _) => NotFoundPage(padding: shellContentPadding(context)),
        data: (record) {
          if (record == null) return NotFoundPage(padding: shellContentPadding(context));
          if (!_tracked) {
            _tracked = true;
            Future.microtask(() => ref.read(lastViewedProvider.notifier).record(record));
            if (widget.glideToPlayer) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _glideToPlayer();
              });
            }
          }
          _resumeEpisode(record);

          final poster = tmdbImage(record.backgroundImgURL ?? record.posterImgURL, TmdbSize.w1280);
          final videoUrl = record.isSeries
              ? (_episodeUrl ?? ((record.videoURL?.isNotEmpty ?? false) ? record.videoURL! : (orderEpisodes(record.allEpisodes).firstOrNull?.videoURL ?? '')))
              : record.videoURL;

          final canWatch = videoUrl != null && videoUrl.isNotEmpty;

          // No top padding: the banner starts at the very top, under the
          // floating header (DetailsHeader adds the header's height to it).

          return Stack(
            children: [
              Positioned.fill(child: DetailsBackground(record: record)),
              // Any touch takes over from a running "Watch now" glide.
              Listener(
                onPointerDown: (_) => _slowScroll.cancel(),
                child: ListView(
                  controller: _scroll,
                  padding: shellContentPadding(context).copyWith(top: 0),
                  children: [
                    DetailsHeader(record: record, onWatch: canWatch ? _glideToPlayer : null),
                    FactsSection(record: record),
                    if (record.trailerURL != null && record.trailerURL!.isNotEmpty) RevealOnScroll(child: TrailerSection(trailerUrl: record.trailerURL!)),
                    CastSection(cast: record.castList, backgroundPath: detailsBackgroundPath(record)),
                    RevealOnScroll(child: ImageGallery(images: record.imagesList)),
                    if (videoUrl != null && (videoUrl.isNotEmpty || record.isSeries))
                      PlayerSection(key: _playerKey, videoUrl: videoUrl, title: record.title, poster: poster),
                    if (record.isSeries) EpisodesSection(key: _episodesKey, series: record, initialSeason: _resumeSeason, onSelect: _playEpisode),
                    SimilarTitlesSection(record: record),
                    RevealOnScroll(
                      child: CommentsSection(recordId: record.id, type: record.type),
                    ),
                    const SiteFooter(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
