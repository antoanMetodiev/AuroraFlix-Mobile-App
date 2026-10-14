import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/catalog_api.dart';
import '../../core/library/last_viewed.dart';
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

typedef _DetailsKey = ({RecordType type, String id});

final _detailsProvider = FutureProvider.family<CinemaRecord?, _DetailsKey>(
  (ref, key) => ref.watch(catalogApiProvider).details(key.type, key.id),
);

/// A movie's or series' page (website: CinemaRecordDetailsPage): header,
/// trailer, cast, images, the player (and episodes for a series), comments,
/// footer. Opening it records it in "Last Viewed".
class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key, required this.type, required this.id});

  final RecordType type;
  final String id;

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  final _scroll = ScrollController();
  final _playerKey = GlobalKey();
  bool _tracked = false;

  /// For a series: the episode playing (the series record itself has no
  /// playable URL — the first episode is the default).
  String? _episodeUrl;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _playEpisode(Episode episode) {
    setState(() => _episodeUrl = episode.videoURL);
    Future.delayed(const Duration(milliseconds: 100), () {
      final playerContext = _playerKey.currentContext;
      if (playerContext != null && playerContext.mounted) {
        Scrollable.ensureVisible(playerContext, duration: const Duration(milliseconds: 600), curve: auroraEase);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(_detailsProvider((type: widget.type, id: widget.id)));

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
          }

          final poster = tmdbImage(record.backgroundImgURL ?? record.posterImgURL, TmdbSize.w1280);
          final videoUrl = record.isSeries
              ? (_episodeUrl ??
                    ((record.videoURL?.isNotEmpty ?? false)
                        ? record.videoURL!
                        : (orderEpisodes(record.allEpisodes).firstOrNull?.videoURL ?? '')))
              : record.videoURL;

          // No top padding: the banner starts at the very top, under the
          // floating header (DetailsHeader adds the header's height to it).
          return Stack(
            children: [
              Positioned.fill(child: DetailsBackground(record: record)),
              ListView(
                controller: _scroll,
                padding: shellContentPadding(context).copyWith(top: 0),
                children: [
                  DetailsHeader(record: record),
                  FactsSection(record: record),
                  if (record.trailerURL != null && record.trailerURL!.isNotEmpty)
                    RevealOnScroll(child: TrailerSection(trailerUrl: record.trailerURL!)),
                  CastSection(cast: record.castList),
                  RevealOnScroll(child: ImageGallery(images: record.imagesList)),
                  if (videoUrl != null && (videoUrl.isNotEmpty || record.isSeries))
                    PlayerSection(key: _playerKey, videoUrl: videoUrl, title: record.title, poster: poster),
                  if (record.isSeries) EpisodesSection(series: record, onSelect: _playEpisode),
                  RevealOnScroll(
                    child: CommentsSection(recordId: record.id, type: record.type),
                  ),
                  // Fades the background out into the footer's solid black.
                  const SizedBox(
                    height: 120,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, AppColors.background],
                        ),
                      ),
                    ),
                  ),
                  const SiteFooter(),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
