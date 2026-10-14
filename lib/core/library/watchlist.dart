import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../i18n/locale.dart';
import '../tmdb.dart';

/// One saved title — same fields as the website's WatchlistItem / LikedItem
/// (and the gateway's watchlist / likes rows).
class LibraryItem {
  const LibraryItem({required this.id, this.tmdbId, this.title, this.posterImgURL, this.tmdbRating, this.type, this.videoId});

  final String id;
  final String? tmdbId;
  final String? title;
  final String? posterImgURL;
  final String? tmdbRating;

  /// "MOVIE" or "TV-SHOW" (the backend's spelling).
  final String? type;
  final String? videoId;

  bool get isSeries => type == 'TV-SHOW' || type == 'SERIES';

  factory LibraryItem.fromRecord(CinemaRecord record) {
    final segments = (record.videoURL ?? '').split('/');
    return LibraryItem(
      id: recordKey(record),
      tmdbId: record.tmdbId,
      title: record.title,
      posterImgURL: record.posterImgURL,
      tmdbRating: record.tmdbRating,
      type: record.isSeries ? 'TV-SHOW' : 'MOVIE',
      videoId: record.isSeries ? '' : (segments.length > 5 ? segments[5] : ''),
    );
  }

  /// Local storage uses `id`, the gateway `recordId`.
  factory LibraryItem.fromJson(Map<String, dynamic> json) => LibraryItem(
    id: '${json['recordId'] ?? json['id'] ?? ''}',
    tmdbId: json['tmdbId'] as String?,
    title: json['title'] as String?,
    posterImgURL: json['posterImgURL'] as String?,
    tmdbRating: json['tmdbRating'] as String?,
    type: json['type'] as String?,
    videoId: json['videoId'] as String?,
  );

  Map<String, dynamic> toLocalJson() => {
    'id': id,
    'tmdbId': tmdbId,
    'title': title,
    'posterImgURL': posterImgURL,
    'tmdbRating': tmdbRating,
    'type': type,
    'videoId': videoId,
  };

  Map<String, dynamic> toServerJson() => {...toLocalJson()..remove('id'), 'recordId': id};
}

/// The one identity a title is known by across watchlist / likes /
/// playlists: its TMDB id (website: getRecordKey) — never the table uuid,
/// which differs between the trending and catalog copies of a title.
String recordKey(CinemaRecord record) => record.isSeries ? (record.tmdbId ?? '') : getMovieId(record);

bool _matches(LibraryItem item, String key) => item.id == key || (item.tmdbId != null && item.tmdbId == key);

const _storageKey = 'AURORAFLIX_WATCHLIST';
const maxWatchlistItems = 20;

/// The watchlist (website: useWatchlist): on the device while signed out
/// (same key and 20-title cap as the site's localStorage), synced to
/// lumo-user-svc through the gateway once signed in. Newest first.
/// `null` while loading.
class WatchlistController extends Notifier<List<LibraryItem>?> {
  @override
  List<LibraryItem>? build() {
    final auth = ref.watch(authProvider);
    if (!auth.isLoaded) return null;
    if (!auth.isSignedIn) return _readLocal();
    Future.microtask(_refreshServer);
    return null;
  }

  List<LibraryItem> _readLocal() {
    final raw = ref.read(sharedPreferencesProvider).getString(_storageKey);
    if (raw == null) return const [];
    try {
      final stored = (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().map(LibraryItem.fromJson).toList();
      return stored.reversed.toList();
    } catch (_) {
      return const [];
    }
  }

  void _writeLocal(List<LibraryItem> newestFirst) {
    ref.read(sharedPreferencesProvider).setString(_storageKey, jsonEncode(newestFirst.reversed.map((item) => item.toLocalJson()).toList()));
    state = newestFirst;
  }

  Future<void> _refreshServer() async {
    final data = await ref.read(apiClientProvider).getJson('/watchlist');
    state = ApiClient.unwrapList(data).map(LibraryItem.fromJson).toList();
  }

  bool get _signedIn => ref.read(authProvider).isSignedIn;

  bool has(String key) => (state ?? const []).any((item) => _matches(item, key));

  Future<void> add(LibraryItem item) async {
    if (item.id.isEmpty || has(item.id)) return;
    if (_signedIn) {
      state = [item, ...?state];
      await ref.read(apiClientProvider).send('POST', '/watchlist', body: item.toServerJson());
      await _refreshServer();
      return;
    }
    final list = [item, ...?state];
    _writeLocal(list.length > maxWatchlistItems ? list.sublist(0, maxWatchlistItems) : list);
  }

  Future<void> remove(String id) async {
    if (_signedIn) {
      state = state?.where((item) => item.id != id).toList();
      await ref.read(apiClientProvider).send('DELETE', '/watchlist/${Uri.encodeComponent(id)}');
      await _refreshServer();
      return;
    }
    _writeLocal((state ?? const []).where((item) => item.id != id).toList());
  }
}

final watchlistProvider = NotifierProvider<WatchlistController, List<LibraryItem>?>(WatchlistController.new);

enum LikeResult { ok, limit, error }

/// Liked titles (website: useLikes) — signed-in only, no local fallback.
/// `null` while loading.
class LikesController extends Notifier<List<LibraryItem>?> {
  @override
  List<LibraryItem>? build() {
    final auth = ref.watch(authProvider);
    if (!auth.isLoaded) return null;
    if (!auth.isSignedIn) return const [];
    Future.microtask(_refresh);
    return null;
  }

  Future<void> _refresh() async {
    final data = await ref.read(apiClientProvider).getJson('/likes');
    state = ApiClient.unwrapList(data).map(LibraryItem.fromJson).toList();
  }

  bool has(String key) => (state ?? const []).any((item) => _matches(item, key));

  Future<LikeResult> add(LibraryItem item) async {
    if (!ref.read(authProvider).isSignedIn) return LikeResult.error;
    final response = await ref.read(apiClientProvider).send('POST', '/likes', body: item.toServerJson());
    if (response == null) return LikeResult.error;
    if (response.statusCode == 409) return LikeResult.limit;
    if (response.statusCode >= 300) return LikeResult.error;
    await _refresh();
    return LikeResult.ok;
  }

  Future<void> remove(String id) async {
    if (!ref.read(authProvider).isSignedIn) return;
    state = state?.where((item) => !_matches(item, id)).toList();
    await ref.read(apiClientProvider).send('DELETE', '/likes/${Uri.encodeComponent(id)}');
    await _refresh();
  }
}

final likesProvider = NotifierProvider<LikesController, List<LibraryItem>?>(LikesController.new);
