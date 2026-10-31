import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _device = MethodChannel('auroraflix/device');

/// Whether the app runs on an Android TV (UiModeManager / leanback, see
/// MainActivity). The browser build has no TV, so there `?tv=1` in the
/// address turns the TV layout on for testing at 1920×1080.
Future<bool> detectTv() async {
  if (kIsWeb) return Uri.base.queryParameters['tv'] == '1';
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await _device.invokeMethod<bool>('isTv') ?? false;
  } catch (_) {
    return false;
  }
}

/// Read once in main() and fixed for the app's lifetime.
final isTvProvider = Provider<bool>((ref) => throw UnimplementedError('Overridden in main()'));
