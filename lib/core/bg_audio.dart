import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

/// A movie's Bulgarian-dubbed stream, for the БГ аудио player (player 1 when
/// there is one).
///
/// The site only knows which ZenoPlay VidHide embed carries the dub
/// (/api/bg-audio-source/{tmdbId}). VidHide signs its playlist links for the
/// network that asked for them — resolved on a server, a viewer's phone gets
/// 403 — so the embed is read here, on the viewer's own connection: its
/// packed jwplayer config is decoded and the fresh master.m3u8 handed to
/// [bgPlayerUrl]. The browser build can't do this (the embed page sends no
/// CORS headers) and never gets the player.
///
/// Null when the movie has no dub or anything along the way fails — the
/// embed players are still there.
final bgAudioMasterProvider = FutureProvider.family<String?, String>((ref, tmdbId) async {
  if (kIsWeb || tmdbId.isEmpty) return null;
  try {
    final source = await http.get(Uri.parse('$siteUrl/api/bg-audio-source/${Uri.encodeComponent(tmdbId)}')).timeout(const Duration(seconds: 20));
    if (source.statusCode != 200) return null;
    final embedUrl = (jsonDecode(source.body) as Map<String, dynamic>)['embedUrl'];
    if (embedUrl is! String || embedUrl.isEmpty) return null;
    return await resolveVidhideMaster(embedUrl);
  } catch (_) {
    return null;
  }
});

const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:130.0) Gecko/20100101 Firefox/130.0';

/// The embed's HLS master playlist URL, checked to really be one.
Future<String?> resolveVidhideMaster(String embedUrl) async {
  final embed = Uri.parse(embedUrl);
  final page = await http.get(embed, headers: {'User-Agent': _userAgent, 'Referer': 'https://zenoplay.to/'}).timeout(const Duration(seconds: 20));
  if (page.statusCode != 200) return null;
  final config = unpackPacked(page.body) ?? page.body;

  // var links={"hls3":"…/master.txt","hls2":"…/master.m3u8?t=…","hls4":"/stream/…/master.m3u8"}
  for (final key in const ['hls2', 'hls4', 'hls3']) {
    final match = RegExp('"$key"\\s*:\\s*"([^"]+)"').firstMatch(config);
    if (match == null) continue;
    final link = embed.resolve(match.group(1)!.replaceAll(r'\/', '/'));
    try {
      final master = await http.get(link, headers: {'User-Agent': _userAgent, 'Referer': embedUrl}).timeout(const Duration(seconds: 20));
      if (master.statusCode == 200 && master.body.startsWith('#EXTM3U')) return link.toString();
    } catch (_) {
      // Try the next link.
    }
  }
  return null;
}

/// Our player page on the site for that stream (my-app/public/bg-player.html);
/// the links go in the fragment, so they never reach the server.
String bgPlayerUrl(String master, {String? subtitleUrl, String? title}) {
  final fragment = <String, String>{'master': master, 'sub': ?subtitleUrl, 'title': ?title};
  return '$siteUrl/bg-player.html#${Uri(queryParameters: fragment).query}';
}

const _packerAlphabet = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// Decodes Dean Edwards' p,a,c,k,e,d packer without running it:
/// `eval(function(p,a,c,k,e,d){…}('<payload>',<radix>,<count>,'<w0|w1|…>'.split('|')…))`.
/// Every word in the payload is a number in base `radix` indexing the keyword
/// list; an empty keyword means the word stands for itself.
String? unpackPacked(String page) {
  final match = RegExp(r"\}\s*\(\s*'((?:[^'\\]|\\.)*)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'((?:[^'\\]|\\.)*)'\.split\('\|'\)").firstMatch(page);
  if (match == null) return null;

  final payload = match.group(1)!.replaceAllMapped(RegExp(r'\\(.)'), (m) => m.group(1)!);
  final radix = int.parse(match.group(2)!);
  final keywords = match.group(4)!.split('|');

  int decode(String word) {
    var value = 0;
    for (final char in word.split('')) {
      final digit = _packerAlphabet.indexOf(char);
      if (digit < 0 || digit >= radix) return -1;
      value = value * radix + digit;
    }
    return value;
  }

  return payload.replaceAllMapped(RegExp(r'\b\w+\b'), (m) {
    final word = m.group(0)!;
    final index = decode(word);
    return index >= 0 && index < keywords.length && keywords[index].isNotEmpty ? keywords[index] : word;
  });
}
