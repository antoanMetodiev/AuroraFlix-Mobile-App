import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'core/i18n/locale.dart';
import 'core/theme.dart';
import 'core/tv.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Visibility checks every 150ms instead of 500ms: lazy posters
  // (AuroraImage.lazy) and scroll entrances react without a visible lag.
  VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 150);

  // Draw edge to edge behind transparent system bars — the header and tab
  // bar handle the safe areas themselves.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Month names for comment dates, in both UI languages.
  await Future.wait([
    for (final locale in ['bg', 'en_US', 'el', 'es']) initializeDateFormatting(locale),
  ]);
  final preferences = await SharedPreferences.getInstance();
  final isTv = await detectTv();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences), isTvProvider.overrideWithValue(isTv)],
      child: const AuroraFlixApp(),
    ),
  );
}

class AuroraFlixApp extends ConsumerWidget {
  const AuroraFlixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keyed by the language, so switching it rebuilds the whole app from
    // scratch on the current screen — every screen loads its data again, in
    // the new language (titles, descriptions, artwork), like the website's
    // reload.
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      key: ValueKey(locale),
      title: 'AuroraFlix',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
