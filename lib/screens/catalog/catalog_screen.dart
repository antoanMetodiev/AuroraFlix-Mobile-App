import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/catalog_api.dart';
import '../../core/api/catalog_cache.dart';
import '../../core/i18n/locale.dart';
import '../../core/trending_ranks.dart';
import '../../widgets/pressable.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../core/theme.dart';
import '../../shell/app_shell.dart';
import '../../widgets/cinema_record_card.dart';
import '../../widgets/footer.dart';
import '../../widgets/loader.dart';
import '../../widgets/pagination.dart';
import '../details/details_background.dart';
import 'auto_order_notice.dart';
import 'discover_filters.dart';
import 'list_background.dart';

class CatalogPage {
  const CatalogPage({required this.records, required this.totalPages});

  final List<CinemaRecord> records;
  final int totalPages;
}

/// One page of results (website: CinemaRecordResults). Title search returns
/// every match at once, so it's paged in memory — same as the site.
final catalogPageProvider = FutureProvider.family<CatalogPage, CatalogQuery>((ref, query) async {
  final api = ref.watch(catalogApiProvider);
  const size = CatalogApi.pageSize;
  // Cached a while, like the website's listings — far less right after an
  // order, so the ordered title shows up soon (see catalog_cache.dart).
  expireAfter(ref, catalogIsFresh ? freshListingCacheTtl : listingCacheTtl);

  if (query.search != null) {
    final all = await api.searchByTitle(query.type, query.search!);
    final start = ((query.page - 1) * size).clamp(0, all.length);
    final end = (query.page * size).clamp(0, all.length);
    return CatalogPage(records: all.sublist(start, end), totalPages: (all.length / size).ceil().clamp(1, 1 << 30));
  }

  final recordsFuture = api.discover(query.type, query.filters, query.page);
  final countFuture = api.discoverCount(query.type, query.filters);
  final records = await recordsFuture;
  final count = await countFuture;
  return CatalogPage(records: records, totalPages: (count / size).ceil().clamp(1, 1 << 30));
});

/// /movies and /series (also genre-filtered and title-search results) —
/// the website's CinemaRecordListPage: filters, heading, the poster grid
/// and pagination, then the footer.
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key, required this.query});

  final CatalogQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final page = ref.watch(catalogPageProvider(query));
    final ranks = ref.watch(trendingRanksProvider(query.type)).value;

    final typeLabel = query.type == RecordType.movie ? t('nav.movies') : t('nav.series');
    final heading = query.search != null
        ? '${t('common.results')} "${query.search}"'
        : query.genre != null
        ? '${t.genre(query.genre!)} $typeLabel'
        : typeLabel;

    // Same blurred-poster background as the Watchlist: the first title on
    // this page. ListBackground stays under it as the fallback while the
    // results load or when nothing matches.
    final backdropPath = page.value?.records.where((record) => record.posterImgURL != null).firstOrNull?.posterImgURL;

    // The list scrolls over a fixed background, like the details screen.
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          const Positioned.fill(child: ListBackground()),
          if (backdropPath != null) Positioned.fill(child: BlurredPageBackdrop(path: backdropPath)),
          ListView(
            padding: shellContentPadding(context),
            children: [
              // Title search is its own flow — no discover filters there.
              if (query.search == null) DiscoverFiltersBar(query: query),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                child: Text(heading, style: display(const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.5))),
              ),
              page.when(
                loading: () => const Loader(minHeight: 320),
                error: (_, _) => const CinemaRecordGrid(records: []),
                data: (result) => Column(
                  children: [
                    // A title search with no match orders it right away instead of a dead end.
                    if (query.search != null && result.records.isEmpty && query.page == 1)
                      AutoOrderNotice(query: query)
                    else
                      CinemaRecordGrid(
                        records: result.records,
                        trendingRanks: ranks,
                        emptyAction: _EmptyActions(listLocation: query.type == RecordType.movie ? '/movies' : '/series'),
                      ),
                    PaginationControls(
                      current: query.page,
                      total: result.totalPages,
                      onPage: (page) => context.go(query.location(page: page)),
                    ),
                  ],
                ),
              ),
              const SiteFooter(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Under "nothing found" (website: the grid's empty state): clear the
/// filters, or order the title instead.
class _EmptyActions extends ConsumerWidget {
  const _EmptyActions({required this.listLocation});

  final String listLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Pressable(
          onTap: () => context.go(listLocation),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 8))],
            ),
            child: Text(t('empty.clearFilters'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF171717))),
          ),
        ),
        Pressable(
          onTap: () => context.go('/order'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Text(t('empty.orderTitle'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.fg(0.85))),
          ),
        ),
      ],
    );
  }
}
