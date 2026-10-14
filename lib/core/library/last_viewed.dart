import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../i18n/locale.dart';

/// A "Last Viewed" entry (website: types/last-viewed.ts).
class LastViewed {
  const LastViewed({
    required this.type,
    required this.title,
    required this.tmdbRating,
    this.tmdbId,
    this.seriesId,
    this.posterURL,
    this.videoURL,
    this.releaseDate = '',
  });

  final RecordType type;
  final String title;
  final String tmdbRating;
  final String? tmdbId;
  final String? seriesId;
  final String? posterURL;
  final String? videoURL;
  final String releaseDate;

  factory LastViewed.fromRecord(CinemaRecord record) => LastViewed(
    type: record.type,
    title: record.title,
    tmdbRating: record.tmdbRating,
    tmdbId: record.tmdbId,
    seriesId: record.isSeries ? record.id : null,
    posterURL: record.posterImgURL,
    videoURL: record.videoURL,
    releaseDate: record.releaseDate ?? '',
  );

  factory LastViewed.fromJson(Map<String, dynamic> json) => LastViewed(
    type: json['type'] == 'SERIES' ? RecordType.series : RecordType.movie,
    title: '${json['title'] ?? ''}',
    tmdbRating: '${json['tmdbRating'] ?? ''}',
    tmdbId: json['tmdbId'] as String?,
    seriesId: json['seriesId'] as String?,
    posterURL: json['posterURL'] as String?,
    videoURL: json['videoURL'] as String?,
    releaseDate: '${json['releaseDate'] ?? ''}',
  );

  Map<String, dynamic> toJson() => {
    'type': type == RecordType.series ? 'SERIES' : 'MOVIE',
    'tmdbId': tmdbId,
    'seriesId': ?seriesId,
    'posterURL': posterURL,
    'title': title,
    'tmdbRating': tmdbRating,
    'videoURL': videoURL,
    'releaseDate': releaseDate,
  };

  /// The TMDB id a details screen opens by (legacy movie rows only carry it
  /// at the end of videoURL).
  String get detailsId => tmdbId ?? RegExp(r'/(\d+)$').firstMatch(videoURL ?? '')?.group(1) ?? '';
}

const _storageKey = 'AURORAFLIX-LAST-VIEWED';
const _maxItems = 20;

/// Recently opened titles (website: useLastViewed) — on the device while
/// signed out, in lumo-user-svc once signed in. Newest first; `null` while
/// loading.
class LastViewedController extends Notifier<List<LastViewed>?> {
  @override
  List<LastViewed>? build() {
    final auth = ref.watch(authProvider);
    if (!auth.isLoaded) return null;
    if (!auth.isSignedIn) return _readLocal().reversed.toList();
    Future.microtask(_refreshServer);
    return null;
  }

  List<LastViewed> _readLocal() {
    final raw = ref.read(sharedPreferencesProvider).getString(_storageKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().map(LastViewed.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _refreshServer() async {
    final data = await ref.read(apiClientProvider).getJson('/last-viewed');
    state = ApiClient.unwrapList(data).map(LastViewed.fromJson).toList();
  }

  /// Called when a details screen opens. Re-viewing something already on
  /// the list bumps it to the top instead of duplicating it.
  Future<void> record(CinemaRecord record) async {
    final entry = LastViewed.fromRecord(record);
    if (ref.read(authProvider).isSignedIn) {
      await ref.read(apiClientProvider).send('POST', '/last-viewed', body: entry.toJson());
      await _refreshServer();
      return;
    }
    final oldestFirst = _readLocal().where((item) => item.title != entry.title).toList()..add(entry);
    final trimmed = oldestFirst.length > _maxItems ? oldestFirst.sublist(oldestFirst.length - _maxItems) : oldestFirst;
    await ref.read(sharedPreferencesProvider).setString(_storageKey, jsonEncode(trimmed.map((item) => item.toJson()).toList()));
    state = trimmed.reversed.toList();
  }
}

final lastViewedProvider = NotifierProvider<LastViewedController, List<LastViewed>?>(LastViewedController.new);
