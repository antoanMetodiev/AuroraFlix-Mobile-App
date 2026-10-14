import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/catalog_api.dart';
import '../../core/dates.dart';
import '../../core/i18n/locale.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../shell/app_shell.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/footer.dart';
import '../../widgets/image_lightbox.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';
import '../../widgets/work_carousel.dart';

final _latestWorksProvider = FutureProvider.family<List<ActorWork>, String>(
  (ref, imdbId) => ref.watch(catalogApiProvider).actorLatestWorks(imdbId),
);

/// An actor's page (website: ActorDetailsView): portrait (tap to enlarge),
/// name, biography, socials, the facts list, then their other titles with
/// the "check for more movies" button. Only reachable from a cast list —
/// there's no "get actor" endpoint, so a bare link has nothing to show.
class ActorScreen extends ConsumerWidget {
  const ActorScreen({super.key, required this.actor});

  final Actor? actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final padding = shellContentPadding(context);
    final actor = this.actor;

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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.foreground, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      t('actor.backToMovies'),
                      style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.background),
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
    final biography = actor.biography != null && actor.biography!.length > 600 ? actor.biography!.substring(0, 600) : actor.biography;
    final gender = int.tryParse(actor.gender ?? '');
    final popularity = double.tryParse(actor.popularity ?? '');
    final works = actor.imdbId == null ? null : ref.watch(_latestWorksProvider(actor.imdbId!));

    final socials = <(FaIconData, String)>[
      if (actor.instagramUsername != null) (FontAwesomeIcons.instagram, 'https://www.instagram.com/${actor.instagramUsername}'),
      if (actor.twitterUsername != null) (FontAwesomeIcons.twitter, 'https://x.com/${actor.twitterUsername}'),
      if (actor.imdbId != null) (FontAwesomeIcons.imdb, 'https://www.imdb.com/name/${actor.imdbId}/?ref_=tt_cst_i_1'),
      if (actor.facebookUsername != null) (FontAwesomeIcons.facebook, 'https://www.facebook.com/${actor.facebookUsername}'),
    ];

    Widget fact(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: '$label ',
          children: [
            TextSpan(
              text: value,
              style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.fg(0.6)),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
    );

    return ListView(
      padding: padding,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            children: [
              Pressable(
                pressedScale: 0.95,
                onTap: actor.imageURL == null
                    ? null
                    : () => showImageLightbox(context, paths: [actor.imageURL!], initialIndex: 0, shape: LightboxShape.actor),
                child: Container(
                  width: 208,
                  height: 208 * 20 / 13,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 15)],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AuroraImage(url: image),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                actor.nameInRealLife,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: 0.6),
              ),
              if (biography != null && biography.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '- $biography',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.75,
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.italic,
                    color: AppColors.fg(0.85),
                  ),
                ),
              ],
              if (socials.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final (icon, url) in socials)
                        Pressable(
                          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: FaIcon(icon, size: 24, color: AppColors.foreground),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (actor.placeOfBirth != null) fact(t('actor.placeOfBirth'), actor.placeOfBirth!),
              if (actor.birthday != null)
                fact(t('actor.birthday'), '${actor.birthday} (${t('actor.age')} ${calculateAge(actor.birthday)})'),
              if (actor.knownFor != null) fact(t('actor.knownFor'), actor.knownFor!),
              if (gender == 1 || gender == 2) fact(t('actor.gender'), gender == 1 ? t('actor.female') : t('actor.male')),
              if (popularity != null) fact(t('actor.popularity'), popularity.toStringAsFixed(1)),
            ],
          ),
        ),
        if (works != null && works.isLoading)
          const Loader()
        else
          WorkCarousel(
            heading: t('carousel.latestWorks'),
            items: [
              for (final work in works?.value ?? const <ActorWork>[])
                WorkCardItem(
                  title: work.title,
                  posterURL: work.posterURL,
                  tmdbRating: work.tmdbRating,
                  type: work.type,
                  detailsId: work.detailsId,
                ),
            ],
            action: actor.imdbId == null ? null : _MoreMoviesButton(imdbId: actor.imdbId!, actorName: actor.nameInRealLife),
          ),
        const SiteFooter(),
      ],
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
