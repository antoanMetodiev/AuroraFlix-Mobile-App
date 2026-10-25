import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/dates.dart';
import '../../core/i18n/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../shell/site_header.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/effects.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/pressable.dart';
import '../../widgets/rating_ring.dart';
import '../../widgets/record_actions.dart';
import 'hero_background.dart';

const _swipeThreshold = 50.0;

/// The homepage hero (website: HeroSection, phone layout): trending trailers
/// playing behind the current title's logo, synopsis, chips and actions;
/// prev/next with a 01 / 20 counter and a mute toggle; and the strip of
/// trailer thumbnails along the bottom. Swipe sideways to switch.
class HeroSection extends ConsumerStatefulWidget {
  const HeroSection({super.key, required this.items});

  final List<CinemaRecord> items;

  @override
  ConsumerState<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends ConsumerState<HeroSection> {
  int _index = 0;
  bool _muted = true;
  bool _videoReady = false;

  /// The playing trailer's progress (0–1). A notifier, not state: it ticks
  /// every 250ms, and as state each tick rebuilt the whole hero — trailer
  /// WebView and rail included. Only the rail's bar listens to it.
  final _progress = ValueNotifier<double>(0);

  void _goTo(int index) {
    final count = widget.items.length;
    _progress.value = 0;
    setState(() {
      _videoReady = false;
      _index = ((index % count) + count) % count;
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _next() => _goTo(_index + 1);
  void _previous() => _goTo(_index - 1);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final screen = MediaQuery.sizeOf(context);
    // The site's `-mt-16 h-[85vh] min-h-[624px]`: the hero starts at the very
    // top of the screen, under the floating header (the home list has no top
    // padding), so it's taller by the header's height — the backdrop / trailer
    // shows around the header island instead of a black strip.
    final header = SiteHeader.reservedHeight(context);
    final height = math.max(screen.height * 0.85 - 64, 560.0) + header;

    if (widget.items.isEmpty) {
      return SizedBox(
        height: screen.height * 0.7 - 64 + header,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              t('hero.welcome'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.fg(0.8)),
            ),
          ),
        ),
      );
    }

    final record = widget.items[_index];
    final onScreen = TickerMode.valuesOf(context).enabled;

    return SizedBox(
      height: height,
      child: FilmGrain(
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Everything above the bottom controls swipes; the trailer strip
              // scrolls sideways on its own, so it stays out of this.
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() < _swipeThreshold) return;
                  velocity < 0 ? _next() : _previous();
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    HeroBackground(
                      key: ValueKey((record.id, onScreen)),
                      record: record,
                      showVideo: onScreen,
                      muted: _muted,
                      onEnded: _next,
                      onReady: () => setState(() => _videoReady = true),
                      onProgress: (value) => _progress.value = value,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black, Color(0x1A000000), Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 168,
                      child: _HeroDetails(key: ValueKey('details-${record.id}'), record: record),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _RoundButton(icon: LucideIcons.chevronLeft, label: t('hero.previous'), onTap: _previous),
                        const SizedBox(width: 8),
                        Text.rich(
                          TextSpan(
                            text: '${_index + 1}'.padLeft(2, '0'),
                            children: [
                              TextSpan(
                                text: ' / ${'${widget.items.length}'.padLeft(2, '0')}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RoundButton(icon: LucideIcons.chevronRight, label: t('hero.next'), onTap: _next),
                        const Spacer(),
                        _MuteButton(
                          muted: _muted,
                          enabled: _videoReady,
                          label: _muted ? t('hero.unmute') : t('hero.mute'),
                          onTap: () => setState(() => _muted = !_muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _TrailerRail(items: widget.items, currentIndex: _index, progress: _progress, onSelect: _goTo),
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

/// Logo (or title), synopsis, chips and actions — lifts into place on every
/// title switch (`animate-hero-content-in`).
class _HeroDetails extends ConsumerWidget {
  const _HeroDetails({super.key, required this.record});

  final CinemaRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final description = record.description ?? '';
    final shortDescription = description.length > 230 ? '${description.substring(0, 230)}..' : description;
    final chipStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.75));

    Widget chip(String text, {bool highlighted = false, VoidCallback? onTap}) => Pressable(
      onTap: onTap,
      pressedScale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: highlighted ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: highlighted ? chipStyle.copyWith(color: Colors.white) : chipStyle),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: auroraEase,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 16 * (1 - value)), child: child),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: record.logoURL != null
                ? SizedBox(
                    height: 64,
                    width: 140,
                    child: AuroraImage(url: record.logoURL, fit: BoxFit.contain, alignment: Alignment.centerLeft),
                  )
                : Text(
                    record.title,
                    style: display(
                      const TextStyle(fontSize: 36, height: 1.02, fontWeight: FontWeight.w600, letterSpacing: -0.8, color: Colors.white),
                    ),
                  ),
          ),
          if (shortDescription.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                shortDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.6, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                chip(record.isSeries ? t('hero.badgeSeries') : t('hero.badgeMovie'), highlighted: true),
                for (final genre in record.genreList) chip(t.genre(genre), onTap: () => openGenre(context, record.type, genre)),
                if (record.releaseDate != null) chip(formatReleaseDate(record.releaseDate, ref.watch(localeProvider).name)),
                chip('4K'),
              ],
            ),
          ),
          Row(
            children: [
              _WatchNowButton(label: t('hero.watchNow'), onTap: () => openRecord(context, record)),
              const SizedBox(width: 12),
              WatchlistButton(record: record),
              const SizedBox(width: 8),
              LikeButton(record: record),
              const SizedBox(width: 12),
              if (record.rating != null) RatingRing(value: record.rating!),
            ],
          ),
        ],
      ),
    );
  }
}

