import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import 'api_client.dart';

enum ReactionType { like, dislike }

/// Comments under a title — the gateway endpoints the website reaches
/// through app/api/comments and app/api/backend. The gateway takes the
/// author from the session token, never from the request body.
class CommentsApi {
  CommentsApi(this._api);

  final ApiClient _api;

  static const pageSize = 10;

  String _kind(RecordType type) => type == RecordType.series ? 'series' : 'movie';

  /// [page] is 1-based.
  Future<List<Comment>> page(RecordType type, String recordId, int page) async {
    final data = await _api.getJson('/get-next-10-${_kind(type)}-comments', {'order': page, 'currentCinemaRecordId': recordId});
    return ApiClient.unwrapList(data).map(Comment.fromJson).toList();
  }

  Future<Map<String, CommentReactions>> reactions(RecordType type, List<String> commentIds) async {
    if (commentIds.isEmpty) return const {};
    final data = await _api.getJson('/get-${_kind(type)}-comments-reactions', {'commentIds': commentIds.join(',')});
    if (data is! Map<String, dynamic>) return const {};
    return {
      for (final entry in data.entries)
        if (entry.value is Map<String, dynamic>) entry.key: CommentReactions.fromJson(entry.value as Map<String, dynamic>),
    };
  }

  Future<bool> post(RecordType type, String recordId, String text) async {
    final response = await _api.send('POST', '/post-${_kind(type)}-comment', body: {'commentText': text, 'cinemaRecordId': recordId});
    return response != null && response.statusCode < 300;
  }

  Future<bool> update(RecordType type, String recordId, String commentId, String text) async {
    final response = await _api.send(
      'PUT',
      '/update-${_kind(type)}-comment',
      params: {'commentId': commentId, 'movieId': recordId},
      body: {'commentText': text},
    );
    return response != null && response.statusCode < 300;
  }

  Future<bool> delete(RecordType type, String recordId, String commentId) async {
    final response = await _api.send('DELETE', '/delete-${_kind(type)}-comment', params: {'commentId': commentId, 'movieId': recordId});
    return response != null && response.statusCode < 300;
  }

  Future<bool> react(RecordType type, String commentId, ReactionType reaction) async {
    final response = await _api.send(
      'PUT',
      '/react-${_kind(type)}-comment',
      params: {'commentId': commentId, 'reactionType': reaction == ReactionType.like ? 'LIKE' : 'DISLIKE'},
    );
    return response != null && response.statusCode < 300;
  }
}

final commentsApiProvider = Provider<CommentsApi>((ref) => CommentsApi(ref.watch(apiClientProvider)));
