import 'package:auroraflix/core/api/api_client.dart';
import 'package:auroraflix/core/auth/auth_controller.dart';
import 'package:auroraflix/core/auth/clerk_models.dart';
import 'package:auroraflix/core/i18n/locale.dart';
import 'package:auroraflix/models/models.dart';
import 'package:auroraflix/router.dart';
import 'package:auroraflix/screens/catalog/catalog_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _SignedIn extends AuthController {
  @override
  AuthState build() => const AuthState.signedIn(ClerkSession(id: 's', status: 'active', user: ClerkUser(id: 'u')));

  @override
  Future<String?> getToken() async => 'token';
}

void main() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  testWidgets('catalog screen settles while signed in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('[]', 200);
    });
    final records = [
      for (var i = 0; i < 30; i++)
        CinemaRecord(id: '$i', type: RecordType.movie, title: 'Movie $i', tmdbRating: '7.$i', releaseDate: '2026-01-01', tmdbId: '$i'),
    ];
    const query = CatalogQuery(type: RecordType.movie);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authProvider.overrideWith(_SignedIn.new),
          apiClientProvider.overrideWithValue(ApiClient(httpClient: client, tokenProvider: () async => 'token')),
          catalogPageProvider(query).overrideWith((ref) async => CatalogPage(records: records, totalPages: 40)),
        ],
        child: const MaterialApp(home: Scaffold(body: CatalogScreen(query: query))),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    debugPrint('requests made: $requests');
    expect(find.text('Movie 0'), findsOneWidget);
    expect(requests, lessThan(20));
  }, timeout: const Timeout(Duration(seconds: 90)));
}
