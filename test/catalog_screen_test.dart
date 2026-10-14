import 'package:auroraflix/core/i18n/locale.dart';
import 'package:auroraflix/models/models.dart';
import 'package:auroraflix/router.dart';
import 'package:auroraflix/screens/catalog/catalog_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visibility_detector/visibility_detector.dart';

void main() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  testWidgets('catalog screen settles with a full page of results', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final records = [
      for (var i = 0; i < 30; i++)
        CinemaRecord(id: '$i', type: RecordType.movie, title: 'Movie $i', tmdbRating: '7.$i', releaseDate: '2026-01-01', tmdbId: '$i'),
    ];
    const query = CatalogQuery(type: RecordType.movie);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          catalogPageProvider(query).overrideWith((ref) async => CatalogPage(records: records, totalPages: 40)),
        ],
        child: const MaterialApp(home: Scaffold(body: CatalogScreen(query: query))),
      ),
    );
    var frames = 0;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      frames++;
    }
    debugPrint('pumped $frames frames, hasScheduledFrame=${tester.binding.hasScheduledFrame}');
    expect(find.text('Movie 0'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
