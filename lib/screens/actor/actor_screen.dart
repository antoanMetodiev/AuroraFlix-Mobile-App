import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/catalog_api.dart';
import '../../core/dates.dart';
import '../../core/i18n/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../shell/app_shell.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/footer.dart';
import '../../widgets/image_lightbox.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';
import '../../widgets/rating_ring.dart';
import '../details/details_background.dart';

final _latestWorksProvider = FutureProvider.family<List<ActorWork>, String>((ref, imdbId) async {
  final works = await ref.watch(catalogApiProvider).actorLatestWorks(imdbId);
  // Newest first; titles without a release date go last.
  return [...works]..sort((a, b) => releaseDateValue(b.releaseDate).compareTo(releaseDateValue(a.releaseDate)));
});

/// Longer biographies start collapsed behind "Show more".
const _bioPreviewChars = 520;

enum _Filter { all, movies, series }

final _eyebrow = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.8, color: AppColors.fg(0.45));
final _card = BoxDecoration(
  color: Colors.white.withValues(alpha: 0.05),
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
);

/// An actor's page (website: ActorDetailsView) over the blurred background
/// of the title it was opened from: a glowing portrait (tap to enlarge), the
/// role pill and big name, stat tiles, social pills, the biography card, then
/// the filmography grid (newest first, All / Movies / Series) with the
/// "check for more movies" button. Only reachable from a cast list — there's
/// no "get actor" endpoint, so a bare link has nothing to show.
class ActorScreen extends ConsumerStatefulWidget {
  const ActorScreen({super.key, required this.actor, this.backgroundPath});

  final Actor? actor;
  final String? backgroundPath;

  @override
  ConsumerState<ActorScreen> createState() => _ActorScreenState();
}

class _ActorScreenState extends ConsumerState<ActorScreen> {
  _Filter _filter = _Filter.all;
  bool _bioExpanded = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final locale = ref.watch(localeProvider).name;
    final padding = shellContentPadding(context);
    final actor = widget.actor;

