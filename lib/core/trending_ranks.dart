import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'api/catalog_api.dart';
import 'api/catalog_cache.dart';
import 'tmdb.dart';

/// The id a record is matched by against today's trending list: trending
/// movies carry their TMDB id as movieId, catalog ones as tmdbId (or only in
/// their video URL) — same idea as the website's getMovieId.
String trendingKey(CinemaRecord record) => detailsIdFor(record);

/// Today's trending position of each title, by [trendingKey] — the "№3 днес"
/// badge on the catalog cards (website: lib/trending-ranks.ts). The endpoints
/// list #1 last, so the rank counts down from the end. Empty on failure.
final trendingRanksProvider = FutureProvider.family<Map<String, int>, RecordType>((ref, type) async {
  expireAfter(ref, listingCacheTtl);
  try {
    final records = await ref.watch(catalogApiProvider).trending(type);
    return {
      for (var i = 0; i < records.length; i++)
        if (trendingKey(records[i]).isNotEmpty) trendingKey(records[i]): records.length - i,
    };
  } catch (_) {
    return const {};
  }
});
