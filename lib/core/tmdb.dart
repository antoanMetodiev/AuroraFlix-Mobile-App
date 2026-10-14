import '../models/models.dart';

/// Port of my-app/lib/tmdb.ts — TMDB image URLs and the movie id/slug rules.
enum TmdbSize { w300, w342, w500, w780, w1280, original }

const _tmdbImageBase = 'https://image.tmdb.org/t/p';

String? tmdbImage(String? path, [TmdbSize size = TmdbSize.w780]) {
  if (path == null || path.isEmpty) return null;
  return path.startsWith('http') ? path : '$_tmdbImageBase/${size.name}$path';
}

/// Movie list/search/details endpoints don't always return a `movieId` —
/// tmdbId is the source of truth once a record has it, then movieId, then
/// the trailing number of the legacy videoURL (".../embed/movie/1064213").
String getMovieId(CinemaRecord record) {
  final fromUrl = RegExp(r'/(\d+)$').firstMatch(record.videoURL ?? '')?.group(1);
  return record.tmdbId ?? record.movieId ?? fromUrl ?? '';
}

/// The id a details screen is fetched by: a movie's TMDB id, a series' tmdbId.
String detailsIdFor(CinemaRecord record) => record.isSeries ? (record.tmdbId ?? '') : getMovieId(record);
