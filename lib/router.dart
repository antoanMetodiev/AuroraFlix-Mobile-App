import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/api/catalog_api.dart';
import 'core/navigation.dart';
import 'core/networks.dart';
import 'models/models.dart';
import 'screens/account/subscription_screen.dart';
import 'screens/actor/actor_screen.dart';
import 'screens/catalog/catalog_screen.dart';
import 'screens/details/details_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/order/order_screens.dart';
import 'screens/playlists/playlists_screen.dart';
import 'screens/recap/recap_screen.dart';
import 'screens/watchlist/watchlist_screen.dart';
import 'shell/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// A page opened inside a tab (title, actor, search, My week…): fades in from
/// a little lower while the one under it fades back a touch — the website's
/// page transition. Back runs it in reverse.
Page<void> smoothPage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 340),
  reverseTransitionDuration: const Duration(milliseconds: 240),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    final curve = CurvedAnimation(parent: animation, curve: const Cubic(0.22, 1, 0.36, 1), reverseCurve: Curves.easeIn);
    final under = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.0).animate(under),
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.025), end: Offset.zero).animate(curve), child: child),
      ),
    );
  },
);

/// Title details and actor pages, available under every tab so they open
/// inside the tab you came from.
List<RouteBase> _sharedRoutes() => [
  GoRoute(
    path: 'title/:type/:id',
    pageBuilder: (context, state) => smoothPage(
      state,
      DetailsScreen(
        key: ValueKey(state.uri.path),
        type: state.pathParameters['type'] == 'series' ? RecordType.series : RecordType.movie,
        id: state.pathParameters['id'] ?? '',
        glideToPlayer: state.uri.queryParameters['watch'] == '1',
      ),
    ),
  ),
  GoRoute(path: 'account/subscription', pageBuilder: (context, state) => smoothPage(state, const SubscriptionScreen())),
  GoRoute(
    path: 'actor/:id',
    pageBuilder: (context, state) {
      final args = state.extra is ActorPageArgs ? state.extra! as ActorPageArgs : null;
      return smoothPage(state, ActorScreen(actor: args?.actor, backgroundPath: args?.backgroundPath));
    },
  ),
];

StatefulShellBranch _branch(String path, Widget Function(GoRouterState state) screen, {List<RouteBase> routes = const []}) => StatefulShellBranch(
  routes: [
    GoRoute(
      path: path,
      pageBuilder: (context, state) => NoTransitionPage(child: screen(state)),
      routes: [...routes, ..._sharedRoutes()],
    ),
  ],
);

/// The catalog list for a tab: `?genre=&year=&actor=&sort=&page=`, or a
/// title search at `search/:query` (the website's /movies, /movies/genres/X
/// and /movies/search/X).
StatefulShellBranch _catalogBranch(String path, RecordType type) => _branch(
  path,
  (state) => CatalogScreen(key: ValueKey(state.uri.toString()), query: CatalogQuery.fromUri(type, state.uri)),
  routes: [
    GoRoute(
      path: 'search/:query',
      pageBuilder: (context, state) => smoothPage(
        state,
        CatalogScreen(
          key: ValueKey(state.uri.toString()),
          query: CatalogQuery(type: type, search: state.pathParameters['query'], page: int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 1),
        ),
      ),
    ),
  ],
);

