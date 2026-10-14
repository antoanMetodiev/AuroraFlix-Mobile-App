// Dart counterparts of my-app/types/*.ts — same field names as the gateway's
// JSON, so parsing is a straight read. Everything optional on the website is
// nullable here too.

String? _str(Object? value) => value?.toString();

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    value is List ? value.whereType<Map<String, dynamic>>().map(parse).toList() : const [];

class Actor {
  const Actor({
    required this.id,
    required this.nameInRealLife,
    this.imageURL,
    this.biography,
    this.imdbId,
    this.birthday,
    this.knownFor,
    this.placeOfBirth,
    this.gender,
    this.popularity,
    this.facebookUsername,
    this.instagramUsername,
    this.twitterUsername,
    this.youtubeChannel,
  });

  final String id;
  final String nameInRealLife;
  final String? imageURL;
  final String? biography;
  final String? imdbId;
  final String? birthday;
  final String? knownFor;
  final String? placeOfBirth;
  final String? gender;
  final String? popularity;
  final String? facebookUsername;
  final String? instagramUsername;
  final String? twitterUsername;
  final String? youtubeChannel;

  factory Actor.fromJson(Map<String, dynamic> json) => Actor(
    id: _str(json['id']) ?? '',
    nameInRealLife: _str(json['nameInRealLife']) ?? '',
    imageURL: _str(json['imageURL']),
    biography: _str(json['biography']),
    imdbId: _str(json['imdbId']),
    birthday: _str(json['birthday']),
    knownFor: _str(json['knownFor']),
    placeOfBirth: _str(json['placeOfBirth']),
    gender: _str(json['gender']),
    popularity: _str(json['popularity']),
    facebookUsername: _str(json['facebookUsername']),
    instagramUsername: _str(json['instagramUsername']),
    twitterUsername: _str(json['twitterUsername']),
    youtubeChannel: _str(json['youtubeChannel']),
  );
}

/// One of an actor's titles (gateway `/actor/latest-works/{imdbId}`). The
/// backend spells the type field `TYPE`.
class ActorWork {
  const ActorWork({required this.type, required this.title, required this.posterURL, required this.tmdbRating, this.tmdbId, this.videoURL});

  final RecordType type;
  final String title;
  final String posterURL;
  final String tmdbRating;
  final String? tmdbId;
  final String? videoURL;

  /// TMDB id the details screen opens by (legacy movie rows: end of videoURL).
  String get detailsId => tmdbId ?? RegExp(r'/(\d+)$').firstMatch(videoURL ?? '')?.group(1) ?? '';

  factory ActorWork.fromJson(Map<String, dynamic> json) => ActorWork(
    type: json['TYPE'] == 'SERIES' ? RecordType.series : RecordType.movie,
    title: _str(json['title']) ?? _str(json['name_in_real_life']) ?? '',
    posterURL: _str(json['posterURL']) ?? '',
    tmdbRating: _str(json['tmdbRating']) ?? '',
    tmdbId: _str(json['tmdbId']),
    videoURL: _str(json['videoURL']),
  );
}

/// A comment under a title (website: types/comment.ts).
class Comment {
  const Comment({
    required this.id,
    required this.text,
    required this.authorId,
    required this.createdAt,
    this.authorUsername,
    this.authorFullName,
    this.authorImgURL,
  });

  final String id;
  final String text;
  final String authorId;
  final String createdAt;
  final String? authorUsername;
  final String? authorFullName;
  final String? authorImgURL;

  String get authorName => (authorFullName?.isNotEmpty ?? false) ? authorFullName! : (authorUsername ?? '');

  Comment copyWith({String? text}) => Comment(
    id: id,
    text: text ?? this.text,
    authorId: authorId,
    createdAt: createdAt,
    authorUsername: authorUsername,
    authorFullName: authorFullName,
    authorImgURL: authorImgURL,
  );

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: _str(json['id']) ?? '',
    text: _str(json['commentText']) ?? '',
    authorId: _str(json['authorId']) ?? '',
    createdAt: _str(json['createdAt']) ?? '',
    authorUsername: _str(json['authorUsername']),
    authorFullName: _str(json['authorFullName']),
    authorImgURL: _str(json['authorImgURL']),
  );
}

/// Someone who liked / disliked a comment.
class Reactor {
  const Reactor({required this.userId, this.username, this.fullName, this.imgURL, this.createdAt});

  final String userId;
  final String? username;
  final String? fullName;
  final String? imgURL;
  final String? createdAt;

  String get displayName => (fullName?.isNotEmpty ?? false) ? fullName! : (username ?? '?');

  factory Reactor.fromJson(Map<String, dynamic> json) => Reactor(
    userId: _str(json['userId']) ?? '',
    username: _str(json['username']),
    fullName: _str(json['fullName']),
    imgURL: _str(json['imgURL']),
    createdAt: _str(json['createdAt']),
  );
}

class CommentReactions {
  const CommentReactions({this.likes = const [], this.dislikes = const []});

  final List<Reactor> likes;
  final List<Reactor> dislikes;

