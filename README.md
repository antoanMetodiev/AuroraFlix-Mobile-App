# AuroraFlix — mobile app

Flutter app for Android (then iOS, then TV) that brings the auroraflix.cloud
website to phones. It is distributed as an APK downloaded from the website,
**not** through Google Play.

## Run in the browser (for testing)

```bash
flutter run -d chrome --web-port 5173
```

Port **5173** matters: the gateway's CORS allowlist includes
`http://localhost:5173`, so the browser build can call lumo-api-gateway
directly. Use DevTools' device toolbar (Ctrl+Shift+M) to get a phone-sized
view. Press `r` in the terminal for hot reload and `R` for hot restart.

### Sign-in in the browser build

The production Clerk instance only accepts browser requests from
auroraflix.cloud. For the browser build, run the dev proxy in a second
terminal (the debug web build talks to it automatically):

```bash
node tool/clerk_dev_proxy.mjs     # http://localhost:5174 -> clerk.auroraflix.cloud
```

Native builds (APK) call Clerk directly and don't need it.

"Continue with Google" also needs these redirect URLs on the Clerk instance's
allowlist (Clerk Dashboard → Configure → Native applications):

- `cloud.auroraflix://sso-callback` (the app)
- `http://localhost:5173/auth.html` (browser testing)

To point the app at a local gateway:

```bash
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://localhost:8080
```

## Layout

```
lib/
  core/            config, theme (site design tokens), API clients, i18n, TMDB helpers
  core/i18n/       dictionary.g.dart is GENERATED from my-app — see below
  models/          Dart versions of my-app/types/*
  shell/           header, search, menu, floating tab bar, tab container
  screens/         one file per screen
  widgets/         shared UI pieces (Pressable, Glass, AuroraImage, ...)
tool/
  gen_dictionary.mjs
```

## Translations

The UI copy is shared with the website. After changing
`my-app/lib/i18n/dictionary.ts`, regenerate:

```bash
node tool/gen_dictionary.mjs
```

App-only strings live in `lib/core/i18n/app_strings.dart`.