class _WatchNowButton extends StatelessWidget {
  const _WatchNowButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.17), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.35, color: Colors.black),
        ),
      ),
    );
  }
}

/// 36px glass circle — prev / next.
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.45),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

/// On phones the hero offers only mute/unmute (volume is the hardware
/// buttons' job), inert until the trailer is actually playing.
class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.muted, required this.enabled, required this.label, required this.onTap});

  final bool muted;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: _RoundIcon(icon: muted ? LucideIcons.volumeX : LucideIcons.volume2, label: label, onTap: enabled ? onTap : null),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 18, color: Colors.white)),
    );
  }
}

const _thumbWidth = 112.0;
const _thumbGap = 10.0;

/// The strip of trailers along the bottom: each title's backdrop, the
/// playing one lit up with a bar filling as its trailer plays; scrolls
/// sideways and keeps the playing card centred.
class _TrailerRail extends ConsumerStatefulWidget {
  const _TrailerRail({required this.items, required this.currentIndex, required this.progress, required this.onSelect});

  final List<CinemaRecord> items;
  final int currentIndex;
  final ValueListenable<double> progress;
  final ValueChanged<int> onSelect;

  @override
  ConsumerState<_TrailerRail> createState() => _TrailerRailState();
}

class _TrailerRailState extends ConsumerState<_TrailerRail> {
  final _controller = ScrollController();

  @override
  void didUpdateWidget(_TrailerRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) _centre();
  }

  void _centre() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target = widget.currentIndex * (_thumbWidth + _thumbGap) - (position.viewportDimension - _thumbWidth) / 2;
    _controller.animateTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);

    return SizedBox(
      height: _thumbWidth * 9 / 16 + 12,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.none,
        itemCount: widget.items.length,
        separatorBuilder: (context, index) => const SizedBox(width: _thumbGap),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final active = index == widget.currentIndex;
          final image = tmdbImage(item.backgroundImgURL, TmdbSize.w300) ?? tmdbImage(item.posterImgURL, TmdbSize.w342);

          return Pressable(
            onTap: () => widget.onSelect(index),
            semanticLabel: '${t('hero.show')} ${item.title}',
            child: AnimatedOpacity(
              opacity: active ? 1 : 0.55,
              duration: const Duration(milliseconds: 300),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _thumbWidth,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: active ? 0.8 : 0.1)),
                  boxShadow: active ? [BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 24)] : const [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AuroraImage(url: image),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xE6000000), Color(0x33000000), Colors.transparent],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (item.isSeries ? t('hero.badgeSeries') : t('hero.badgeMovie')).toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.35,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      if (active)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 3,
                          child: ColoredBox(
                            color: Colors.white.withValues(alpha: 0.2),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ValueListenableBuilder<double>(
                                valueListenable: widget.progress,
                                builder: (context, progress, bar) => AnimatedFractionallySizedBox(
                                  duration: const Duration(milliseconds: 300),
                                  widthFactor: progress,
                                  heightFactor: 1,
                                  child: bar,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 8)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
