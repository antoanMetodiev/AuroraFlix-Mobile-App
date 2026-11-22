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
import '../../widgets/footer.dart';
import '../../widgets/library_hero.dart';
import '../../widgets/library_poster_card.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';
import '../details/details_background.dart';
import '../playlists/playlist_card.dart' show PillTextField;
import '../../widgets/empty_art.dart';

/// Opens a saved title (watchlist / playlist row) — rows only carry the
/// TMDB id and "MOVIE" / "TV-SHOW".
void openLibraryItem(BuildContext context, LibraryItem item) =>
    openTitle(context, item.isSeries ? RecordType.series : RecordType.movie, item.tmdbId ?? item.id);

enum _Filter { all, movies, series }

enum _Sort { recent, rating, title }

/// "My Watchlist" (website: WatchlistView): the newest title's poster
/// blurred behind the page, the big title and stat cards (saved / movies /
/// series / average rating), then All / Movies / Series (when there are
/// both), a search, the sort switch and the poster grid — or the empty
/// state with "Browse Movies" / "Browse Series".
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.recent;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    // Titles / posters in the app's current language (see localizeLibraryItems).
    final items = localizeLibraryItems(ref, ref.watch(watchlistProvider));
    final list = items ?? const <LibraryItem>[];

    final seriesCount = list.where((item) => item.isSeries).length;
    final counts = {_Filter.all: list.length, _Filter.movies: list.length - seriesCount, _Filter.series: seriesCount};
    final ratings = list.map((item) => double.tryParse(item.tmdbRating ?? '')).whereType<double>().where((value) => value > 0).toList();
    final average = ratings.isEmpty ? null : ratings.reduce((a, b) => a + b) / ratings.length;

    final query = _search.text.trim().toLowerCase();
    var shown = list
        .where(
          (item) =>
              switch (_filter) {
                _Filter.all => true,
                _Filter.movies => !item.isSeries,
                _Filter.series => item.isSeries,
              } &&
              (query.isEmpty || (item.title ?? '').toLowerCase().contains(query)),
        )
        .toList();
    if (_sort == _Sort.rating) {
      shown.sort((a, b) => (double.tryParse(b.tmdbRating ?? '') ?? 0).compareTo(double.tryParse(a.tmdbRating ?? '') ?? 0));
    } else if (_sort == _Sort.title) {
      shown.sort((a, b) => (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase()));
    }
    // _Sort.recent: the list is already newest first.

    final full = list.length >= maxWatchlistItems;
    final subtitle = t('watchlist.subtitle', {'max': maxWatchlistItems});
    final backdrop = list.isEmpty ? null : tmdbImage(list.first.posterImgURL, TmdbSize.w780);

    return Stack(
      children: [
        if (backdrop != null) Positioned.fill(child: BlurredPageBackdrop(url: backdrop)),
        ListView(
          padding: shellContentPadding(context),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LibraryHero(
                    title: t('watchlist.title'),
                    subtitle: full ? '${t('watchlist.full')} — $subtitle' : subtitle,
                    stats: list.isEmpty
                        ? const []
                        : [
                            LibraryStat(
                              icon: LucideIcons.bookmark,
                              label: t('watchlist.statSaved'),
                              value: '${list.length} / $maxWatchlistItems',
                              progress: list.length / maxWatchlistItems,
                            ),
                            LibraryStat(icon: LucideIcons.clapperboard, label: t('nav.movies'), value: '${counts[_Filter.movies]}'),
                            LibraryStat(icon: LucideIcons.tv, label: t('nav.series'), value: '$seriesCount'),
                            // The site has a star here; it isn't in the shipped icon font.
                            LibraryStat(icon: LucideIcons.sparkles, label: t('watchlist.statRating'), value: average == null ? '—' : average.toStringAsFixed(1)),
                          ],
                  ),
                  const SizedBox(height: 40),
                  if (items == null)
                    const Loader()
                  else if (items.isEmpty)
                    const _EmptyState()
                  else ...[
                    if (counts[_Filter.movies]! > 0 && seriesCount > 0) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _FilterTabs(value: _filter, counts: counts, onChanged: (filter) => setState(() => _filter = filter)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    PillTextField(
                      controller: _search,
                      hint: t('watchlist.searchPlaceholder'),
                      prefixIcon: LucideIcons.search,
                      onChanged: (_) => setState(() {}),
                      suffix: query.isEmpty
                          ? null
                          : Pressable(
                              onTap: () => setState(_search.clear),
                              semanticLabel: t('watchlist.clearSearch'),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(LucideIcons.x, size: 14, color: AppColors.fg(0.55)),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _SortSwitch(value: _sort, onChanged: (sort) => setState(() => _sort = sort)),
                    ),
                    const SizedBox(height: 24),
                    if (shown.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          children: [
                            const EmptyIllustration(art: EmptyArt.search, width: 128, height: 96),
                            const SizedBox(height: 12),
                            Text(
                              t('watchlist.noMatches', {'query': _search.text.trim()}),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.fg(0.6)),
                            ),
                          ],
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 560 ? 3 : 2;
                          final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (var i = 0; i < shown.length; i++)
                                SizedBox(
                                  width: width,
                                  child: LibraryPosterCard(
                                    key: ValueKey(shown[i].id),
                                    item: shown[i],
                                    onTap: () => openLibraryItem(context, shown[i]),
                                    onRemove: () => ref.read(watchlistProvider.notifier).remove(shown[i].id),
                                    removeLabel: t('watchlist.removeAria'),
                                    // The first two rows load right away, the rest as they scroll in.
                                    lazy: i >= 4,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
            const SiteFooter(),
          ],
        ),
      ],
    );
  }
}

/// All / Movies / Series pill switch with counts (same as the actor page's).
class _FilterTabs extends ConsumerWidget {
  const _FilterTabs({required this.value, required this.counts, required this.onChanged});

  final _Filter value;
  final Map<_Filter, int> counts;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final tabs = [
      (_Filter.all, t('actor.filterAll'), LucideIcons.sparkles),
      (_Filter.movies, t('nav.movies'), LucideIcons.clapperboard),
      (_Filter.series, t('nav.series'), LucideIcons.tv),
    ];
    return _PillGroup(
      children: [
        for (final (tab, label, icon) in tabs)
          _Pill(
            selected: value == tab,
            onTap: () => onChanged(tab),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: value == tab ? AppColors.onWhite : AppColors.fg(0.65)),
                const SizedBox(width: 6),
                Text(label),
                const SizedBox(width: 6),
                Text('${counts[tab]}', style: TextStyle(color: value == tab ? const Color(0xFF737373) : AppColors.fg(0.4))),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Recently added / Top rated / A–Z".
class _SortSwitch extends ConsumerWidget {
  const _SortSwitch({required this.value, required this.onChanged});

  final _Sort value;
  final ValueChanged<_Sort> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final sorts = [
      (_Sort.recent, t('watchlist.sortRecent')),
      (_Sort.rating, t('watchlist.sortRating')),
      (_Sort.title, t('watchlist.sortTitle')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: _PillGroup(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            // The site's ArrowDownWideNarrow isn't in the shipped icon font.
            child: Icon(LucideIcons.slidersHorizontal, size: 14, color: AppColors.fg(0.4)),
          ),
          for (final (sort, label) in sorts)
            _Pill(selected: value == sort, small: true, onTap: () => onChanged(sort), child: Text(label)),
        ],
      ),
    );
  }
}

class _PillGroup extends StatelessWidget {
  const _PillGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.selected, required this.onTap, required this.child, this.small = false});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final bool small;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: small ? 6 : 7),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: selected && !small
            ? [BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 4))]
            : null,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: small ? 12 : 13,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.onWhite : AppColors.fg(small ? 0.6 : 0.65),
        ),
        child: child,
      ),
    ),
  );
}

/// The bookmark badge in its glow, "Your watchlist is empty" and the two
/// browse buttons.
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.03), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          const EmptyIllustration(art: EmptyArt.watchlist),
          const SizedBox(height: 16),
          Text(
            t('watchlist.emptyTitle'),
            textAlign: TextAlign.center,
            style: display(const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Text(
            t('watchlist.emptyDesc'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.fg(0.55)),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _BrowseButton(icon: LucideIcons.clapperboard, label: t('watchlist.browseMovies'), primary: true, onTap: () => context.go('/movies')),
              _BrowseButton(icon: LucideIcons.tv, label: t('watchlist.browseSeries'), onTap: () => context.go('/series')),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrowseButton extends StatelessWidget {
  const _BrowseButton({required this.icon, required this.label, required this.onTap, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: primary ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: primary ? null : Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: primary ? [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 8))] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: primary ? AppColors.onWhite : AppColors.fg(0.85)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary ? AppColors.onWhite : AppColors.fg(0.85)),
          ),
        ],
      ),
    ),
  );
}
