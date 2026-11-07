import 'dart:convert';

import 'package:auroraflix/core/api/api_client.dart';
import 'package:auroraflix/core/i18n/locale.dart';
import 'package:auroraflix/core/library/watch_progress.dart';
import 'package:auroraflix/screens/details/player_telemetry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signed out: the positions stay on the device.
final signedOut = progressAccountProvider.overrideWithValue((known: true, userId: null));

void main() {
  late ProviderContainer container;
  late WatchProgressController progress;
  const movie = ProgressTarget.movie('27205');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs), signedOut]);
    progress = container.read(watchProgressProvider.notifier);
  });

  tearDown(() => container.dispose());

  Map<String, WatchProgress> saved() => container.read(watchProgressProvider);

  group('saving', () {
    test('ignores a look at the opening and a pre-roll ad', () {
      progress.save(movie, 10, 8000);
      progress.save(movie, 50, 60);
      expect(saved(), isEmpty);
    });

    test('rewinds a little to resume, and a finished title starts over', () {
      progress.save(movie, 2827, 8888);
      expect(resumeSecondsFrom(saved(), movie), 2822);
      progress.save(movie, 8500, 8888);
      expect(saved()[movie.key]!.finished, isTrue);
      expect(resumeSecondsFrom(saved(), movie), isNull);
    });

    test('keeps a known runtime when a save has none', () {
      progress.save(movie, 100, 8888);
      progress.save(movie, 110, null);
      expect(saved()[movie.key]!.duration, 8888);
    });

    test('survives a restart', () async {
      progress.save(movie, 100, 8888, title: 'Генезис', image: 'https://x/y.jpg', approximate: true);
      final prefs = await SharedPreferences.getInstance();
      final fresh = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs), signedOut]);
      addTearDown(fresh.dispose);
      final entry = fresh.read(watchProgressProvider)[movie.key]!;
      expect(entry.seconds, 100);
      expect(entry.title, 'Генезис');
      expect(entry.approximate, isTrue);
    });
  });

  group('continue watching', () {
    test('one entry per title, without what is finished', () async {
      progress.save(const ProgressTarget.episode('1396', '2', '4'), 500, 2800);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      progress.save(const ProgressTarget.episode('1396', '2', '5'), 900, 2800);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      progress.save(const ProgressTarget.movie('1'), 7000, 7100);
      final list = continueWatching(saved());
      expect(list, hasLength(1));
      expect(list.single.tmdbId, '1396');
      expect(list.single.season, '2');
      expect(list.single.episode, '5');
    });

    test('dismiss keeps the finished episodes', () {
      progress.save(const ProgressTarget.episode('1396', '2', '4'), 2700, 2800);
      progress.save(const ProgressTarget.episode('1396', '2', '5'), 900, 2800);
      progress.dismiss(isSeries: true, tmdbId: '1396');
      expect(saved().keys, ['tv:1396:2:4']);
    });
  });

  group('signed in', () {
    late ProviderContainer account;
    late List<http.Request> requests;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      requests = [];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {'key': 'movie:1', 'seconds': 600, 'duration': 6000, 'finished': false, 'approximate': false, 'title': 'От профила', 'updatedAt': 1},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('', 204);
      });
      account = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(container.read(sharedPreferencesProvider)),
          progressAccountProvider.overrideWithValue((known: true, userId: 'user_1')),
          apiClientProvider.overrideWithValue(ApiClient(httpClient: client)),
        ],
      );
    });

    tearDown(() => account.dispose());

    test("uses the account's positions and leaves the device's alone", () async {
      // Saved on this device while signed out.
      progress.save(movie, 100, 8888);

      expect(account.read(watchProgressReadyProvider), isFalse);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(account.read(watchProgressReadyProvider), isTrue);
      expect(account.read(watchProgressProvider).keys, ['movie:1']);

      account.read(watchProgressProvider.notifier).save(const ProgressTarget.movie('2'), 300, 7000);
      await Future<void>.delayed(Duration.zero);
      final put = requests.singleWhere((request) => request.method == 'PUT');
      expect(jsonDecode(put.body)['key'], 'movie:2');
      expect(account.read(watchProgressProvider).keys, containsAll(['movie:1', 'movie:2']));

      account.read(watchProgressProvider.notifier).dismiss(isSeries: false, tmdbId: '1');
      await Future<void>.delayed(Duration.zero);
      expect(requests.last.method, 'DELETE');
      expect(requests.last.url.queryParametersAll['key'], ['movie:1']);

      // Nothing of the account's reached the device, nor the device's the account.
      final prefs = await SharedPreferences.getInstance();
      final fresh = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs), signedOut]);
      addTearDown(fresh.dispose);
      expect(fresh.read(watchProgressProvider).keys, [movie.key]);
      expect(requests.where((request) => request.body.contains('27205')), isEmpty);
    });
  });

  test('formats playback time', () {
    expect(formatPlaybackTime(65), '1:05');
    expect(formatPlaybackTime(8880), '2:28:00');
  });

  group('player messages', () {
    test('EmbedMaster, by its own marker from any origin', () {
      const time = {'source': 'embedmaster_player', 'event': 'time', 'info': 2830.5};
      expect(extractProgress(5, 'https://embdmstrplayer.com', time)!.currentTime, 2830.5);
      expect(extractProgress(5, 'https://other.example', {'source': 'embedmaster_player', 'event': 'duration', 'info': 8888})!.duration, 8888);
      expect(extractProgress(5, 'https://embdmstrplayer.com', {'source': 'embedmaster_player', 'event': 'play'}), isNull);
      expect(isEmbedmasterReady({'source': 'embedmaster_player', 'event': 'duration', 'info': 8888}), isTrue);
    });

    test('VidFast shape, only from its own origin', () {
      const message = {
        'type': 'PLAYER_EVENT',
        'data': {'event': 'timeupdate', 'currentTime': 20.2, 'duration': 8886.2, 'season': 2, 'episode': 5},
      };
      final update = extractProgress(2, 'https://vidfast.vc', message)!;
      expect(update.currentTime, 20.2);
      expect(update.season, '2');
      expect(extractProgress(2, 'https://evil.example', message), isNull);
    });

    test('our БГ аудио page', () {
      final update = extractProgress(7, 'https://auroraflix.cloud', {'type': 'BG_AUDIO_PROGRESS', 'currentTime': 12, 'duration': 6000})!;
      expect(update.currentTime, 12);
      expect(update.duration, 6000);
    });

    test('the recorder follows an episode change', () {
      final saves = <(String, double)>[];
      final recorder = WatchProgressRecorder(
        target: const ProgressTarget.episode('1', '1', '1'),
        provider: 2,
        save: (target, seconds, duration) => saves.add((target.key, seconds)),
      );
      Map<String, Object> tick(num time, num duration, int episode) => {
        'type': 'PLAYER_EVENT',
        'data': {'currentTime': time, 'duration': duration, 'season': 1, 'episode': episode},
      };
      recorder.onMessage('https://vidfast.vc', tick(100, 2800, 1));
      recorder.onMessage('https://vidfast.vc', tick(50, 2800, 2));
      recorder.flush();
      expect(saves, [('tv:1:1:1', 100.0), ('tv:1:1:2', 50.0)]);
    });
  });
}
