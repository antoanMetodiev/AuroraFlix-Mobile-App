import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/friends/friends_api.dart';
import '../../core/friends/friends_store.dart';
import '../../core/i18n/locale.dart';
import '../../core/library/playlists.dart';
import '../../core/library/watchlist.dart';
import '../../core/theme.dart';
import '../../widgets/image_lightbox.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';
import '../playlists/playlist_card.dart';
import 'friend_widgets.dart';

const _pageSize = 6;

/// Someone's profile (website: UserProfileModal): their picture, likes and
/// shared playlists — friends only; everyone else gets a lock.
Future<void> showUserProfileModal(BuildContext context, Friend person) =>
    showAuroraModal(context, builder: (context) => _UserProfileModal(person: person));

class _UserProfileModal extends ConsumerStatefulWidget {
  const _UserProfileModal({required this.person});

  final Friend person;

  @override
  ConsumerState<_UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends ConsumerState<_UserProfileModal> {
  List<LibraryItem>? _likes;
  List<Playlist>? _playlists;
  bool _requested = false;
  int _visibleLikes = _pageSize;
  int _visiblePlaylists = _pageSize;

  Future<void> _load() async {
    final api = ref.read(friendsApiProvider);
    final (likes, playlists) = await (api.likesOf(widget.person.clerkId), api.visiblePlaylistsOf(widget.person.clerkId)).wait;
    if (!mounted) return;
    setState(() {
      _likes = likes;
      _playlists = playlists;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final person = widget.person;
    final name = person.displayName?.isNotEmpty == true ? person.displayName! : '?';
    final friends = ref.watch(friendsProvider);
    final isSelf = ref.watch(authProvider.select((auth) => auth.user?.id)) == person.clerkId;
    final isFriend = isSelf || friends.friends.any((friend) => friend.clerkId == person.clerkId);
    final canView = !friends.isLoading && isFriend;

    if (canView && !_requested) {
      _requested = true;
      _load();
    }

    final imageUrl = person.profileImageURL;
    final header = Row(
      children: [
        Pressable(
          onTap: imageUrl == null || imageUrl.isEmpty
              ? null
              : () => showImageLightbox(context, paths: [imageUrl], initialIndex: 0, shape: LightboxShape.actor),
          semanticLabel: name,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0.05)],
              ),
            ),
            child: FriendAvatar(person: person, size: 64, ringColor: AppColors.surface),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.6),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _Stat(
                    icon: Icons.favorite,
                    label: canView && _likes != null ? t('profile.likesCount', {'count': _likes!.length}) : t('profile.likes'),
                  ),
                  _Stat(
                    icon: LucideIcons.listVideo,
                    label: canView && _playlists != null
                        ? t('profile.playlistsCount', {'count': _playlists!.length})
                        : t('profile.sharedPlaylists'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final List<Widget> body;
    if (friends.isLoading) {
      body = [const Loader(minHeight: 256)];
    } else if (!isFriend) {
      body = [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Column(
            children: [
              _EmptyIcon(icon: LucideIcons.lock, size: 56, iconSize: 22),
              const SizedBox(height: 12),
              Text(t('profile.friendsOnlyTitle'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 384),
                child: Text(
                  t('profile.friendsOnlyDesc', {'name': name}),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.fg(0.5)),
                ),
              ),
            ],
          ),
        ),
      ];
    } else {
      body = [
        _SectionTitle(t('profile.likes')),
        if (_likes == null)
          const Loader(minHeight: 160)
        else if (_likes!.isEmpty)
          _EmptyState(icon: Icons.favorite_border, label: t('profile.likesEmpty'))
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 24) / 3;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in _likes!.take(_visibleLikes))
                    SizedBox(
                      width: width,
                      child: LibraryPosterTile(item: item),
                    ),
                ],
              );
            },
          ),
          if (_likes!.length > _visibleLikes) LoadMoreButton(onTap: () => setState(() => _visibleLikes += _pageSize)),
        ],
        const SizedBox(height: 32),
        _SectionTitle(t('profile.sharedPlaylists')),
        if (_playlists == null)
          const Loader(minHeight: 128)
        else if (_playlists!.isEmpty)
          _EmptyState(icon: LucideIcons.listVideo, label: t('playlists.noneVisible'))
        else ...[
          for (final playlist in _playlists!.take(_visiblePlaylists))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PlaylistCard(key: ValueKey(playlist.id), playlist: playlist, canManage: false, itemsPageSize: _pageSize),
            ),
          if (_playlists!.length > _visiblePlaylists) LoadMoreButton(onTap: () => setState(() => _visiblePlaylists += _pageSize)),
        ],
      ];
    }

    return AuroraModalCard(
      glowAlpha: 0.08,
      header: header,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.7)),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.fg(0.5)),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: AppColors.fg(0.5)),
    ),
  );
}

class _EmptyIcon extends StatelessWidget {
  const _EmptyIcon({required this.icon, this.size = 48, this.iconSize = 20});

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.fg(0.05)),
    child: Icon(icon, size: iconSize, color: AppColors.fg(0.3)),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        _EmptyIcon(icon: icon),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.fg(0.5)),
        ),
      ],
    ),
  );
}
