import 'package:auroraflix/core/i18n/locale.dart';
import 'package:auroraflix/models/models.dart';
import 'package:auroraflix/widgets/cinema_record_card.dart';
import 'package:auroraflix/widgets/pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('catalog grid and pagination lay out and settle', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final records = [
      for (var i = 0; i < 30; i++)
        CinemaRecord(id: '$i', type: RecordType.movie, title: 'Movie $i', tmdbRating: '7.$i', releaseDate: '2026-01-01', tmdbId: '$i'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                CinemaRecordGrid(records: records),
                PaginationControls(current: 1, total: 12, onPage: (_) {}),
              ],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Movie 0'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
