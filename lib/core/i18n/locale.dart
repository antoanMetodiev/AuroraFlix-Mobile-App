import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';
import 'dictionary.g.dart';

enum AppLocale { en, bg }

/// Loaded once in main() before the first frame, so everything that needs a
/// saved setting can read it synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('Overridden in main()'));

const _localeKey = 'auroraflix_locale';

/// Same rule as the website's resolveInitialLocale(): a saved choice wins,
/// otherwise Bulgarian for a Bulgarian device and English for everyone else.
class LocaleController extends Notifier<AppLocale> {
  @override
  AppLocale build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_localeKey);
    if (saved == 'bg') return AppLocale.bg;
    if (saved == 'en') return AppLocale.en;

    final deviceLanguages = PlatformDispatcher.instance.locales.map((locale) => locale.languageCode);
    return deviceLanguages.contains('bg') ? AppLocale.bg : AppLocale.en;
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
    var text = (dictionary[key] ?? appStrings[key])?[locale.name] ?? key;
    vars?.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));
    return text;
  }

  /// Genre names come from the backend in English; shown translated.
  String genre(String name) => genreTranslations[name]?[locale.name] ?? name;
}

final translatorProvider = Provider<Translator>((ref) => Translator(ref.watch(localeProvider)));
