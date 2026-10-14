import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/i18n/locale.dart';
import 'core/theme.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  await Future.wait([initializeDateFormatting('bg'), initializeDateFormatting('en_US')]);
  final preferences = await SharedPreferences.getInstance();

  runApp(ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(preferences)], child: const AuroraFlixApp()));
}

class AuroraFlixApp extends StatelessWidget {
  const AuroraFlixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(title: 'AuroraFlix', debugShowCheckedModeBanner: false, theme: buildAppTheme(), routerConfig: appRouter);
  }
}
