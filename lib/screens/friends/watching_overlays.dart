import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/friends/friends_api.dart';
import '../../core/friends/friends_store.dart';
import '../../core/i18n/locale.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/pressable.dart';
import 'friend_widgets.dart';

const _maxAvatars = 3;

/// One friend's "watching now" row (website: WatchingFriendCard): poster,
/// the friend, "● WATCHING", the title, rating and two genres.
class WatchingFriendCard extends ConsumerWidget {
  const WatchingFriendCard({super.key, required this.friend, required this.watching, this.onNavigate});

  final Friend friend;
  final WatchingTarget watching;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(titlePreviewProvider((watching.type, watching.tmdbId)));
    final rating = double.tryParse(preview.value?.tmdbRating ?? '');

    return Pressable(
      onTap: () {
        onNavigate?.call();
        openWatching(context, watching);
      },
      pressedScale: 0.98,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WatchingPoster(watching: watching, posterPath: preview.value?.posterImgURL, width: 56, height: 80, radius: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FriendAvatar(person: friend, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          friend.displayName?.isNotEmpty == true ? friend.displayName! : '?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.fg(0.55)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const WatchingLabel(),
                  Text(
                    watching.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.fg(0.9)),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 10, color: AppColors.amber),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.amber),
                            ),
                          ],
                        ),
                      PreviewGenres(loaded: preview.hasValue || preview.hasError, genres: previewGenres(preview.value, 2)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlapping avatars of the friends watching right now, each with a
/// pulsing green dot; "+N" past three.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.friends});

  final List<Friend> friends;

  @override
  Widget build(BuildContext context) {
    const size = 26.0;
    const overlap = 10.0;
    final shown = friends.take(_maxAvatars).toList();
    final extra = friends.length - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);
    // Each bubble carries a 2px surface ring, like the site's ring-2.
    const outer = size + 4;

    return SizedBox(
      width: outer + (count - 1) * (outer - overlap),
      height: outer,
      child: Stack(
        children: [
          for (var index = 0; index < shown.length; index++)
            Positioned(
              left: index * (outer - overlap),
              child: Stack(
                children: [
                  FriendAvatar(person: shown[index], size: size, ringColor: AppColors.surface),
                  const Positioned(right: 2, bottom: 2, child: _PulsingDot()),
                ],
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * (outer - overlap),
              child: Container(
                width: outer,
                height: outer,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Color.alphaBlend(AppColors.fg(0.15), AppColors.surface)),
                  child: Text(
                    '+$extra',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.fg(0.8)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 1.0, end: 0.5).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.emerald,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
    ),
  );
}

/// Bottom-left pill over the tab bar with the avatars of friends watching
/// right now; tap for their cards (website: WatchingFriendsMobilePill).
class WatchingFriendsPill extends ConsumerStatefulWidget {
  const WatchingFriendsPill({super.key});

  @override
  ConsumerState<WatchingFriendsPill> createState() => _WatchingFriendsPillState();
}

class _WatchingFriendsPillState extends ConsumerState<WatchingFriendsPill> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final friends = ref.watch(friendsProvider);
    final watchingFriends = friends.watchingFriends;
    if (watchingFriends.isEmpty) {
      if (_open) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() => _open = false) : null);
      return const SizedBox.shrink();
    }
    final screen = MediaQuery.sizeOf(context);

    return TapRegion(
      onTapOutside: (_) {
        if (_open) setState(() => _open = false);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IgnorePointer(
            ignoring: !_open,
            child: AnimatedOpacity(
              opacity: _open ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: AnimatedScale(
                scale: _open ? 1 : 0.95,
                alignment: Alignment.bottomLeft,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Container(
                  width: (screen.width - 24).clamp(0, 320).toDouble(),
                  constraints: BoxConstraints(maxHeight: screen.height * 0.6),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.fg(0.1)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 45, offset: const Offset(0, 20))],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 4,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                          child: Text(
                            t('friends.watchingNow').toUpperCase(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: AppColors.fg(0.5)),
                          ),
                        ),
                        for (final friend in watchingFriends)
                          WatchingFriendCard(
                            friend: friend,
                            watching: friends.watching[friend.clerkId]!,
                            onNavigate: () => setState(() => _open = false),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Pressable(
            onTap: () => setState(() => _open = !_open),
            semanticLabel: t('friends.watchingAria'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.fg(0.1)),
                  ),
                  child: _open
                      ? SizedBox(width: 26, height: 30, child: Icon(LucideIcons.x, size: 14, color: AppColors.fg(0.7)))
                      : _AvatarStack(friends: watchingFriends),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toast {
  _Toast({required this.id, required this.actor, required this.watching});

  final int id;
  final Friend actor;
  final WatchingTarget watching;
}

/// A friend just started (or switched to) something: a card bottom-right
/// for 10 seconds with the backdrop, what it is and "Watch too" (website:
/// WatchingToastManager).
class WatchingToasts extends ConsumerStatefulWidget {
  const WatchingToasts({super.key});

  @override
  ConsumerState<WatchingToasts> createState() => _WatchingToastsState();
}

class _WatchingToastsState extends ConsumerState<WatchingToasts> {
  final _toasts = <_Toast>[];
  final _timers = <Timer>[];
  StreamSubscription<WatchingPush>? _subscription;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(friendsEventsProvider).watchingPushes.listen((push) {
      final watching = push.watching;
      if (watching == null || !mounted) return;
      final toast = _Toast(id: _nextId++, actor: push.actor, watching: watching);
      setState(() => _toasts.add(toast));
      _timers.add(Timer(const Duration(seconds: 10), () => _dismiss(toast.id)));
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _dismiss(int id) {
    if (mounted) setState(() => _toasts.removeWhere((toast) => toast.id == id));
  }

  @override
  Widget build(BuildContext context) {
    if (_toasts.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 12,
      children: [
        for (final toast in _toasts) _WatchingToastCard(key: ValueKey(toast.id), toast: toast, onDismiss: () => _dismiss(toast.id)),
      ],
    );
  }
}

class _WatchingToastCard extends ConsumerStatefulWidget {
  const _WatchingToastCard({super.key, required this.toast, required this.onDismiss});

  final _Toast toast;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_WatchingToastCard> createState() => _WatchingToastCardState();
}

class _WatchingToastCardState extends ConsumerState<_WatchingToastCard> with SingleTickerProviderStateMixin {
  late final _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..forward();

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final watching = widget.toast.watching;
    final actor = widget.toast.actor;
    final preview = ref.watch(titlePreviewProvider((watching.type, watching.tmdbId)));
    final loaded = preview.hasValue || preview.hasError;
    final record = preview.value;
    final backdrop = tmdbImage(record?.backgroundImgURL ?? record?.posterImgURL, TmdbSize.w780);
    final isMovie = watching.type == RecordType.movie;
    final typeIcon = isMovie ? LucideIcons.film : LucideIcons.tv;
    final description = record?.description;
    final curved = CurvedAnimation(parent: _enter, curve: auroraEase);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(curved),
        child: Pressable(
          onTap: () {
            widget.onDismiss();
            openWatching(context, watching);
          },
          pressedScale: 0.98,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.fg(0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.75), blurRadius: 55, spreadRadius: -15, offset: const Offset(0, 25)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.black,
                        child: backdrop != null
                            ? AuroraImage(url: backdrop)
                            : ColoredBox(
                                color: AppColors.fg(0.1),
                                child: Icon(typeIcon, size: 28, color: AppColors.fg(0.3)),
                              ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [AppColors.surface, AppColors.surface.withValues(alpha: 0.1), Colors.transparent],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Pressable(
                          onTap: widget.onDismiss,
                          semanticLabel: t('friends.dismiss'),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.5)),
                            child: Icon(LucideIcons.x, size: 13, color: Colors.white.withValues(alpha: 0.8)),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 8,
                        right: 12,
                        child: Row(
                          children: [
                            FriendAvatar(person: actor, size: 22, ringColor: AppColors.surface),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${actor.displayName?.isNotEmpty == true ? actor.displayName! : '?'} · ${t('friends.watching').toLowerCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  shadows: [Shadow(color: Color(0xCC000000), blurRadius: 2, offset: Offset(0, 1))],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        watching.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      DefaultTextStyle.merge(
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.fg(0.55)),
                        child: Row(
                          children: [
                            Icon(typeIcon, size: 11, color: AppColors.fg(0.55)),
                            const SizedBox(width: 6),
                            Text(isMovie ? t('watchlist.movie') : t('watchlist.series')),
                            if (watching.season != null && watching.episode != null) ...[
                              const SizedBox(width: 6),
                              Text('•', style: TextStyle(color: AppColors.fg(0.25))),
                              const SizedBox(width: 6),
                              Text('S${watching.season} E${watching.episode}'),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!loaded)
                        const Row(spacing: 6, children: [PulsePlaceholder(width: 56, height: 20), PulsePlaceholder(width: 64, height: 20)])
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final genre in previewGenres(record, 3))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.fg(0.05),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.fg(0.1)),
                                ),
                                child: Text(
                                  genre,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.fg(0.7)),
                                ),
                              ),
                          ],
                        ),
                      if (loaded && description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, height: 1.6, color: AppColors.fg(0.6)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow_rounded, size: 14, color: AppColors.onWhite),
                            const SizedBox(width: 6),
                            Text(
                              t('friends.watchToo'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onWhite),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
