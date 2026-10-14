import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/locale.dart';
import '../../core/library/last_viewed.dart';
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

    return ColoredBox(
      color: AppColors.background,
      child: WorkCarousel(
        heading: t('carousel.lastViewed'),
        items: [
          for (final entry in items)
            WorkCardItem(
              title: entry.title,
              posterURL: entry.posterURL,
              tmdbRating: entry.tmdbRating,
              type: entry.type,
              detailsId: entry.detailsId,
            ),
        ],
      ),
    );
  }
}
