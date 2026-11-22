import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/catalog_api.dart';
import '../../models/models.dart';

/// How many of each kind the home screen uses (hero, showcase, backdrop).
const _homeMovies = 5;
const _homeSeries = 5;

/// The endpoints list #1 last, so the top N are the last N entries.
List<T> _topTrending<T>(List<T> records, int count) =>
    records.length <= count ? records : records.sublist(records.length - count);

/// Both trending lists, fetched in parallel (website: app/page.tsx).
final trendingProvider = FutureProvider<({List<CinemaRecord> movies, List<CinemaRecord> series})>((ref) async {
  final api = ref.watch(catalogApiProvider);
  final results = await Future.wait([api.trending(RecordType.movie), api.trending(RecordType.series)]);
  return (movies: _topTrending(results[0], _homeMovies), series: _topTrending(results[1], _homeSeries));
});

List<T> _shuffled<T>(List<T> items) => [...items]..shuffle(math.Random());

/// The hero carousel's titles: each list shuffled (so the same trailer
/// doesn't always open the page), then interleaved movie, series, movie…
/// Computed once per load, like the website does once per request.
final heroItemsProvider = FutureProvider<List<CinemaRecord>>((ref) async {
  final trending = await ref.watch(trendingProvider.future);
  final movies = _shuffled(trending.movies);
  final series = _shuffled(trending.series);
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
