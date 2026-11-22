import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/locale.dart';
import '../../core/library/playlists.dart';
import '../../core/theme.dart';
import '../../shell/app_shell.dart';
import '../../widgets/footer.dart';
import '../../widgets/library_hero.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';
import '../details/details_background.dart';
import 'playlist_card.dart';
import '../../widgets/burst.dart';
import '../../widgets/empty_art.dart';

/// "Playlists" (website: PlaylistsView): heading with the count, "New
/// playlist" (which unfolds the create form), then one card per playlist,
/// or the empty state.
class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  bool _creating = false;

  /// Bumped when a playlist is added: a burst from the "new" button (website: same).
  int _celebrate = 0;

  /// The first playlist's first poster (a TMDB path), reported by its card
  /// once its titles load — the page's blurred background, like the Watchlist.
  String? _coverPoster;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final playlists = ref.watch(playlistsProvider);
    ref.listen(playlistsProvider, (previous, next) {
      if (previous != null && next != null && next.length > previous.length) setState(() => _celebrate++);
    });

    Widget newButton({bool forceWhite = false}) {
      final white = forceWhite || !_creating;
      return Celebrate(
        trigger: _celebrate,
        count: 16,
        distance: 56,
        particleSize: 6,
        colors: const [Colors.white, Color(0xFFFCD34D), Color(0xFF7DD3FC), Color(0xFFFB7185), Color(0xFFA78BFA)],
        child: Pressable(
          onTap: () => setState(() => _creating = forceWhite ? true : !_creating),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: white ? Colors.white : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(999),
              border: white ? null : Border.all(color: AppColors.fg(0.15)),
              boxShadow: white
                  ? [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 8))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(white ? LucideIcons.plus : LucideIcons.x, size: 16, color: white ? AppColors.onWhite : AppColors.fg(0.7)),
                const SizedBox(width: 8),
                Text(
                  t('playlists.new'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: white ? AppColors.onWhite : AppColors.fg(0.7)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final backdrop = playlists != null && playlists.isNotEmpty ? _coverPoster : null;

    return Stack(
      children: [
        if (backdrop != null) Positioned.fill(child: BlurredPageBackdrop(path: backdrop)),
        ListView(
          padding: shellContentPadding(context),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LibraryHero(
                    title: t('playlists.title'),
                    subtitle: t('playlists.subtitle'),
                    action: Align(alignment: Alignment.centerLeft, child: newButton()),
                    stats: playlists == null || playlists.isEmpty
                        ? const []
                        : [
                            LibraryStat(icon: LucideIcons.listVideo, label: t('playlists.statPlaylists'), value: '${playlists.length}'),
                            LibraryStat(
                              icon: LucideIcons.globe,
                              label: t('playlists.statPublic'),
                              value: '${playlists.where((playlist) => playlist.isPublic).length}',
                            ),
                            LibraryStat(
                              icon: LucideIcons.film,
                              label: t('playlists.statTitles'),
                              value: '${playlists.fold<int>(0, (sum, playlist) => sum + playlist.itemCount)}',
                            ),
                          ],
                  ),
                  const SizedBox(height: 32),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: auroraEase,
                    alignment: Alignment.topCenter,
                    child: _creating
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: CreatePlaylistForm(onDone: () => setState(() => _creating = false)),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  if (playlists == null)
                    const Loader()
                  else if (playlists.isEmpty && !_creating)
                    Container(
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
                          const EmptyIllustration(art: EmptyArt.playlists),
                          const SizedBox(height: 12),
                          Text(
                            t('playlists.emptyTitle'),
                            textAlign: TextAlign.center,
                            style: display(const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t('playlists.emptyDesc'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: AppColors.fg(0.55)),
                          ),
                          const SizedBox(height: 16),
                          newButton(forceWhite: true),
                        ],
                      ),
                    )
                  else
                    for (final playlist in playlists)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: PlaylistCard(
                          key: ValueKey(playlist.id),
                          playlist: playlist,
                          canManage: true,
                          onCoverPoster: playlist == playlists.first
                              ? (path) {
                                  if (mounted && path != _coverPoster) setState(() => _coverPoster = path);
                                }
                              : null,
                        ),
                      ),
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
