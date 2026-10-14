import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'watchlist.dart';

/// A title's current name and poster in the app's language.
typedef LocalizedTitle = ({String title, String? posterImgURL});

/// `movie|1,2,3` / `series|4,5` → each TMDB id's current title and poster
/// (GET /get-movie-titles, /get-series-titles — the ApiClient adds ?lang and
/// is rebuilt on a language switch, so this refetches in the new language).
final _titlesProvider = FutureProvider.family<Map<String, LocalizedTitle>, String>((ref, key) async {
  final separator = key.indexOf('|');
  final kind = key.substring(0, separator);
  final ids = key.substring(separator + 1);
  final data = await ref.watch(apiClientProvider).getJson(kind == 'movie' ? '/get-movie-titles' : '/get-series-titles', {'ids': ids});
  return {
    for (final row in ApiClient.unwrapList(data))
      if (row['tmdbId'] is String && row['title'] is String)
        row['tmdbId'] as String: (title: row['title'] as String, posterImgURL: row['posterImgURL'] as String?),
  };
});

/// The watchlist, playlists, likes and last-viewed keep a copy of each
/// title / poster from when it was saved — in whatever language the app was
/// in then (the website's useLocalizedTitles does the same). [lookup] gives
/// the catalog's current one in the language the app is in now, once loaded;
/// until then (or for a title no longer in the catalog) null — show the copy.
class LocalizedTitles {
  LocalizedTitles._(this._movies, this._series);

  final Map<String, LocalizedTitle> _movies;
  final Map<String, LocalizedTitle> _series;

  LocalizedTitle? lookup({required bool isSeries, String? tmdbId}) => tmdbId == null ? null : (isSeries ? _series : _movies)[tmdbId];

  static LocalizedTitles watch(WidgetRef ref, Iterable<({bool isSeries, String? tmdbId})> items) {
    final movieIds = <String>{};
    final seriesIds = <String>{};
    for (final item in items) {
      final id = item.tmdbId;
      if (id == null || id.isEmpty) continue;
      (item.isSeries ? seriesIds : movieIds).add(id);
    }
    Map<String, LocalizedTitle> load(String kind, Set<String> ids) {
      if (ids.isEmpty) return const {};
      final key = '$kind|${(ids.toList()..sort()).join(',')}';
      return ref.watch(_titlesProvider(key)).value ?? const {};
    }

    return LocalizedTitles._(load('movie', movieIds), load('series', seriesIds));
  }
}

/// [items] with each title / poster swapped for the current, translated one.
List<LibraryItem>? localizeLibraryItems(WidgetRef ref, List<LibraryItem>? items) {
  if (items == null) return null;
  final titles = LocalizedTitles.watch(ref, items.map((item) => (isSeries: item.isSeries, tmdbId: item.tmdbId)));
  return [
    for (final item in items)
      if (titles.lookup(isSeries: item.isSeries, tmdbId: item.tmdbId) case final current?)
        LibraryItem(
          id: item.id,
          tmdbId: item.tmdbId,
          title: current.title,
          posterImgURL: (current.posterImgURL?.isNotEmpty ?? false) ? current.posterImgURL : item.posterImgURL,
          tmdbRating: item.tmdbRating,
          type: item.type,
          videoId: item.videoId,
        )
      else
        item,
  ];
}
