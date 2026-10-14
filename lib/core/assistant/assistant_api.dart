import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../models/models.dart';
import '../auth/auth_controller.dart';
import '../config.dart';

/// A title the assistant named, as found in our catalog (website:
/// ResolvedCard from lib/assistant-tools.ts).
class AssistantCard {
  const AssistantCard({
    required this.type,
    required this.id,
    required this.title,
    this.posterImgURL,
    this.tmdbRating,
    this.year,
    this.description,
    this.genres,
    this.images = const [],
  });

  final RecordType type;

  /// What the details screen is opened by (a movie's / series' TMDB id).
  final String id;
  final String title;
  final String? posterImgURL;
  final String? tmdbRating;
  final String? year;
  final String? description;
  final String? genres;
  final List<String> images;

  factory AssistantCard.fromJson(Map<String, dynamic> json) => AssistantCard(
    type: json['mediaType'] == 'series' ? RecordType.series : RecordType.movie,
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    posterImgURL: json['posterImgURL'] as String?,
    tmdbRating: json['tmdbRating'] as String?,
    year: json['year'] as String?,
    description: json['description'] as String?,
    genres: json['genres'] as String?,
    images: (json['images'] as List? ?? const []).whereType<String>().toList(),
  );
}

class AssistantMessage {
  const AssistantMessage({required this.fromUser, required this.content, this.cards = const [], this.isError = false});

  final bool fromUser;
  final String content;
  final List<AssistantCard> cards;
  final bool isError;
}

enum AssistantFailure { rateLimited, generic }

class AssistantException implements Exception {
  const AssistantException(this.failure);

  final AssistantFailure failure;
}

const _maxHistorySent = 8;

/// The website's assistant route (Gemini, the person's likes and watchlist,
/// catalog lookups) — called straight from the app with the Clerk session
/// token, so both share one implementation.
class AssistantApi {
  AssistantApi(this._getToken);

  final Future<String?> Function() _getToken;

  Future<AssistantMessage> send(String message, String locale, List<AssistantMessage> history) async {
    final token = await _getToken();
    if (token == null) throw const AssistantException(AssistantFailure.generic);
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$siteUrl/api/assistant'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({
              'message': message,
              'locale': locale,
              'history': [
                for (final item in history.skip(history.length > _maxHistorySent ? history.length - _maxHistorySent : 0))
                  {'role': item.fromUser ? 'user' : 'assistant', 'content': item.content},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const AssistantException(AssistantFailure.generic);
    }
    if (response.statusCode == 429) throw const AssistantException(AssistantFailure.rateLimited);
    if (response.statusCode != 200) throw const AssistantException(AssistantFailure.generic);
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return AssistantMessage(
        fromUser: false,
        content: '${data['message'] ?? ''}',
        cards: (data['titles'] as List? ?? const []).whereType<Map<String, dynamic>>().map(AssistantCard.fromJson).toList(),
      );
    } catch (_) {
      throw const AssistantException(AssistantFailure.generic);
    }
  }
}

final assistantApiProvider = Provider<AssistantApi>((ref) => AssistantApi(() => ref.read(authProvider.notifier).getToken()));
