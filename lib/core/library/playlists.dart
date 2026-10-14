import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import 'watchlist.dart';

class Playlist {
  const Playlist({required this.id, required this.name, required this.isPublic, required this.itemCount, this.ownerId});

  final String id;
  final String name;
  final bool isPublic;
  final int itemCount;
  final String? ownerId;

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: '${json['id']}',
    name: '${json['name'] ?? ''}',
    isPublic: json['isPublic'] == true,
    itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
    ownerId: json['ownerId'] as String?,
  );
}

enum AddToPlaylistResult { ok, limit, error }

/// Playlist calls on the gateway (website: lib/playlists.ts). Items use the
/// same shape as watchlist / likes rows.
class PlaylistsApi {
  PlaylistsApi(this._api);

  final ApiClient _api;

  String _id(String id) => Uri.encodeComponent(id);

  Future<List<Playlist>> mine() async => ApiClient.unwrapList(await _api.getJson('/playlists')).map(Playlist.fromJson).toList();

  Future<Playlist?> create(String name, bool isPublic) async {
    final response = await _api.send('POST', '/playlists', body: {'name': name, 'isPublic': isPublic});
    if (response == null || response.statusCode >= 300) return null;
    return Playlist(id: '', name: name, isPublic: isPublic, itemCount: 0);
  }

  Future<bool> update(String id, String name, bool isPublic) async {
    final response = await _api.send('PATCH', '/playlists/${_id(id)}', body: {'name': name, 'isPublic': isPublic});
    return response != null && response.statusCode < 300;
  }

  Future<bool> delete(String id) async {
    final response = await _api.send('DELETE', '/playlists/${_id(id)}');
    return response != null && response.statusCode < 300;
  }

  Future<List<LibraryItem>> items(String id) async =>
      ApiClient.unwrapList(await _api.getJson('/playlists/${_id(id)}/items')).map(LibraryItem.fromJson).toList();

  Future<AddToPlaylistResult> addItem(String id, LibraryItem item) async {
    final response = await _api.send('POST', '/playlists/${_id(id)}/items', body: item.toServerJson());
    if (response == null) return AddToPlaylistResult.error;
    if (response.statusCode == 409) return AddToPlaylistResult.limit;
    return response.statusCode < 300 ? AddToPlaylistResult.ok : AddToPlaylistResult.error;
  }

  Future<bool> removeItem(String id, String recordId) async {
    final response = await _api.send('DELETE', '/playlists/${_id(id)}/items/${_id(recordId)}');
    return response != null && response.statusCode < 300;
  }
}

final playlistsApiProvider = Provider<PlaylistsApi>((ref) => PlaylistsApi(ref.watch(apiClientProvider)));

/// Your playlists (website: usePlaylists) — signed-in only; an empty list
/// while signed out. `null` while loading.
class PlaylistsController extends Notifier<List<Playlist>?> {
  @override
  List<Playlist>? build() {
    final auth = ref.watch(authProvider);
    if (!auth.isLoaded) return null;
    if (!auth.isSignedIn) return const [];
    Future.microtask(refresh);
    return null;
  }

  PlaylistsApi get _api => ref.read(playlistsApiProvider);

  Future<void> refresh() async => state = await _api.mine();

  Future<bool> create(String name, bool isPublic) async {
    final created = await _api.create(name, isPublic);
    if (created != null) await refresh();
    return created != null;
  }

  Future<bool> update(String id, String name, bool isPublic) async {
    final ok = await _api.update(id, name, isPublic);
    if (ok) await refresh();
    return ok;
  }

  Future<void> delete(String id) async {
    if (await _api.delete(id)) await refresh();
  }
}

final playlistsProvider = NotifierProvider<PlaylistsController, List<Playlist>?>(PlaylistsController.new);
