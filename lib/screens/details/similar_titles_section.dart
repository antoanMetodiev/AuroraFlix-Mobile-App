import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/catalog_api.dart';
import '../../core/i18n/locale.dart';
import '../../models/models.dart';
import '../../widgets/cinema_record_card.dart';
import '../../widgets/section_heading.dart';

/// How many of each type the section shows (movies and series alternate).
const _perType = 6;

/// Genres of the current title used to look for similar ones — the first
/// are the most characteristic.
const _maxGenres = 2;

typedef _SimilarKey = ({RecordType type, String id, String genres});

/// The website's SimilarTitlesSection: candidates are the top-rated titles of
/// each of the title's first genres; those sharing more genres with it come
/// first, and among equals the order is shuffled with the title's id as the
/// seed — each title gets its own mix, the same one every time.
final _similarProvider = FutureProvider.family<List<CinemaRecord>, _SimilarKey>((ref, key) async {
  final genres = CinemaRecord.parseGenres(key.genres).take(_maxGenres).toList();
  if (genres.isEmpty) return const [];

  final api = ref.watch(catalogApiProvider);

  Future<List<CinemaRecord>> candidates(RecordType type) async {
    final pages = await Future.wait(
      genres.map(
        (genre) => api
            .discover(type, DiscoverFilters(genre: genre, sort: SortOption.topRated), 1)
            .catchError((Object _) => const <CinemaRecord>[]),
      ),
    );
    final seen = <String>{};
    return [
      for (final record in pages.expand((page) => page))
        if (!(type == key.type && record.id == key.id) && seen.add(record.id)) record,
    ];
  }

  final results = await Future.wait([candidates(RecordType.movie), candidates(RecordType.series)]);
  final random = _SeededRandom(key.id);
  final movies = _mostSimilar(results[0], genres, random).take(_perType).toList();
  final series = _mostSimilar(results[1], genres, random).take(_perType).toList();

  return [
    for (var i = 0; i < _perType; i++) ...[if (i < movies.length) movies[i], if (i < series.length) series[i]],
  ];
});

/// Most shared genres first; ties in a seeded-random order.
List<CinemaRecord> _mostSimilar(List<CinemaRecord> list, List<String> genres, _SeededRandom random) {
  final wanted = genres.map((genre) => genre.toLowerCase()).toSet();
  final scored = [
    for (final record in list)
      (record: record, shared: record.genreList.where((genre) => wanted.contains(genre.toLowerCase())).length, tieBreak: random.next()),
  ]..sort((a, b) => b.shared != a.shared ? b.shared - a.shared : a.tieBreak.compareTo(b.tieBreak));
  return [for (final entry in scored) entry.record];
}

/// "You may also like" — below the comments on every details screen.
class SimilarTitlesSection extends ConsumerWidget {
  const SimilarTitlesSection({super.key, required this.record});

  final CinemaRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final similar = ref.watch(_similarProvider((type: record.type, id: record.id, genres: record.genres ?? '')));

    // Streams in on its own; nothing while loading or when there's nothing.
    final records = similar.value ?? const <CinemaRecord>[];
    if (records.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(t('details.similarTitle'), icon: LucideIcons.listVideo, padding: const EdgeInsets.symmetric(horizontal: 16)),
          CinemaRecordGrid(records: records),
        ],
      ),
    );
  }
}

/// The website's seededRandom: mulberry32 seeded by an FNV-1a hash of the id,
/// so the same title gets the same order here as on the site.
class _SeededRandom {
  _SeededRandom(String seed) {
    var hash = 2166136261;
    for (final unit in seed.codeUnits) {
      hash ^= unit;
      hash = _imul(hash, 16777619);
    }
    _state = hash;
  }

  late int _state;

  double next() {
    _state = (_state + 0x6d2b79f5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= (t + _imul(t ^ (t >>> 7), t | 61)) & 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
  }

  /// JavaScript's Math.imul on unsigned 32-bit values, split in 16-bit halves
  /// so no product exceeds 2^53 (the web build's ints are doubles).
  static int _imul(int a, int b) {
    final low = (a & 0xFFFF) * b;
    final high = ((a >>> 16) * b & 0xFFFF) << 16;
    return (low + high) & 0xFFFFFFFF;
  }
}
