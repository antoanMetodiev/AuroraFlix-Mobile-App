import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/locale.dart';
import '../../core/library/last_viewed.dart';
import '../../core/library/localized_titles.dart';
import '../../core/library/watch_progress.dart';
import '../../models/models.dart';
import '../../core/theme.dart';
import '../../widgets/work_carousel.dart';

/// "Last Viewed" (website: LastViewedSection → WorkCarousel): the titles
/// opened most recently. Renders nothing until there's history, exactly
/// like the website.
class LastViewedSection extends ConsumerWidget {
  const LastViewedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final items = ref.watch(lastViewedProvider) ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    // Each entry keeps the title / poster from when it was opened — show the
    // catalog's current ones in the app's language.
    final progress = ref.watch(watchProgressProvider);
    final titles = LocalizedTitles.watch(ref, items.map((entry) => (isSeries: entry.type == RecordType.series, tmdbId: entry.tmdbId)));

    return ColoredBox(
      color: AppColors.background,
      child: WorkCarousel(
        heading: t('carousel.lastViewed'),
        items: [
          for (final entry in items)
            if (latestProgress(progress, isSeries: entry.type == RecordType.series, tmdbId: entry.tmdbId) case final latest)
            WorkCardItem(
              title: titles.lookup(isSeries: entry.type == RecordType.series, tmdbId: entry.tmdbId)?.title ?? entry.title,
              posterURL: titles.lookup(isSeries: entry.type == RecordType.series, tmdbId: entry.tmdbId)?.posterImgURL ?? entry.posterURL,
              tmdbRating: entry.tmdbRating,
              type: entry.type,
              detailsId: entry.detailsId,
              progressPercent: latest == null || latest.progress.finished ? null : latest.progress.percent,
              progressLabel: latest?.season == null ? null : t('carousel.episodeShort', {'season': latest!.season!, 'episode': latest.episode ?? ''}),
            ),
        ],
      ),
    );
  }
}
