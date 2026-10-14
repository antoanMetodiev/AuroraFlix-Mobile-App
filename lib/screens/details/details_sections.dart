import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/i18n/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/embed_frame/embed_frame.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/image_lightbox.dart';
import '../../widgets/pressable.dart';
import '../../widgets/rating_ring.dart';
import '../../widgets/record_actions.dart';
import '../../widgets/reveal.dart';
import '../../widgets/section_heading.dart';

/// The top of a title page (website: DetailsHeader): a cinematic backdrop
/// banner with the title, year, tagline, genre chips, date and rating ring
/// over layered gradients; below it the poster, the overview and the
/// watchlist / like buttons.
class DetailsHeader extends ConsumerWidget {
  const DetailsHeader({super.key, required this.record});

  final CinemaRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final chipStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8));

    Widget chip(String text, {VoidCallback? onTap}) => Pressable(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Text(text, style: chipStyle),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: (screenHeight * 0.46).clamp(320, double.infinity),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (record.backgroundImgURL != null) AuroraImage(url: tmdbImage(record.backgroundImgURL, TmdbSize.w1280)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black, Color(0x59000000), Color(0x1A000000)],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xBF000000), Colors.transparent, Colors.transparent],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x99000000), Colors.transparent, Colors.transparent])),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: record.title,
                        children: [
                          if (record.year != null)
                            TextSpan(
                              text: ' (${record.year})',
                              style: TextStyle(fontWeight: FontWeight.w400, color: Colors.white.withValues(alpha: 0.55)),
                            ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: Colors.white,
                        shadows: [Shadow(color: Color(0xB3000000), blurRadius: 12, offset: Offset(0, 2))],
                      ),
                    ),
                    if (record.specialText != null && record.specialText!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          record.specialText!,
                          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final genre in record.genreList) chip(genre, onTap: () => openGenre(context, record.type, genre)),
                        if (record.releaseDate != null) chip(record.releaseDate!),
                        if (record.rating != null)
                          RatingRing(
                            value: record.rating!,
                            size: RatingRingSize.sm,
                            border: BorderSide(color: Colors.white.withValues(alpha: 0.25), width: 2),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (record.posterImgURL != null)
                Container(
                  width: 128,
                  height: 192,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 45, spreadRadius: -10, offset: const Offset(0, 20)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AuroraImage(url: tmdbImage(record.posterImgURL, TmdbSize.w780)),
                ),
              const SizedBox(height: 24),
              if (record.description != null && record.description!.isNotEmpty) ...[
                Text(
                  'OVERVIEW',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: AppColors.fg(0.45)),
                ),
                const SizedBox(height: 8),
                Text(record.description!, style: TextStyle(fontSize: 16, height: 1.75, color: AppColors.fg(0.8))),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  WatchlistButton(record: record),
                  const SizedBox(width: 8),
                  LikeButton(record: record),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Trailer" — the YouTube trailer, playable, in a rounded 16:9 card.
class TrailerSection extends ConsumerWidget {
  const TrailerSection({super.key, required this.trailerUrl});

  final String trailerUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final embedUrl = trailerUrl.replaceFirst('https://www.youtube.com/watch?v=', 'https://www.youtube.com/embed/');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(t('sections.trailer')),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF050505),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 60, offset: const Offset(0, 20))],
              ),
              clipBehavior: Clip.antiAlias,
              child: EmbedFrame(url: embedUrl),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Top Cast" — a sideways row of actor cards; each opens the actor page.
class CastSection extends ConsumerWidget {
  const CastSection({super.key, required this.cast});

  final List<Actor> cast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cast.isEmpty) return const SizedBox.shrink();
    final t = ref.watch(translatorProvider);
    const cardWidth = 152.0;

    return InViewOnce(
      threshold: 0.3,
      builder: (context, inView) => Reveal(
        visible: inView,
        offset: 48,
        child: Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeading(t('sections.topCast'), padding: const EdgeInsets.symmetric(horizontal: 16)),
              SizedBox(
                height: cardWidth * 14.7 / 10.8 + 8 + 24,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cast.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final actor = cast[index];
                    final name = actor.nameInRealLife.length >= 17 ? '${actor.nameInRealLife.substring(0, 16)}..' : actor.nameInRealLife;
                    return Pressable(
                      onTap: () => openActor(context, actor),
                      child: SizedBox(
                        width: cardWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 10.8 / 14.7,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AuroraImage(
                                  url: actor.imageURL != null ? tmdbImage(actor.imageURL, TmdbSize.w342) : fallbackActorImage,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(name, maxLines: 1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Images" — backdrops / posters tabs, a 2-column grid of 8 with "Load
/// More", each opening the lightbox on that picture.
class ImageGallery extends ConsumerStatefulWidget {
  const ImageGallery({super.key, required this.images});

  final List<MediaImage> images;

  @override
  ConsumerState<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends ConsumerState<ImageGallery> {
  static const _pageSize = 8;

  ImageType _type = ImageType.backdrop;
  int _visibleCount = _pageSize;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    if (widget.images.isEmpty) return const SizedBox.shrink();

    final allOfType = widget.images.where((image) => image.imageType == _type).toList();
    final visible = allOfType.take(_visibleCount).toList();
    final expanded = visible.length == allOfType.length && allOfType.length > _pageSize;
    final aspect = _type == ImageType.backdrop ? 21.3 / 11.8 : 22 / 30;

    return InViewOnce(
      threshold: 0.3,
      builder: (context, inView) => AnimatedOpacity(
        opacity: inView ? 1 : 0,
        duration: const Duration(milliseconds: 500),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 64, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 16,
                spacing: 16,
                children: [
                  SectionHeading(t('sections.images'), spacing: 0),
                  _TypeTabs(
                    value: _type,
                    labels: {ImageType.backdrop: t('sections.backdrops'), ImageType.poster: t('sections.posters')},
                    onChanged: (type) => setState(() {
                      _type = type;
                      _visibleCount = _pageSize;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 16) / 2;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (var i = 0; i < visible.length; i++)
                        Pressable(
                          onTap: () => showImageLightbox(
                            context,
                            paths: visible.map((image) => image.imageURL).toList(),
                            initialIndex: i,
                            shape: _type == ImageType.backdrop ? LightboxShape.backdrop : LightboxShape.poster,
                          ),
                          pressedScale: 0.95,
                          child: Container(
                            width: width,
                            height: width / aspect,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: AuroraImage(url: tmdbImage(visible[i].imageURL, TmdbSize.w780)),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (allOfType.length > _pageSize)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Pressable(
                      onTap: () => setState(() => _visibleCount = expanded ? _pageSize : _visibleCount + _pageSize),
                      child: Container(
                        width: 160,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.fg(0.25)),
                        ),
                        child: Text(
                          (expanded ? t('sections.showLess') : t('sections.loadMore')).toUpperCase(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.value, required this.labels, required this.onChanged});

  final ImageType value;
  final Map<ImageType, String> labels;
  final ValueChanged<ImageType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.fg(0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.fg(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final type in const [ImageType.backdrop, ImageType.poster])
            GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: type == value ? Colors.white : Colors.white.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  labels[type]!,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: type == value ? AppColors.onWhite : AppColors.fg(0.6)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
