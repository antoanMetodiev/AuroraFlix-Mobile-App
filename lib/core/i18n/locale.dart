import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'app_strings.dart';
import 'dictionary.g.dart';

/// The UI languages, in the order the language picker lists them (same as
/// the website's LOCALES).
enum AppLocale { bg, en, el, es }

AppLocale? _parseLocale(String? value) {
  for (final locale in AppLocale.values) {
    if (locale.name == value) return locale;
  }
  return null;
}

/// Loaded once in main() before the first frame, so everything that needs a
/// saved setting can read it synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('Overridden in main()'));

const _localeKey = 'auroraflix_locale';

/// Same rule as the website's detectLocale(): a saved choice wins. On the
/// very first launch the phone's own language is a quick first guess, then
/// the website's /api/geo answers by the phone's country (Bulgaria → bg,
/// Greece/Cyprus → el, Spanish-speaking countries → es, elsewhere → en) and
/// that is saved — so it stays put from then on, until the user picks another.
class LocaleController extends Notifier<AppLocale> {
  @override
  AppLocale build() {
    final saved = _parseLocale(ref.read(sharedPreferencesProvider).getString(_localeKey));
    if (saved != null) return saved;

    Future.microtask(_detectFromCountry);
    for (final locale in PlatformDispatcher.instance.locales) {
      final match = _parseLocale(locale.languageCode);
      if (match != null) return match;
    }
    return AppLocale.en;
  }

  Future<void> _detectFromCountry() async {
    final preferences = ref.read(sharedPreferencesProvider);
    try {
      final response = await http.get(Uri.parse('$siteUrl/api/geo')).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return;
      final detected = _parseLocale((jsonDecode(response.body) as Map<String, dynamic>)['locale'] as String?);
      // The user may have picked a language while this was in flight.
      if (detected == null || preferences.getString(_localeKey) != null) return;
      set(detected);
    } catch (_) {
      // Offline or the site is down: keep the device-language guess, and try
      // again next launch (nothing was saved).
    }
  }

  void set(AppLocale locale) {
    state = locale;
    ref.read(sharedPreferencesProvider).setString(_localeKey, locale.name);
  }
}

final localeProvider = NotifierProvider<LocaleController, AppLocale>(LocaleController.new);

/// `t('nav.home')` / `t('subscription.renews', {'date': ...})` — the website's
/// useTranslation().t, reading the same generated dictionary. An unknown key
/// comes back as itself, so a missing string is visible instead of blank.
class Translator {
  const Translator(this.locale);

  final AppLocale locale;

  String call(String key, [Map<String, Object>? vars]) {
    final entry = dictionary[key] ?? appStrings[key];
    var text = entry?[locale.name] ?? entry?['en'] ?? key;
    vars?.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));
    return text;
  }

  /// Genre names come from the backend in English; shown translated.
  String genre(String name) => genreTranslations[name]?[locale.name] ?? name;

  /// The language's own name for itself, for the language picker.
  static const nativeNames = {AppLocale.bg: 'Български', AppLocale.en: 'English', AppLocale.el: 'Ελληνικά', AppLocale.es: 'Español'};
}

final translatorProvider = Provider<Translator>((ref) => Translator(ref.watch(localeProvider)));