    if (actor == null) {
      return Padding(
        padding: padding,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 96),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('actor.notAvailable'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Text(
                  t('actor.onlyFromCast'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.fg(0.7)),
                ),
                const SizedBox(height: 16),
                Pressable(
                  onTap: () => context.go('/movies'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      t('actor.backToMovies'),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.onWhite),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final image = actor.imageURL != null ? tmdbImage(actor.imageURL, TmdbSize.w500) : fallbackActorImage;
    final gender = int.tryParse(actor.gender ?? '');
    final age = calculateAge(actor.birthday);
    final birthDate = DateTime.tryParse(actor.birthday ?? '');
    final popularity = double.tryParse(actor.popularity ?? '');
    final works = actor.imdbId == null ? null : ref.watch(_latestWorksProvider(actor.imdbId!));

    // The website's Cake / CalendarDays / MapPin icons aren't in the shipped
    // icon font (a patch can't add glyphs), so the nearest shipped ones stand in.
    final stats = <(IconData, String, String)>[
      if (age.isNotEmpty) (LucideIcons.user, t('actor.statAge'), t('actor.ageShort', {'age': age})),
      if (birthDate != null) (LucideIcons.clock, t('actor.statBorn'), DateFormat.yMMMMd(intlLocale(locale)).format(birthDate)),
      if (actor.placeOfBirth != null && actor.placeOfBirth!.isNotEmpty) (LucideIcons.globe, t('actor.statPlace'), actor.placeOfBirth!),
      if (popularity != null && popularity > 0) (LucideIcons.flame, t('actor.statPopularity'), popularity.toStringAsFixed(1)),
    ];
    final socials = <(FaIconData, String, String)>[
      if (actor.imdbId != null) (FontAwesomeIcons.imdb, 'IMDb', 'https://www.imdb.com/name/${actor.imdbId}/'),
      if (actor.instagramUsername != null)
        (FontAwesomeIcons.instagram, 'Instagram', 'https://www.instagram.com/${actor.instagramUsername}'),
      if (actor.twitterUsername != null) (FontAwesomeIcons.twitter, 'X', 'https://x.com/${actor.twitterUsername}'),
      if (actor.facebookUsername != null) (FontAwesomeIcons.facebook, 'Facebook', 'https://www.facebook.com/${actor.facebookUsername}'),
    ];
    final biography = actor.biography?.trim() ?? '';
    final bioIsLong = biography.length > _bioPreviewChars;

    return Stack(
      children: [
        // The background of the title this actor was opened from — same still, blur and shade.
        if (widget.backgroundPath != null) Positioned.fill(child: BlurredPageBackdrop(path: widget.backgroundPath)),
        ListView(
          padding: padding,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 48),
              child: Column(
                children: [
                  _Portrait(
                    image: image,
                    onTap: actor.imageURL == null
                        ? null
                        : () => showImageLightbox(context, paths: [actor.imageURL!], initialIndex: 0, shape: LightboxShape.actor),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.sparkles, size: 13, color: Colors.white.withValues(alpha: 0.85)),
                        const SizedBox(width: 6),
                        Text(
                          gender == 1 ? t('actor.roleFemale') : t('actor.roleMale'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.white.withValues(alpha: 0.65)],
                    ).createShader(bounds),
                    child: Text(
                      actor.nameInRealLife,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 38,
                        height: 0.98,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        shadows: [Shadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 4))],
                      ),
                    ),
                  ),
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final (icon, label, value) in stats)
                              SizedBox(
                                width: width,
                                child: _StatTile(icon: icon, label: label, value: value),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                  if (socials.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (icon, label, url) in socials)
                          Pressable(
                            onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FaIcon(icon, size: 15, color: AppColors.fg(0.8)),
                                  const SizedBox(width: 8),
                                  Text(
                                    label,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.fg(0.8)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (biography.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: _card.copyWith(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.02)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('actor.biography').toUpperCase(), style: _eyebrow),
                          const SizedBox(height: 12),
                          Text(
                            bioIsLong && !_bioExpanded ? '${biography.substring(0, _bioPreviewChars).trimRight()}…' : biography,
                            style: TextStyle(fontSize: 16, height: 1.75, color: AppColors.fg(0.8)),
                          ),
                          if (bioIsLong) ...[
                            const SizedBox(height: 16),
                            Pressable(
                              onTap: () => setState(() => _bioExpanded = !_bioExpanded),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                child: Text(
                                  _bioExpanded ? t('actor.showLess') : t('actor.showMore'),
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.fg(0.85)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _Filmography(
              works: works == null || works.hasError ? const [] : works.value,
              filter: _filter,
              onFilter: (filter) => setState(() => _filter = filter),
              locale: locale,
              action: actor.imdbId == null ? null : _MoreMoviesButton(imdbId: actor.imdbId!, actorName: actor.nameInRealLife),
            ),
            // Fades the background out into the footer's solid black.
            const SizedBox(
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.background],
                  ),
                ),
              ),
            ),
            const SiteFooter(),
          ],
        ),
      ],
    );
  }
}

/// The portrait in its soft white halo, rounded and glowing.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.image, required this.onTap});

  final String? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const width = 224.0;
    return Pressable(
      pressedScale: 0.97,
      onTap: onTap,
      child: Container(
        width: width,
        height: width * 3 / 2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 60, spreadRadius: 12),
            BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: -8),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null) AuroraImage(url: image!),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [Color(0x80000000), Colors.transparent],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Big faint icon in the corner.
          Positioned(right: -18, bottom: -18, child: Icon(icon, size: 72, color: Colors.white.withValues(alpha: 0.05))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: -6, offset: const Offset(0, 6)),
                  ],
                ),
                child: Icon(icon, size: 16, color: AppColors.onWhite),
              ),
              const SizedBox(height: 12),
              Text(label.toUpperCase(), style: _eyebrow),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Filmography": heading with the count, the request button, the
/// All / Movies / Series switch (only when there are both), then the grid.
/// [works] is null while loading.
class _Filmography extends ConsumerWidget {
  const _Filmography({required this.works, required this.filter, required this.onFilter, required this.locale, this.action});

