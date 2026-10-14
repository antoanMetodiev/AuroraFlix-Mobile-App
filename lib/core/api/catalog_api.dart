import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import 'api_client.dart';

/// Public catalog endpoints — port of my-app/lib/api.ts + api-public.ts.
enum SortOption { newest, oldest, topRated }

extension on SortOption {
  String get param => switch (this) {
    SortOption.newest => 'newest',
    SortOption.oldest => 'oldest',
    SortOption.topRated => 'top_rated',
  };
}

class DiscoverFilters {
  const DiscoverFilters({this.genre, this.year, this.actor, this.sort});

  final String? genre;
  final String? year;
  final String? actor;
  final SortOption? sort;
}

class CatalogApi {
  CatalogApi(this._api);

  final ApiClient _api;

  static const pageSize = 30;

  Future<List<CinemaRecord>> _records(String path, RecordType type, [Map<String, Object?>? params]) async =>
      ApiClient.unwrapList(await _api.getJson(path, params)).map((json) => CinemaRecord.fromJson(json, type)).toList();

  Future<int> _count(String path, [Map<String, Object?>? params]) async {
    final data = await _api.getJson(path, params);
    return data is num ? data.toInt() : 0;
  }

  String _segment(RecordType type) => type == RecordType.movie ? 'movies' : 'series';

  Future<List<CinemaRecord>> trending(RecordType type) => _records('/get-trending-${_segment(type)}', type);

  /// [page] is 1-based like the website's; the gateway's is 0-based.
  Future<List<CinemaRecord>> discover(RecordType type, DiscoverFilters filters, int page) => _records('/discover-${_segment(type)}', type, {
    'genre': filters.genre,
    'year': filters.year,
    'actorName': filters.actor,
    'sort': filters.sort?.param,
    'page': page - 1,
    'size': pageSize,
  });

  Future<int> discoverCount(RecordType type, DiscoverFilters filters) =>
      _count('/discover-${_segment(type)}-count', {'genre': filters.genre, 'year': filters.year, 'actorName': filters.actor});

  Future<List<CinemaRecord>> searchByTitle(RecordType type, String title) =>
      _records(type == RecordType.movie ? '/get-movies-by-title' : '/get-series-by-title', type, {'title': title});

  /// Live search suggestions (the header's search dropdown).
  Future<List<CinemaRecord>> searchSuggestions(RecordType type, String title, {int limit = 10, int offset = 0}) {
    if (title.trim().isEmpty) return Future.value(const []);
    return _records('/search-${_segment(type)}-matching-results/${Uri.encodeComponent(title)}', type, {'limit': limit, 'offset': offset});
  }

  Future<CinemaRecord?> details(RecordType type, String id) async {
    if (id.isEmpty) return null;
    final data = type == RecordType.movie
        ? await _api.getJson('/get-movie-details', {'movieId': id})
        : await _api.getJson('/get-series-details', {'id': id});
    return data is Map<String, dynamic> ? CinemaRecord.fromJson(data, type) : null;
  }

  /// Actor suggestions for the list filters' actor field.
  Future<List<Actor>> suggestActors(RecordType type, String query) async {
    if (query.trim().isEmpty) return const [];
    final path = type == RecordType.movie ? '/suggest-movie-actors' : '/suggest-series-actors';
    return ApiClient.unwrapList(await _api.getJson(path, {'query': query})).map(Actor.fromJson).toList();
  }

  /// An actor's other titles in the catalog (the actor page's "Latest Works").
  Future<List<ActorWork>> actorLatestWorks(String imdbId) async =>
      ApiClient.unwrapList(await _api.getJson('/actor/latest-works/${Uri.encodeComponent(imdbId)}')).map(ActorWork.fromJson).toList();

  /// Asks the generators to pull in this actor's other movies.
  Future<void> requestMoreMoviesForActor(String imdbId) => _api.send('POST', '/add-movies-by-actor/${Uri.encodeComponent(imdbId)}');

  /// "Order a title": asks the generators to add a title by name.
  Future<bool> order(RecordType type, String title) async {
    final response = await _api.send('POST', type == RecordType.movie ? '/search-movies' : '/search-series', body: {'recordName': title});
    return response != null && response.statusCode < 300;
  }

  /// Asks the series generator to look for episodes that came out since.
  Future<void> checkForNewEpisodes(String id, String title) =>
      _api.send('POST', '/check-for-new-episodes', body: {'id': id, 'title': title});
}

final catalogApiProvider = Provider<CatalogApi>((ref) => CatalogApi(ref.watch(apiClientProvider)));
