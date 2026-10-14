import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

/// Where every backend call goes. Defaults to the deployed gateway; pass
/// `--dart-define=API_BASE_URL=http://localhost:8080` to point a run at a
/// local one instead.
///
/// The app talks to lumo-api-gateway directly — unlike the website, which
/// proxies through its own /api routes. A native app sends no `Origin`
/// header, so the gateway's CORS allowlist never applies to it; and for
/// browser testing, `flutter run -d chrome --web-port 5173` serves from
/// http://localhost:5173, which that allowlist already includes.
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://lumo-api-gateway.onrender.com');

/// Same gateway, ws(s):// scheme — for the friends/presence socket.
final String wsBaseUrl = apiBaseUrl.replaceFirst(RegExp('^http'), 'ws');

/// Clerk's Frontend API for the production instance (the publishable key
/// pk_live_Y2xlcmsuYXVyb3JhZmxpeC5jbG91ZCQ decodes to this host).
///
/// That instance only accepts browser requests from auroraflix.cloud, so the
/// debug browser build goes through tool/clerk_dev_proxy.mjs instead — run
/// it next to `flutter run -d chrome`. Native builds talk to Clerk directly
/// (they send no Origin header). `--dart-define=CLERK_FAPI_URL=...` wins.
final String clerkFrontendApi = const String.fromEnvironment('CLERK_FAPI_URL').isNotEmpty
    ? const String.fromEnvironment('CLERK_FAPI_URL')
    : (kIsWeb && kDebugMode ? 'http://localhost:5174' : 'https://clerk.auroraflix.cloud');

/// The name Clerk shows in its own copy ("Sign in to Auroraflix.cloud").
const String clerkApplicationName = 'Auroraflix.cloud';

/// The website, for the few things that only live in its own /api routes
/// (AI assistant, subtitles) and for links out (pricing, privacy).
const String siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://auroraflix.cloud');
