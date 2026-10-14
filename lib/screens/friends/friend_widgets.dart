import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/friends/friends_api.dart';
import '../../core/i18n/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/pressable.dart';

/// Someone's round picture, or their initial on a faint disc (website:
/// components/ui/avatar.tsx).
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({super.key, required this.person, this.size = 32, this.ringColor, this.ringWidth = 2});

  final Friend person;
  final double size;
  final Color? ringColor;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    final name = person.displayName?.trim() ?? '';
    final url = person.profileImageURL;
    final avatar = SizedBox(
      width: size,
      height: size,
      child: url != null && url.isNotEmpty
          ? ClipOval(child: AuroraImage(url: url))
          : DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.fg(0.15)),
              child: Center(
                child: Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w600, color: AppColors.fg(0.8), height: 1),
                ),
              ),
            ),
    );
    if (ringColor == null) return avatar;
    return Container(
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(shape: BoxShape.circle, color: ringColor),
      child: avatar,
    );
  }
}

/// The site's big centered dialog card (FriendsModal / UserProfileModal):
/// black/75 blurred backdrop, a rounded-[2rem] surface card a bit above
/// center with a soft top glow, a header row and a scrolling body.
Future<void> showAuroraModal(BuildContext context, {required WidgetBuilder builder}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: auroraEase, reverseCurve: Curves.easeIn);
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: animation,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.75)),
                ),
              ),
            ),
          ),
          FadeTransition(
            opacity: curved,
            child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
          ),
        ],
      );
    },
  );
}

class AuroraModalCard extends ConsumerWidget {
  const AuroraModalCard({super.key, required this.header, required this.body, this.glowAlpha = 0.06});

  final Widget header;
  final Widget body;
  final double glowAlpha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, size.height * 0.1),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 896, maxHeight: size.height * 0.9),
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 90, spreadRadius: -15, offset: const Offset(0, 30)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 224,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: glowAlpha),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: header),
                                const SizedBox(width: 12),
                                Pressable(
                                  onTap: () => Navigator.of(context).pop(),
                                  semanticLabel: ref.watch(translatorProvider)('nav.closeMenu'),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.fg(0.05)),
                                    child: Icon(LucideIcons.x, size: 19, color: AppColors.fg(0.6)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(child: body),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens what a friend is watching.
void openWatching(BuildContext context, WatchingTarget watching) => openTitle(context, watching.type, watching.tmdbId);

/// Small genre chips under a "watching" title; a pulsing placeholder while
/// the preview loads.
class PreviewGenres extends StatelessWidget {
  const PreviewGenres({super.key, required this.loaded, required this.genres, this.fontSize = 9});

  final bool loaded;
  final List<String> genres;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const PulsePlaceholder(width: 48, height: 14);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final genre in genres)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.fg(0.1), borderRadius: BorderRadius.circular(999)),
            child: Text(
              genre,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: AppColors.fg(0.6)),
            ),
          ),
      ],
    );
  }
}

/// Tailwind's animate-pulse on a rounded block.
class PulsePlaceholder extends StatefulWidget {
  const PulsePlaceholder({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<PulsePlaceholder> createState() => _PulsePlaceholderState();
}

class _PulsePlaceholderState extends State<PulsePlaceholder> with SingleTickerProviderStateMixin {
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
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: AppColors.fg(0.1), borderRadius: BorderRadius.circular(999)),
    ),
  );
}

/// The small green "● WATCHING" label.
class WatchingLabel extends ConsumerWidget {
  const WatchingLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.emerald),
      ),
      const SizedBox(width: 4),
      Text(
        ref.watch(translatorProvider)('friends.watching').toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.25, color: AppColors.emerald),
      ),
    ],
  );
}

/// Poster thumbnail for a "watching" row — the type icon until there's one.
class WatchingPoster extends StatelessWidget {
  const WatchingPoster({
    super.key,
    required this.watching,
    required this.posterPath,
    required this.width,
    required this.height,
    required this.radius,
  });

  final WatchingTarget watching;
  final String? posterPath;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final poster = tmdbImage(posterPath, TmdbSize.w342);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: AppColors.fg(0.1), borderRadius: BorderRadius.circular(radius)),
      clipBehavior: Clip.antiAlias,
      child: poster != null
          ? AuroraImage(url: poster)
          : Icon(watching.type.name == 'movie' ? LucideIcons.film : LucideIcons.tv, size: width * 0.32, color: AppColors.fg(0.3)),
    );
  }
}
