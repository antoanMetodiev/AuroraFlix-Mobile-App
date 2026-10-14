import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/catalog_api.dart';
import '../../models/models.dart';

/// Both trending lists, fetched in parallel (website: app/page.tsx).
final trendingProvider = FutureProvider<({List<CinemaRecord> movies, List<CinemaRecord> series})>((ref) async {
  final api = ref.watch(catalogApiProvider);
  final results = await Future.wait([api.trending(RecordType.movie), api.trending(RecordType.series)]);
  return (movies: results[0], series: results[1]);
});

const _heroMovies = 10;
const _heroSeries = 10;

List<T> _shuffled<T>(List<T> items) => [...items]..shuffle(math.Random());

/// The hero carousel's titles: each list shuffled (so the same trailer
/// doesn't always open the page), then interleaved movie, series, movie…
/// Computed once per load, like the website does once per request.
final heroItemsProvider = FutureProvider<List<CinemaRecord>>((ref) async {
  final trending = await ref.watch(trendingProvider.future);
  final movies = _shuffled(trending.movies).take(_heroMovies).toList();
  final series = _shuffled(trending.series).take(_heroSeries).toList();
  final mixed = <CinemaRecord>[];
  for (var i = 0; i < math.max(movies.length, series.length); i++) {
    if (i < movies.length) mixed.add(movies[i]);
    if (i < series.length) mixed.add(series[i]);
  }
  return mixed;
});

/// One entry of the "Trending Movies / Series" showcase, already ranked.
class RankedItem {
  const RankedItem({required this.record, required this.rank});

  final CinemaRecord record;
  final int rank;
}

/// The trending endpoints list newest-inserted first, i.e. #1 last — flipped
/// so the showcase can number them (website: toShowcaseItems).
List<RankedItem> rankTrending(List<CinemaRecord> records) {
  final withPosters = records.reversed.where((record) => record.posterImgURL != null).toList();
  return [for (var i = 0; i < withPosters.length; i++) RankedItem(record: withPosters[i], rank: i + 1)];
}

const _popularCount = 12;
const _windowMonths = 12;

/// TMDB averages from a handful of votes can sit at a perfect 10 above
/// everything real — anything this high is treated as noise.
const _maxTrustedRating = 9.5;

String _isoDate(DateTime date) => date.toIso8601String().substring(0, 10);

/// Website: PopularSection's pickPopular — best-rated titles released in
/// the last 12 months, deduplicated, top 12.
List<CinemaRecord> _pickPopular(List<CinemaRecord> records) {
  final now = DateTime.now().toUtc();
  final today = _isoDate(now);
  final since = _isoDate(DateTime.utc(now.year, now.month - _windowMonths, now.day));

  final eligible = records.where((record) {
    final rating = double.tryParse(record.tmdbRating);
    final released = record.releaseDate ?? '';
    return record.tmdbId != null &&
        record.posterImgURL != null &&
        rating != null &&
        rating > 0 &&
        rating < _maxTrustedRating &&
        released.compareTo(since) >= 0 &&
        released.compareTo(today) <= 0;
  }).toList()..sort((a, b) => double.parse(b.tmdbRating).compareTo(double.parse(a.tmdbRating)));

  final seen = <String>{};
  return eligible.where((record) => seen.add(record.tmdbId!)).take(_popularCount).toList();
}

final popularProvider = FutureProvider<({List<CinemaRecord> movies, List<CinemaRecord> series})>((ref) async {
  final api = ref.watch(catalogApiProvider);
  final year = DateTime.now().toUtc().year;
  DiscoverFilters filters(int y) => DiscoverFilters(sort: SortOption.topRated, year: '$y');

  final results = await Future.wait([
    api.discover(RecordType.movie, filters(year), 1),
    api.discover(RecordType.movie, filters(year - 1), 1),
    api.discover(RecordType.series, filters(year), 1),
    api.discover(RecordType.series, filters(year - 1), 1),
  ]);

  return (movies: _pickPopular([...results[0], ...results[1]]), series: _pickPopular([...results[2], ...results[3]]));
});

/// The hand-picked "Cult Movies / Cult Shows" rows — same titles and images
/// as the website's lib/data/home-marquee.ts (images bundled in assets/).
class MarqueeItem {
  const MarqueeItem(this.title, this.tmdbId, this.image, this.type);

  final String title;
  final String tmdbId;
  final String image;
  final RecordType type;
}

const cultMovies = [
  MarqueeItem('Anora', '1064213', 'assets/movies/anora.webp', RecordType.movie),
  MarqueeItem('Get Out', '419430', 'assets/movies/get-out.webp', RecordType.movie),
  MarqueeItem('Knives Out', '546554', 'assets/movies/knives-out.webp', RecordType.movie),
  MarqueeItem('Prey', '766507', 'assets/movies/prey.jpg', RecordType.movie),
  MarqueeItem('Joker', '475557', 'assets/movies/the_joker.webp', RecordType.movie),
  MarqueeItem('Project X', '57214', 'assets/movies/the_x_project.webp', RecordType.movie),
  MarqueeItem('The Babysitter', '419479', 'assets/movies/the-babysiter.webp', RecordType.movie),
  MarqueeItem('Through My Window', '818647', 'assets/movies/throw-the-window.webp', RecordType.movie),
  MarqueeItem('Wrong Turn', '630586', 'assets/movies/wrong_turn.webp', RecordType.movie),
];

const cultSeries = [
  MarqueeItem('13 Reasons Why', '66788', 'assets/series/13-reasons-why.webp', RecordType.series),
  MarqueeItem('Breaking Bad', '1396', 'assets/series/breaking-bad.webp', RecordType.series),
  MarqueeItem('Chernobyl', '87108', 'assets/series/chernobyl.webp', RecordType.series),
  MarqueeItem('Dark', '70523', 'assets/series/dark.webp', RecordType.series),
  MarqueeItem('Elite', '76669', 'assets/series/elite.webp', RecordType.series),
  MarqueeItem('Euphoria', '85552', 'assets/series/euphoria.webp', RecordType.series),
  MarqueeItem('Game of Thrones', '1399', 'assets/series/game-of-thrones.webp', RecordType.series),
  MarqueeItem('House of the Dragon', '94997', 'assets/series/house-of-the-dragon.webp', RecordType.series),
  MarqueeItem('Outer Banks', '100757', 'assets/series/outher-banks.webp', RecordType.series),
  MarqueeItem('The 100', '48866', 'assets/series/the-100.webp', RecordType.series),
  MarqueeItem('The Vampire Diaries', '18165', 'assets/series/the-vampier-diares.webp', RecordType.series),
  MarqueeItem('Vikings', '44217', 'assets/series/vikings.webp', RecordType.series),
];
