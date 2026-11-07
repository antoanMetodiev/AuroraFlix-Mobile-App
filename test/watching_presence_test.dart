import 'dart:convert';

import 'package:auroraflix/core/api/api_client.dart';
import 'package:auroraflix/core/friends/friends_api.dart';
import 'package:auroraflix/core/friends/watching_presence.dart';
import 'package:auroraflix/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> sent;
  late WatchingPresence presence;

  setUp(() {
    sent = [];
    final client = MockClient((request) async {
      if (request.method == 'PUT') sent.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('', 204);
    });
    presence = WatchingPresence(FriendsApi(ApiClient(httpClient: client, tokenProvider: () async => 'token')))..signedIn = true;
  });

  tearDown(() => presence.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('tells friends the minute and a pause right away', () async {
    presence.update(const WatchingTarget(tmdbId: '1', type: RecordType.series, title: 'Генезис', season: 1, episode: 2));
    await settle();
    expect(sent.single.containsKey('position'), isFalse);

    presence.onPlayback(currentTime: 2820, duration: 3600, playing: true);
    presence.onPlayback(currentTime: 2821, playing: false);
    await settle();
    expect(sent.last['position'], 2821);
    expect(sent.last['duration'], 3600);
    expect(sent.last['paused'], isTrue);
    expect(sent.last['episode'], 2);

    // The player moved on to the next episode by itself.
    presence.onPlayback(currentTime: 5, playing: true, season: '1', episode: '3');
    await settle();
    expect(sent.last['episode'], 3);
    expect(sent.last['position'], 5);
    expect(sent.last['paused'], isFalse);
  });
}
