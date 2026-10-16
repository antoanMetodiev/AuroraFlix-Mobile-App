import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/catalog_api.dart';
import '../../core/i18n/locale.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../core/theme.dart';
import '../../shell/app_shell.dart';
import '../../widgets/cinema_record_card.dart';
import '../../widgets/footer.dart';
import '../../widgets/loader.dart';
import '../../widgets/pagination.dart';
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

    final typeLabel = query.type == RecordType.movie ? t('nav.movies') : t('nav.series');
    final heading = query.search != null
        ? '${t('common.results')} "${query.search}"'
        : query.genre != null
        ? '${t.genre(query.genre!)} $typeLabel'
        : typeLabel;

    // The list scrolls over a fixed background, like the details screen.
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          Positioned.fill(child: ListBackground(type: query.type)),
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
                    CinemaRecordGrid(records: result.records),
                    PaginationControls(
                      current: query.page,
                      total: result.totalPages,
                      onPage: (page) => context.go(query.location(page: page)),
                    ),
                  ],
                ),
              ),
              // Fades the background out into the footer's solid black.
              const SizedBox(
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.background],
                    ),
                  ),
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
