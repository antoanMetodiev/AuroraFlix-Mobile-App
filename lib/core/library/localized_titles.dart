import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'watchlist.dart';

/// A title's current name and poster in the app's language.
typedef LocalizedTitle = ({String title, String? posterImgURL});

/// How long ids are collected before one request goes out. Lists on a
/// screen get their items at slightly different moments (each playlist loads
/// its own), so a short window — not just the same frame — lets them share
/// a call. The saved copies show meanwhile (the website does the same).
const _batchWindow = Duration(milliseconds: 50);

/// Merges the lookups of every list asking within [_batchWindow] of the
/// first into one request per kind (GET /get-movie-titles,
/// /get-series-titles), instead of one per list.
class _TitleBatcher {
  _TitleBatcher(this._api);

  final ApiClient _api;
  final _pending = <String, ({Set<String> ids, Future<Map<String, LocalizedTitle>> rows})>{};

  /// Resolves with all of that request's titles (other lists' ones included).
  Future<Map<String, LocalizedTitle>> load(String kind, Iterable<String> ids) {
    var batch = _pending[kind];
    if (batch == null) {
      final collected = <String>{};
      final rows = Future<void>.delayed(_batchWindow).then((_) async {
        _pending.remove(kind);
        final data = await _api.getJson(kind == 'movie' ? '/get-movie-titles' : '/get-series-titles', {'ids': collected.join(',')});
        return {
          for (final row in ApiClient.unwrapList(data))
            if (row['tmdbId'] is String && row['title'] is String)
              row['tmdbId'] as String: (title: row['title'] as String, posterImgURL: row['posterImgURL'] as String?),
        };
      });
      batch = _pending[kind] = (ids: collected, rows: rows);
    }
    batch.ids.addAll(ids);
    return batch.rows;
  }
}

/// Rebuilt with the ApiClient — i.e. on a language switch, which adds ?lang.
final _titleBatcherProvider = Provider<_TitleBatcher>((ref) => _TitleBatcher(ref.watch(apiClientProvider)));

/// `movie|1,2,3` / `series|4,5` → each TMDB id's current title and poster,
/// fetched together with whatever other lists ask at the same time (and
/// refetched in the new language after a switch).
final _titlesProvider = FutureProvider.family<Map<String, LocalizedTitle>, String>((ref, key) async {
  final separator = key.indexOf('|');
  final kind = key.substring(0, separator);
  final ids = key.substring(separator + 1).split(',');
  return ref.watch(_titleBatcherProvider).load(kind, ids);
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