  factory CommentReactions.fromJson(Map<String, dynamic> json) =>
      CommentReactions(likes: _list(json['likes'], Reactor.fromJson), dislikes: _list(json['dislikes'], Reactor.fromJson));
}

enum ImageType { poster, backdrop }

class MediaImage {
  const MediaImage({required this.id, required this.imageType, required this.imageURL});

  final String id;
  final ImageType imageType;
  final String imageURL;

  factory MediaImage.fromJson(Map<String, dynamic> json) => MediaImage(
    id: _str(json['id']) ?? '',
    imageType: json['imageType'] == 'POSTER' ? ImageType.poster : ImageType.backdrop,
    imageURL: _str(json['imageURL']) ?? '',
  );
}

class Episode {
  const Episode({
    required this.id,
    required this.videoURL,
    this.posterImgURL,
    this.episodeTitle,
    this.airDate,
    this.description,
    this.runtime,
    this.tmdbRating,
    this.season,
    this.episodeNumber,
  });

  final String id;
  final String videoURL;
  final String? posterImgURL;
  final String? episodeTitle;
  final String? airDate;
  final String? description;
  final String? runtime;
  final String? tmdbRating;
  final String? season;
  final String? episodeNumber;

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    id: _str(json['id']) ?? '',
    videoURL: _str(json['videoURL']) ?? '',
    posterImgURL: _str(json['posterImgURL']),
    episodeTitle: _str(json['episodeTitle']),
    airDate: _str(json['airDate']),
    description: _str(json['description']),
    runtime: _str(json['runtime']),
    tmdbRating: _str(json['tmdbRating']),
    season: _str(json['season']),
    episodeNumber: _str(json['episodeNumber']),
  );
}

enum RecordType { movie, series }

/// A movie or a series — the website's `Movie | Series` / `CinemaRecord`.
/// One class instead of two since they share every field but the episode
/// list; [type] is carried explicitly for the same reason as the site's
/// HeroItem: trending rows have no `allEpisodes` to sniff it from.
class CinemaRecord {
  const CinemaRecord({
    required this.id,
    required this.type,
    required this.title,
    this.originalTitle,
    required this.tmdbRating,
    this.movieId,
    this.tmdbId,
    this.description,
    this.specialText,
    this.genres,
    this.releaseDate,
    this.posterImgURL,
    this.backgroundImgURL,
    this.trailerURL,
    this.trailerVideoURL,
    this.logoURL,
    this.videoURL,
    this.castList = const [],
    this.imagesList = const [],
    this.allEpisodes = const [],
  });

  final String id;
  final RecordType type;
  final String title;

  /// The English title, sent only when [title] is a translation (?lang).
  final String? originalTitle;
  final String tmdbRating;
  final String? movieId;
  final String? tmdbId;
  final String? description;
  final String? specialText;
  final String? genres;
  final String? releaseDate;
  final String? posterImgURL;
  final String? backgroundImgURL;
  final String? trailerURL;

  /// Hero-only (trending endpoints): YouTube trailer and title logo.
  final String? trailerVideoURL;
  final String? logoURL;

  final String? videoURL;
  final List<Actor> castList;
  final List<MediaImage> imagesList;
  final List<Episode> allEpisodes;

  bool get isSeries => type == RecordType.series;

  double? get rating {
    final value = double.tryParse(tmdbRating);
    return value == null || value.isNaN ? null : value.clamp(0, 10).toDouble();
  }

  String? get year => releaseDate != null && releaseDate!.length >= 4 ? releaseDate!.substring(0, 4) : null;

  /// Some series rows store genres as `"Drama".` — the quotes / dot are stripped.
  List<String> get genreList =>
      (genres ?? '').split(',').map((genre) => genre.trim().replaceAll(_genreJunk, '')).where((genre) => genre.isNotEmpty).toList();

  static final _genreJunk = RegExp(r'''^["']+|["'.]+$''');

  factory CinemaRecord.fromJson(Map<String, dynamic> json, RecordType type) => CinemaRecord(
    id: _str(json['id']) ?? '',
    type: type,
    title: _str(json['title']) ?? '',
    originalTitle: _str(json['originalTitle']),
    tmdbRating: _str(json['tmdbRating']) ?? '',
    movieId: _str(json['movieId']),
    tmdbId: _str(json['tmdbId']),
    description: _str(json['description']),
    specialText: _str(json['specialText']),
    genres: _str(json['genres']),
    releaseDate: _str(json['releaseDate']),
    posterImgURL: _str(json['posterImgURL']),
    backgroundImgURL: _str(json['backgroundImg_URL']),
    trailerURL: _str(json['trailerURL']),
    trailerVideoURL: _str(json['trailerVideoURL']),
    logoURL: _str(json['logoURL']),
    videoURL: _str(json['videoURL']),
    castList: _list(json['castList'], Actor.fromJson),
    imagesList: _list(json['imagesList'], MediaImage.fromJson),
    allEpisodes: _list(json['allEpisodes'], Episode.fromJson),
  );
}
