import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/locale.dart';
import '../../core/library/localized_titles.dart';
import '../../core/library/watchlist.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../shell/app_shell.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/footer.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';

/// Opens a saved title (watchlist / playlist row) — rows only carry the
/// TMDB id and "MOVIE" / "TV-SHOW".
void openLibraryItem(BuildContext context, LibraryItem item) =>
    openTitle(context, item.isSeries ? RecordType.series : RecordType.movie, item.tmdbId ?? item.id);

/// "My Watchlist" (website: WatchlistView): heading with the count pill,
/// then a poster grid with rating and a remove ✕ on each, or the empty
/// state with "Browse Movies".
class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    // Titles / posters in the app's current language (see localizeLibraryItems).
    final items = localizeLibraryItems(ref, ref.watch(watchlistProvider));

    return ListView(
      padding: shellContentPadding(context),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('watchlist.title'), style: display(const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.6))),
                      const SizedBox(height: 8),
                      Text(t('watchlist.subtitle', {'max': maxWatchlistItems}), style: TextStyle(fontSize: 14, color: AppColors.fg(0.5))),
                    ],
                  ),
                  if (items != null && items.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.fg(0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.fg(0.15)),
                      ),
                      child: Text(
                        '${items.length} ${t('watchlist.saved')}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.fg(0.8)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 40),
              if (items == null)
                const Loader()
              else if (items.isEmpty)
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t('watchlist.emptyTitle'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text(
                        t('watchlist.emptyDesc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.fg(0.5)),
                      ),
                      const SizedBox(height: 24),
                      Pressable(
                        onTap: () => context.go('/movies'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Text(
                            t('watchlist.browseMovies'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onWhite),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 16) / 2;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final item in items)
                          SizedBox(
                            width: width,
                            child: _WatchlistTile(item: item),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
        const SiteFooter(),
      ],
    );
  }
}

class _WatchlistTile extends ConsumerWidget {
  const _WatchlistTile({required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final rating = double.tryParse(item.tmdbRating ?? '');

    return Pressable(
      onTap: () => openLibraryItem(context, item),
      pressedScale: 0.97,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AuroraImage(url: tmdbImage(item.posterImgURL, TmdbSize.w500)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xE6000000), Color(0x22000000), Colors.transparent],
                  ),
                ),
              ),
              if (rating != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      '★ ${rating.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Pressable(
                  onTap: () => ref.read(watchlistProvider.notifier).remove(item.id),
                  semanticLabel: t('watchlist.removeAria'),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.6)),
                    child: const Icon(LucideIcons.x, size: 14, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, height: 1.25, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.isSeries ? t('watchlist.series') : t('watchlist.movie'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
