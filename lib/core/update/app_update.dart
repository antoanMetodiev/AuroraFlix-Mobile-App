import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config.dart';

/// The newest APK on auroraflix.cloud, described by
/// `/downloads/version.json`:
/// `{ "versionCode": 4, "versionName": "0.2.0", "url": "…/auroraflix.apk",
///    "notes": { "bg": "…", "en": "…" }, "tv": { …the same fields… } }`.
/// `tv` is the 32-bit ARM build Android TVs need; it's released on its own,
/// so it keeps its own version.
///
/// Small changes reach phones through Shorebird patches by themselves; this
/// is for the releases that need a new APK (new native code, icon,
/// permissions) — the app offers to download and install it.
class AppRelease {
  const AppRelease({required this.versionCode, required this.versionName, required this.url, required this.notes});

  final int versionCode;
  final String versionName;
  final String url;
  final Map<String, String> notes;

  static AppRelease? fromJson(Object? json, {bool tv = false}) {
    if (json is! Map) return null;
    if (tv) return fromJson(json['tv']);
    final code = json['versionCode'];
    final url = json['url'];
    if (code is! num || url is! String || url.isEmpty) return null;
    return AppRelease(
      versionCode: code.toInt(),
      versionName: '${json['versionName'] ?? ''}',
      url: url,
      notes: {
        if (json['notes'] case final Map notes)
          for (final entry in notes.entries) '${entry.key}': '${entry.value}',
      },
    );
  }
}

const _versionUrl = '$siteUrl/downloads/version.json';

/// Only the Android APK updates itself this way.
bool get canSelfUpdate => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The published release, if it's newer than the installed one. A TV only
/// gets offered the TV build — the phone one won't install there.
Future<AppRelease?> checkForAppUpdate({required bool tv}) async {
  if (!canSelfUpdate) return null;
  try {
    // Cache-busted so a fresh release shows up right away.
    final response = await http
        .get(Uri.parse('$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final release = AppRelease.fromJson(jsonDecode(utf8.decode(response.bodyBytes)), tv: tv);
    if (release == null) return null;
    final installed = int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
    return release.versionCode > installed ? release : null;
  } catch (_) {
    return null;
  }
}
