import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/locale.dart';
import '../core/navigation.dart';
import '../core/theme.dart';
import '../core/tmdb.dart';
import '../models/models.dart';
import 'fade_in_image.dart';
import 'pressable.dart';
import 'rating_ring.dart';

class WorkCardItem {
  const WorkCardItem({required this.title, required this.posterURL, required this.tmdbRating, required this.type, required this.detailsId});

  final String title;
  final String? posterURL;
  final String tmdbRating;
  final RecordType type;
  final String detailsId;
}

/// A heading and a sideways row of glowing poster cards with a rating ring,
/// title and type — the website's WorkCarousel ("Last Viewed", an actor's
/// "Latest Works"). [action] sits under the heading (the actor page's
/// "check for more movies" button).
class WorkCarousel extends ConsumerWidget {
  const WorkCarousel({super.key, required this.heading, required this.items, this.action});

  final String heading;
  final List<WorkCardItem> items;
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    if (items.isEmpty && action == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(heading, style: display(const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, letterSpacing: -0.3))),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
          if (items.isNotEmpty)
            SizedBox(
              height: 8 + 300 + 8 + 44 + 16,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 20),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final rating = double.tryParse(item.tmdbRating);
                  return Pressable(
                    onTap: () => openTitle(context, item.type, item.detailsId),
                    child: SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            width: 200,
                            height: 300,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.25), blurRadius: 15)],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AuroraImage(url: tmdbImage(item.posterURL, TmdbSize.w500)),
                                  const Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    height: 120,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [Color(0xB3000000), Colors.transparent],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (rating != null)
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: RatingRing(value: rating, size: RatingRingSize.xs),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            item.type == RecordType.series ? t('watchlist.series') : t('watchlist.movie'),
                            style: TextStyle(fontSize: 14, color: AppColors.fg(0.7)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