  final List<ActorWork>? works;
  final _Filter filter;
  final ValueChanged<_Filter> onFilter;
  final String locale;
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final list = works ?? const <ActorWork>[];
    final seriesCount = list.where((work) => work.type == RecordType.series).length;
    final counts = {_Filter.all: list.length, _Filter.movies: list.length - seriesCount, _Filter.series: seriesCount};
    final shown = list
        .where(
          (work) => switch (filter) {
            _Filter.all => true,
            _Filter.movies => work.type != RecordType.series,
            _Filter.series => work.type == RecordType.series,
          },
        )
        .toList();
    final tabs = [
      (_Filter.all, t('actor.filterAll'), LucideIcons.sparkles),
      (_Filter.movies, t('nav.movies'), LucideIcons.clapperboard),
      (_Filter.series, t('nav.series'), LucideIcons.tv),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.45), blurRadius: 12)],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(t('actor.filmography'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              ),
              if (works != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    '${list.length}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.fg(0.7)),
                  ),
                ),
              ],
            ],
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
          if (works != null && counts[_Filter.movies]! > 0 && seriesCount > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (value, label, icon) in tabs)
                    Pressable(
                      onTap: () => onFilter(value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: filter == value ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: filter == value
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    blurRadius: 16,
                                    spreadRadius: -4,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: filter == value ? AppColors.onWhite : AppColors.fg(0.65)),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: filter == value ? AppColors.onWhite : AppColors.fg(0.65),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${counts[value]}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: filter == value ? const Color(0xFF737373) : AppColors.fg(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (works == null)
            _grid([for (var i = 0; i < 6; i++) const Shimmer(borderRadius: BorderRadius.all(Radius.circular(16)))])
          else if (shown.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              decoration: _card,
              child: Text(
                t('actor.noWorks'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.fg(0.6)),
              ),
            )
          else
            _grid([for (final work in shown) _WorkCard(work: work, locale: locale)]),
        ],
      ),
    );
  }

  /// Two posters a row on a phone (three on a wider screen), 2:3 each.
  Widget _grid(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560 ? 3 : 2;
      final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [for (final child in children) SizedBox(width: width, height: width * 3 / 2, child: child)],
      );
    },
  );
}

class _WorkCard extends ConsumerWidget {
  const _WorkCard({required this.work, required this.locale});

  final ActorWork work;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final rating = double.tryParse(work.tmdbRating);
    final poster = tmdbImage(work.posterURL, TmdbSize.w500);
    final isSeries = work.type == RecordType.series;

    return Pressable(
      onTap: () => openTitle(context, work.type, work.detailsId),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (poster != null) AuroraImage(url: poster),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xD9000000), Color(0x1A000000), Colors.transparent],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isSeries ? LucideIcons.tv : LucideIcons.clapperboard, size: 11, color: Colors.white.withValues(alpha: 0.9)),
                    const SizedBox(width: 4),
                    Text(
                      (isSeries ? t('watchlist.series') : t('watchlist.movie')).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (rating != null && rating > 0)
              Positioned(
                top: 8,
                right: 8,
                child: RatingRing(value: rating, size: RatingRingSize.xs),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    work.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: [Shadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 2))],
                    ),
                  ),
                  if (work.releaseDate != null && work.releaseDate!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      formatReleaseDate(work.releaseDate, locale),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _cooldown = Duration(minutes: 3);
const _cooldownKeyPrefix = 'add_movies_actor_cooldown_';

/// "Check for more movies with X" — asks the generators to add this actor's
/// other movies; then a per-actor three-minute cooldown with a countdown.
class _MoreMoviesButton extends ConsumerStatefulWidget {
  const _MoreMoviesButton({required this.imdbId, required this.actorName});

  final String imdbId;
  final String actorName;

  @override
  ConsumerState<_MoreMoviesButton> createState() => _MoreMoviesButtonState();
}

class _MoreMoviesButtonState extends ConsumerState<_MoreMoviesButton> {
  Duration _remaining = Duration.zero;
  bool _requesting = false;
  Timer? _ticker;

  String get _key => '$_cooldownKeyPrefix${widget.imdbId}';

  @override
  void initState() {
    super.initState();
    _update();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final last = ref.read(sharedPreferencesProvider).getInt(_key);
    final left = last == null ? Duration.zero : _cooldown - DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last));
    final next = left.isNegative ? Duration.zero : left;
    if (mounted && next.inSeconds != _remaining.inSeconds) setState(() => _remaining = next);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _request() async {
    setState(() => _requesting = true);
    await ref.read(catalogApiProvider).requestMoreMoviesForActor(widget.imdbId);
    await ref.read(sharedPreferencesProvider).setInt(_key, DateTime.now().millisecondsSinceEpoch);
    if (mounted) {
      setState(() {
        _requesting = false;
        _remaining = _cooldown;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);

    if (_remaining > Duration.zero) {
      final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.fg(0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.fg(0.15)),
        ),
        child: Text(
          '${t('carousel.checkingStarted')} ${_remaining.inMinutes}:$seconds',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.fg(0.7)),
        ),
      );
    }

    return Pressable(
      onTap: _requesting ? null : _request,
      child: Opacity(
        opacity: _requesting ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_requesting) ...[const Spinner(size: 14, color: AppColors.onWhite), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  '${t('carousel.checkForMoreWith')} ${widget.actorName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onWhite),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
