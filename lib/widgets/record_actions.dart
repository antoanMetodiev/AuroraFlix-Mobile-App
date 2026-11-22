import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/i18n/locale.dart';
import '../core/library/watchlist.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'burst.dart';
import 'pressable.dart';

/// `standard` sits on a page (44px, faint fill); `overlay` sits on a poster
/// (32px, dark glass) — the website's two button variants.
enum RecordActionVariant { standard, overlay }

/// Bookmark button: adds the title to the watchlist; once added it turns
/// into a filled white tile and stays that way (website: AddToWatchlistButton).
class WatchlistButton extends ConsumerWidget {
  const WatchlistButton({super.key, required this.record, this.variant = RecordActionVariant.standard});

  final CinemaRecord record;
  final RecordActionVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final items = ref.watch(watchlistProvider);
    final loading = items == null;
    final added = !loading && ref.read(watchlistProvider.notifier).has(recordKey(record));

    return _ActionTile(
      icon: LucideIcons.bookmark,
      activeIcon: FontAwesomeIcons.solidBookmark,
      active: added,
      dimmed: loading,
      variant: variant,
      label: added ? t('watchlistButton.added') : t('watchlistButton.add'),
      burstColors: const [Colors.white, Color(0xFFFCD34D), Color(0xFF7DD3FC)],
      onTap: added || loading ? null : () => ref.read(watchlistProvider.notifier).add(LibraryItem.fromRecord(record)),
    );
  }
}

/// Heart button (website: LikeButton) — toggles the like; signed out it does
/// nothing, like the site. Past the cap it shows the "limit reached" note.
class LikeButton extends ConsumerStatefulWidget {
  const LikeButton({super.key, required this.record, this.variant = RecordActionVariant.standard});

  final CinemaRecord record;
  final RecordActionVariant variant;

  @override
  ConsumerState<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<LikeButton> {
  bool _showLimit = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggle(bool liked) async {
    final likes = ref.read(likesProvider.notifier);
    final key = recordKey(widget.record);
    if (liked) {
      await likes.remove(key);
      return;
    }
    final result = await likes.add(LibraryItem.fromRecord(widget.record));
    if (result == LikeResult.limit && mounted) {
      setState(() => _showLimit = true);
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 3500), () {
        if (mounted) setState(() => _showLimit = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final items = ref.watch(likesProvider);
    final loading = items == null;
    final liked = !loading && ref.read(likesProvider.notifier).has(recordKey(widget.record));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _ActionTile(
          icon: LucideIcons.heart,
          activeIcon: FontAwesomeIcons.solidHeart,
          active: liked,
          dimmed: loading,
          variant: widget.variant,
          label: liked ? t('likeButton.liked') : t('likeButton.like'),
          burstColors: const [Color(0xFFFB7185), Color(0xFFF43F5E), Color(0xFFFDA4AF)],
          onTap: loading ? null : () => _toggle(liked),
        ),
        if (_showLimit)
          Positioned(
            top: (widget.variant == RecordActionVariant.overlay ? 32 : 44) + 8,
            right: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 200),
              curve: auroraEase,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.scale(scale: 0.94 + 0.06 * value, alignment: Alignment.topRight, child: child),
              ),
              child: Container(
                width: 224,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.fg(0.15)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: Text(
                  t('likeButton.limitReached'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.fg(0.8)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.variant,
    required this.label,
    required this.onTap,
    required this.burstColors,
    this.dimmed = false,
  });

  /// The particles when it turns on (website: Burst).
  final List<Color> burstColors;

  final IconData icon;

  /// Lucide icons are outline-only; the filled state (`fill-current` on the
  /// site) uses Font Awesome's solid glyph instead.
  final FaIconData activeIcon;
  final bool active;
  final bool dimmed;
  final RecordActionVariant variant;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final overlay = variant == RecordActionVariant.overlay;
    final size = overlay ? 32.0 : 44.0;

    final Color background;
    final Color border;
    final Color foreground;
    if (active) {
      background = Colors.white;
      border = Colors.transparent;
      foreground = AppColors.onWhite;
    } else if (overlay) {
      background = Colors.black.withValues(alpha: 0.6);
      border = Colors.white.withValues(alpha: 0.25);
      foreground = Colors.white;
    } else {
      background = AppColors.fg(0.05);
      border = AppColors.fg(0.15);
      foreground = AppColors.fg(0.7);
    }

    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: dimmed ? 0.5 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Center(
            child: Celebrate(
              active: active,
              colors: burstColors,
              distance: overlay ? 20 : 28,
              child: active ? FaIcon(activeIcon, size: overlay ? 12 : 16, color: foreground) : Icon(icon, size: overlay ? 14 : 18, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