/// One branch per tab, each with its own navigation stack (so a tab keeps
/// where you were in it).
final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute(
      builder: (context, state, navigationShell) => navigationShell,
      navigatorContainerBuilder: (context, navigationShell, children) => AppShell(navigationShell: navigationShell, children: children),
      branches: [
        _branch('/', (_) => const HomeScreen(), routes: [GoRoute(path: 'week', pageBuilder: (context, state) => smoothPage(state, const RecapScreen()))]),
        _catalogBranch('/movies', RecordType.movie),
        _catalogBranch('/series', RecordType.series),
        _branch('/watchlist', (_) => const WatchlistScreen()),
        _branch('/playlists', (_) => const PlaylistsScreen()),
        _branch(
          '/order',
          (_) => const OrderSelectScreen(),
          routes: [
            GoRoute(
              path: ':type',
              redirect: (context, state) => const {'movie', 'series'}.contains(state.pathParameters['type']) ? null : '/order',
              pageBuilder: (context, state) =>
                  smoothPage(state, OrderFormScreen(type: state.pathParameters['type'] == 'series' ? RecordType.series : RecordType.movie)),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Everything a catalog list is filtered by.
class CatalogQuery {
  const CatalogQuery({required this.type, this.genre, this.year, this.actor, this.network, this.sort, this.bgAudio = false, this.search, this.page = 1});

  final RecordType type;
  final String? genre;
  final String? year;
  final String? actor;

  /// Series only: one of topNetworks (?network=Netflix).
  final String? network;
  final SortOption? sort;

  /// Movies only: just the ones with a Bulgarian dub (?audio=bg).
  final bool bgAudio;
  final String? search;
  final int page;

  DiscoverFilters get filters => DiscoverFilters(genre: genre, year: year, actor: actor, network: network, sort: sort, bgAudio: bgAudio);

  static String? _nonEmpty(String? value) => value == null || value.isEmpty ? null : value;

  factory CatalogQuery.fromUri(RecordType type, Uri uri) {
    final params = uri.queryParameters;
    return CatalogQuery(
      type: type,
      genre: _nonEmpty(params['genre']),
      year: _nonEmpty(params['year']),
      actor: _nonEmpty(params['actor']),
      network: type == RecordType.series && isTopNetwork(params['network']) ? params['network'] : null,
      sort: switch (params['sort']) {
        'top_rated' => SortOption.topRated,
        'oldest' => SortOption.oldest,
        _ => null,
      },
      bgAudio: type == RecordType.movie && params['audio'] == 'bg',
      page: int.tryParse(params['page'] ?? '') ?? 1,
    );
  }

  /// The URL for this query — what a filter change navigates to.
  String location({int? page}) {
    final base = type == RecordType.movie ? '/movies' : '/series';
    final targetPage = page ?? this.page;
    if (search != null) {
      return Uri(path: '$base/search/${Uri.encodeComponent(search!)}', queryParameters: targetPage > 1 ? {'page': '$targetPage'} : null).toString();
    }
    final params = {
      'genre': ?genre,
      'year': ?year,
      'actor': ?actor,
      'network': ?network,
      if (sort == SortOption.topRated) 'sort': 'top_rated',
      if (sort == SortOption.oldest) 'sort': 'oldest',
      if (bgAudio) 'audio': 'bg',
      if (targetPage > 1) 'page': '$targetPage',
    };
    return Uri(path: base, queryParameters: params.isEmpty ? null : params).toString();
  }

  CatalogQuery copyWith({
    String? Function()? genre,
    String? Function()? year,
    String? Function()? actor,
    String? Function()? network,
    SortOption? Function()? sort,
    bool? bgAudio,
  }) => CatalogQuery(
    type: type,
    genre: genre != null ? genre() : this.genre,
    year: year != null ? year() : this.year,
    actor: actor != null ? actor() : this.actor,
    network: network != null ? network() : this.network,
    sort: sort != null ? sort() : this.sort,
    bgAudio: bgAudio ?? this.bgAudio,
    search: search,
    // Any filter change starts over from page 1.
    page: 1,
  );

  @override
  bool operator ==(Object other) =>
      other is CatalogQuery &&
      other.type == type &&
      other.genre == genre &&
      other.year == year &&
      other.actor == actor &&
      other.network == network &&
      other.sort == sort &&
      other.bgAudio == bgAudio &&
      other.search == search &&
      other.page == page;

  @override
  int get hashCode => Object.hash(type, genre, year, actor, network, sort, bgAudio, search, page);
}
