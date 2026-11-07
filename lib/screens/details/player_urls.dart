// How each video provider's embed URL is built — a straight port of the URL
// builders in my-app/components/movies/details/player-section.tsx. See that
// file for why each parameter is there (verified against each player there).

/// The TMDB id (and season/episode) parsed out of a record's vidsrc URL.
sealed class VidsrcRef {
  const VidsrcRef(this.tmdbId);

  final String tmdbId;

  static VidsrcRef? parse(String videoUrl) {
    final tv = RegExp(r'/embed/tv/(\d+)/(\d+)/(\d+)').firstMatch(videoUrl);
    if (tv != null) return TvRef(tv.group(1)!, tv.group(2)!, tv.group(3)!);
    final movie = RegExp(r'/embed/movie/(\d+)').firstMatch(videoUrl);
    if (movie != null) return MovieRef(movie.group(1)!);
    return null;
  }
}

class MovieRef extends VidsrcRef {
  const MovieRef(super.tmdbId);
}

class TvRef extends VidsrcRef {
  const TvRef(super.tmdbId, this.season, this.episode);

  final String season;
  final String episode;
}

/// Player ids as on the website: 1 vidsrc2.ru, 2 VidFast, 3 CineSrc,
/// 4 VidLink, 5 EmbedMaster, 6 VidSpark, 7 / 8 БГ аудио.
typedef ProviderId = int;

/// Default language for the providers' own bundled subtitles.
const _subtitleLang = 'bg';

String _withParams(String url, Map<String, String?> params) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final query = Map<String, String>.of(uri.queryParameters);
  params.forEach((key, value) {
    if (value != null && value.isNotEmpty) query[key] = value;
  });
  return uri.replace(queryParameters: query).toString();
}

String _path(VidsrcRef ref) => switch (ref) {
  MovieRef() => 'movie/${ref.tmdbId}',
  TvRef(:final season, :final episode) => 'tv/${ref.tmdbId}/$season/$episode',
};

/// 1 — vidsrc2.ru: our Bulgarian file via `sub_url` when we have one,
/// otherwise its own Bulgarian track.
String vidsrcUrl(String videoUrl, {String? subtitleUrl}) => _withParams(videoUrl.replaceAll('vidsrc.icu', 'vidsrc2.ru'), {
  'autoplay': '1',
  'sub': _subtitleLang,
  'ds_lang': _subtitleLang,
  'sub_url': subtitleUrl,
});

/// VidFast's own controls are shown this much smaller (the iframe is laid
/// out at 1/scale and scaled back down).
const vidfastUiScale = 0.7;

/// 2 — VidFast, in blue, poster first, no title overlay or Chromecast; with
/// next-episode for series. Its own Bulgarian track.
String vidfastUrl(VidsrcRef ref, {int? startAt}) => _withParams('https://vidfast.vc/${_path(ref)}', {
  'autoPlay': 'true',
  'title': 'false',
  'poster': 'true',
  'theme': '2980B9',
  'chromecast': 'false',
  if (startAt != null) 'startAt': '$startAt',
  if (ref is TvRef) 'nextButton': 'true',
  if (ref is TvRef) 'autoNext': 'true',
  'sub': _subtitleLang,
  'lang': _subtitleLang,
});

/// 3 — CineSrc: its own subtitle search, preselecting Bulgarian.
String cinesrcUrl(VidsrcRef ref, {int? startAt}) => _withParams('https://cinesrc.st/embed/${ref is TvRef ? 'tv' : 'movie'}/${ref.tmdbId}', {
  'autoplay': 'true',
  'subtitles': 'auto',
  'subtitlelang': _subtitleLang,
  // Without continueprompt=false it first asks "Continue / Restart", which our
  // own poster has already answered.
  if (startAt != null) 't': '$startAt',
  if (startAt != null) 'continueprompt': 'false',
  if (ref is TvRef) 's': ref.season,
  if (ref is TvRef) 'e': ref.episode,
});

/// 4 — VidLink: our file in its own player (`sub_file`).
String vidlinkUrl(VidsrcRef ref, String subtitleUrl, {int? startAt}) => _withParams('https://vidlink.pro/${_path(ref)}', {
  'autoplay': 'true',
  'sub_file': subtitleUrl,
  'sub_label': 'Български',
  if (startAt != null) 'startAt': '$startAt',
});

/// 5 — EmbedMaster: best picture; our file in its captions menu.
String embedmasterUrl(VidsrcRef ref, String subtitleUrl) => _withParams('https://embedmaster.link/${_path(ref)}', {
  'welcome_page': 'off',
  'autoplay': 'on',
  'sub_url[]': subtitleUrl,
  'sub_label[]': 'Български',
});

/// 6 — VidSpark: plays in a sandbox (no ads); no subtitle parameters.
String vidsparkUrl(VidsrcRef ref, {int? startAt}) => _withParams('https://vidspark.to/${_path(ref)}', {if (startAt != null) 'startAt': '$startAt'});

/// Players that run inside an iframe sandbox — pop-ups and redirects can't
/// escape it, so they're ad-free.
const sandboxedPlayers = {3, 6};

const playerSandbox = 'allow-scripts allow-same-origin allow-forms allow-presentation allow-orientation-lock allow-pointer-lock';

const vidlinkOrigin = 'https://vidlink.pro';
