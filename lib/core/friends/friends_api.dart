import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../models/models.dart';
import '../api/api_client.dart';
import '../api/catalog_api.dart';
import '../library/playlists.dart';
import '../library/watchlist.dart';

/// Friends, requests, notifications and "watching now" on the gateway —
/// port of my-app/lib/friends.ts + watching.ts.
class Friend {
  const Friend({required this.clerkId, this.displayName, this.profileImageURL});

  final String clerkId;
  final String? displayName;
  final String? profileImageURL;

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    clerkId: '${json['clerkId']}',
    displayName: json['displayName'] as String?,
    profileImageURL: json['profileImageURL'] as String?,
  );
}

class FriendRequestItem {
  const FriendRequestItem({required this.id, required this.person});

  final String id;
  final Friend person;

  factory FriendRequestItem.fromJson(Map<String, dynamic> json) => FriendRequestItem(id: '${json['id']}', person: Friend.fromJson(json));
}

enum Relationship { none, pendingSent, pendingReceived, friends }

class FriendSearchResult {
  const FriendSearchResult({required this.person, required this.relationship});

  final Friend person;
  final Relationship relationship;

  factory FriendSearchResult.fromJson(Map<String, dynamic> json) => FriendSearchResult(
    person: Friend.fromJson(json),
    relationship: switch (json['relationship']) {
      'PENDING_SENT' => Relationship.pendingSent,
      'PENDING_RECEIVED' => Relationship.pendingReceived,
      'FRIENDS' => Relationship.friends,
      _ => Relationship.none,
    },
  );
}

enum NotificationType { request, accepted, declined }

class FriendNotification {
  const FriendNotification({required this.id, required this.type, required this.actor});

  final String id;
  final NotificationType type;
  final Friend actor;

  factory FriendNotification.fromJson(Map<String, dynamic> json) => FriendNotification(
    id: '${json['id']}',
    type: switch (json['type']) {
      'FRIEND_REQUEST_ACCEPTED' => NotificationType.accepted,
      'FRIEND_REQUEST_DECLINED' => NotificationType.declined,
      _ => NotificationType.request,
    },
    actor: Friend(
      clerkId: '${json['actorId']}',
      displayName: json['actorDisplayName'] as String?,
      profileImageURL: json['actorProfileImageURL'] as String?,
    ),
  );
}

/// What someone is playing right now (website: WatchingTarget).
class WatchingTarget {
  const WatchingTarget({required this.tmdbId, required this.type, required this.title, this.season, this.episode});

  final String tmdbId;
  final RecordType type;
  final String title;
  final int? season;
  final int? episode;

  static WatchingTarget? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return WatchingTarget(
      tmdbId: '${json['tmdbId']}',
      type: json['type'] == 'series' ? RecordType.series : RecordType.movie,
      title: '${json['title'] ?? ''}',
      season: (json['season'] as num?)?.toInt(),
      episode: (json['episode'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() => {
    'tmdbId': tmdbId,
    'type': type == RecordType.series ? 'series' : 'movie',
    'title': title,
    'season': ?season,
    'episode': ?episode,
  };

  @override
  bool operator ==(Object other) =>
      other is WatchingTarget &&
      other.tmdbId == tmdbId &&
      other.type == type &&
      other.title == title &&
      other.season == season &&
      other.episode == episode;

  @override
  int get hashCode => Object.hash(tmdbId, type, title, season, episode);
}

class FriendsApi {
  FriendsApi(this._api);

  final ApiClient _api;

  String _id(String id) => Uri.encodeComponent(id);

  bool _ok(http.Response? response) => response != null && response.statusCode < 300;

  Future<List<Friend>> friends() async => ApiClient.unwrapList(await _api.getJson('/friends')).map(Friend.fromJson).toList();

  Future<List<FriendRequestItem>> incoming() async =>
      ApiClient.unwrapList(await _api.getJson('/friends/requests/incoming')).map(FriendRequestItem.fromJson).toList();

  Future<List<FriendRequestItem>> outgoing() async =>
      ApiClient.unwrapList(await _api.getJson('/friends/requests/outgoing')).map(FriendRequestItem.fromJson).toList();

  /// A blank query lists recently joined people.
  Future<List<FriendSearchResult>> search(String query) async =>
      ApiClient.unwrapList(await _api.getJson('/friends/search', {'query': query})).map(FriendSearchResult.fromJson).toList();

  Future<bool> send(String addresseeId) async => _ok(await _api.send('POST', '/friends/requests', body: {'addresseeId': addresseeId}));

  Future<bool> accept(String requestId) async => _ok(await _api.send('POST', '/friends/requests/${_id(requestId)}/accept'));

  Future<bool> cancelOrDecline(String requestId) async => _ok(await _api.send('DELETE', '/friends/requests/${_id(requestId)}'));

  Future<bool> remove(String clerkId) async => _ok(await _api.send('DELETE', '/friends/${_id(clerkId)}'));

  /// Reading them also marks them as seen.
  Future<List<FriendNotification>> consumeNotifications() async =>
      ApiClient.unwrapList(await _api.getJson('/friends/notifications')).map(FriendNotification.fromJson).toList();

  Future<int> notificationCount() async {
    final data = await _api.getJson('/friends/notifications/count');
    return data is Map && data['count'] is num ? (data['count'] as num).toInt() : 0;
  }

  Future<Map<String, WatchingTarget>> friendsWatching() async => {
    for (final entry in ApiClient.unwrapList(await _api.getJson('/watching/friends')))
      '${entry['clerkId']}': ?WatchingTarget.fromJson(entry['watching']),
  };

  Future<void> setWatching(WatchingTarget target) => _api.send('PUT', '/watching', body: target.toJson());

  Future<void> clearWatching() => _api.send('DELETE', '/watching');

  Future<List<LibraryItem>> likesOf(String clerkId) async =>
      ApiClient.unwrapList(await _api.getJson('/likes/user/${_id(clerkId)}')).map(LibraryItem.fromJson).toList();

  Future<List<Playlist>> visiblePlaylistsOf(String clerkId) async =>
      ApiClient.unwrapList(await _api.getJson('/playlists/${_id(clerkId)}/visible')).map(Playlist.fromJson).toList();
}

final friendsApiProvider = Provider<FriendsApi>((ref) => FriendsApi(ref.watch(apiClientProvider)));

/// Poster / genres / description for a "watching" card — cached per title
/// for the session (website: getMoviePreview / getSeriesPreview).
final titlePreviewProvider = FutureProvider.family<CinemaRecord?, (RecordType, String)>((ref, key) {
  ref.keepAlive();
  return ref.read(catalogApiProvider).details(key.$1, key.$2);
});

List<String> previewGenres(CinemaRecord? preview, int count) =>
    (preview?.genres ?? '').split(',').map((genre) => genre.trim()).where((genre) => genre.isNotEmpty).take(count).toList();
