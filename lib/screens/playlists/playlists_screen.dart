import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/locale.dart';
import '../../core/library/playlists.dart';
import '../../core/theme.dart';
import '../../shell/app_shell.dart';
import '../../widgets/footer.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';
import 'playlist_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final playlists = ref.watch(playlistsProvider);

    Widget newButton({bool forceWhite = false}) {
      final white = forceWhite || !_creating;
      return Pressable(
        onTap: () => setState(() => _creating = forceWhite ? true : !_creating),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: white ? Colors.white : Colors.transparent,
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
      );
    }

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
                crossAxisAlignment: WrapCrossAlignment.start,
                spacing: 16,
                runSpacing: 16,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t('playlists.title'), style: display(const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.6))),
                          if (playlists != null && playlists.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.fg(0.1),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.fg(0.15)),
                              ),
                              child: Text(
                                '${playlists.length}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.fg(0.7)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 448),
                        child: Text(t('playlists.subtitle'), style: TextStyle(fontSize: 14, color: AppColors.fg(0.5))),
                      ),
                    ],
                  ),
                  newButton(),
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
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.fg(0.05)),
                        child: Icon(LucideIcons.listVideo, size: 24, color: AppColors.fg(0.3)),
                      ),
                      const SizedBox(height: 12),
                      Text(t('playlists.emptyTitle'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text(
                        t('playlists.emptyDesc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.fg(0.5)),
                      ),
                      const SizedBox(height: 24),
                      newButton(forceWhite: true),
                    ],
                  ),
                )
              else
                for (final playlist in playlists)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: PlaylistCard(key: ValueKey(playlist.id), playlist: playlist, canManage: true),
                  ),
            ],
          ),
        ),
        const SiteFooter(),
      ],
    );
  }
}
