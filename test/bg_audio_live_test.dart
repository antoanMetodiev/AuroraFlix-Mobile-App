@Tags(['live'])
library;

import 'package:auroraflix/core/bg_audio.dart';
import 'package:flutter_test/flutter_test.dart';

// Hits VidHide for real: flutter test --tags live test/bg_audio_live_test.dart
void main() {
  test('resolves a VidHide embed to its master playlist', () async {
    final master = await resolveVidhideMaster('https://morencius.com/embed/su8eey9dalgv');
    expect(master, isNotNull);
    expect(master, contains('master.m3u8'));
  });
}
