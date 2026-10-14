import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import 'tmdb.dart';

/// The tab branches that have their own URL prefix (home is the bare `/`).
const _branchPrefixes = ['/movies', '/series', '/watchlist', '/playlists', '/order'];

/// Details and actor screens open inside whichever tab you're on (so the
/// header and tab bar stay, like on the website) — this is that tab's prefix.
String _currentBranchPrefix(BuildContext context) {
  final path = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
  return _branchPrefixes.where(path.startsWith).firstOrNull ?? '';
}

/// Opens a title's details screen by its TMDB id.
void openTitle(BuildContext context, RecordType type, String id) {
  if (id.isEmpty) return;
  context.push('${_currentBranchPrefix(context)}/title/${type.name}/${Uri.encodeComponent(id)}');
}

void openRecord(BuildContext context, CinemaRecord record) => openTitle(context, record.type, detailsIdFor(record));

/// "Subscription" (website: /account/subscription), inside the current tab.
void openSubscription(BuildContext context) => context.push('${_currentBranchPrefix(context)}/account/subscription');

/// The backend has no "get actor by id" endpoint — an actor only exists
/// inside a title's cast list — so the actor travels along with the route
/// (the website hands it over through sessionStorage the same way).
void openActor(BuildContext context, Actor actor) {
  context.push('${_currentBranchPrefix(context)}/actor/${Uri.encodeComponent(actor.id)}', extra: actor);
}

String _listPath(RecordType type) => type == RecordType.movie ? '/movies' : '/series';

/// The catalog of [type] filtered to a genre (website: /movies/genres/X).
void openGenre(BuildContext context, RecordType type, String genre) =>
    context.go(Uri(path: _listPath(type), queryParameters: {'genre': genre}).toString());

/// Title search results (website: /movies/search/X).
void openSearch(BuildContext context, RecordType type, String query) =>
    context.go('${_listPath(type)}/search/${Uri.encodeComponent(query)}');

/// Closes every open dialog (friends, a profile on top of it…) and then
/// navigates — with a context that's still mounted afterwards.
void closeModalsAnd(BuildContext context, void Function(BuildContext context) navigate) {
  final navigator = Navigator.of(context, rootNavigator: true);
  navigator.popUntil((route) => route is! PopupRoute);
  navigate(navigator.context);
}
