import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n/locale.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../router.dart';
import 'pressable.dart';

/// The website's SeoIntro, which sits right above the footer on every page:
/// the "watch online" title and intro, then every genre as a chip, for
/// movies and for series. Built into [SiteFooter], so every screen that has
/// the footer has this too — same as the site's root layout.
class SeoIntro extends ConsumerWidget {
  const SeoIntro({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final locale = t.locale;
    final copy = _copy[locale]!;

    String chipLabel(String genre, RecordType type) {
      final isMovie = type == RecordType.movie;
      if (locale == AppLocale.bg) {
        final seo = _genreSeo[genre];
        if (seo != null) return isMovie ? seo.movies : seo.series;
        return '${t.genre(genre)} ${isMovie ? 'филми' : 'сериали'}';
      }
      if (locale == AppLocale.en) return '${t.genre(genre)} ${isMovie ? 'movies' : 'series'}';
      // Under a "Movies by genre" / "Series by genre" heading, the genre alone reads fine.
      return t.genre(genre);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 16),
      child: Container(
        padding: const EdgeInsets.only(top: 48),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(copy.title, style: display(const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.4))),
            const SizedBox(height: 16),
            for (final (index, paragraph) in copy.paragraphs.indexed)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                child: Text(paragraph, style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.fg(0.65))),
              ),
            for (final type in RecordType.values) ...[
              SizedBox(height: type == RecordType.movie ? 40 : 32),
              Text(
                type == RecordType.movie ? copy.moviesHeading : copy.seriesHeading,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.fg(0.85)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final genre in _allGenres)
                    _GenreChip(
                      label: chipLabel(genre, type),
                      onTap: () => context.go(CatalogQuery(type: type, genre: genre).location()),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.fg(0.7))),
      ),
    );
  }
}

/// The website's ALL_GENRES (lib/genres.ts), in its order.
const _allGenres = [
  'Action', 'Horror', 'Comedy', 'Drama', 'Mystery', 'Romance', 'Adventure', 'Crime', //
  'Fantasy', 'Historical', 'Animation', 'Thriller', 'Western', 'Biography', //
  'Documentary', 'Family', 'Musical', 'Sports', 'War',
];

/// The website's GENRE_SEO (lib/seo.ts): the Bulgarian genre-page headings.
const _genreSeo = <String, ({String movies, String series})>{
  'Action': (movies: 'Екшън филми', series: 'Екшън сериали'),
  'Horror': (movies: 'Филми на ужасите', series: 'Сериали на ужасите'),
  'Comedy': (movies: 'Комедии', series: 'Комедийни сериали'),
  'Drama': (movies: 'Драми', series: 'Драматични сериали'),
  'Mystery': (movies: 'Мистерии', series: 'Мистериозни сериали'),
  'Romance': (movies: 'Романтични филми', series: 'Романтични сериали'),
  'Adventure': (movies: 'Приключенски филми', series: 'Приключенски сериали'),
  'Crime': (movies: 'Криминални филми', series: 'Криминални сериали'),
  'Fantasy': (movies: 'Фентъзи филми', series: 'Фентъзи сериали'),
  'Historical': (movies: 'Исторически филми', series: 'Исторически сериали'),
  'Animation': (movies: 'Анимационни филми', series: 'Анимационни сериали'),
  'Thriller': (movies: 'Трилъри', series: 'Трилър сериали'),
  'Western': (movies: 'Уестърни', series: 'Уестърн сериали'),
  'Biography': (movies: 'Биографични филми', series: 'Биографични сериали'),
  'Documentary': (movies: 'Документални филми', series: 'Документални сериали'),
  'Family': (movies: 'Семейни филми', series: 'Семейни сериали'),
  'Musical': (movies: 'Мюзикъли', series: 'Музикални сериали'),
  'Sports': (movies: 'Спортни филми', series: 'Спортни сериали'),
  'War': (movies: 'Военни филми', series: 'Военни сериали'),
};

typedef _Copy = ({String title, List<String> paragraphs, String moviesHeading, String seriesHeading});

/// The website's SeoIntro COPY, word for word.
const _copy = <AppLocale, _Copy>{
  AppLocale.bg: (
    title: 'Онлайн филми и сериали с БГ субтитри',
    paragraphs: [
      'AuroraFlix е мястото да гледаш филми онлайн и сериали онлайн безплатно — в HD и 4K качество, с български субтитри и без регистрация. Всеки ден добавяме нови филми и нови епизоди, така че винаги има какво да пуснеш.',
      'Тук ще намериш нови филми 2026, най-гледаните холивудски заглавия, екшън филми, комедии, филми на ужасите, трилъри, анимационни филми за цялото семейство и хитови сериали с всички сезони и епизоди. За много от тях имаме собствени субтитри на български, които се зареждат директно в плейъра.',
      'Не намираш заглавието, което търсиш? Поръчай го и го добавяме в каталога.',
    ],
    moviesHeading: 'Филми по жанрове',
    seriesHeading: 'Сериали по жанрове',
  ),
  AppLocale.en: (
    title: 'Watch movies and series online',
    paragraphs: [
      'AuroraFlix is where you watch movies and series online for free — in HD and 4K, with Bulgarian subtitles and no sign-up needed. New movies and new episodes are added every day.',
      "Find the newest 2026 releases, Hollywood hits, action movies, comedies, horror, thrillers, animated movies for the whole family and hit series with every season and episode. Many of them come with our own Bulgarian subtitles, loaded straight into the player.",
      "Can't find a title? Order it and we'll add it to the catalog.",
    ],
    moviesHeading: 'Movies by genre',
    seriesHeading: 'Series by genre',
  ),
  AppLocale.el: (
    title: 'Δες ταινίες και σειρές online',
    paragraphs: [
      'Το AuroraFlix είναι το μέρος για να βλέπεις ταινίες και σειρές online δωρεάν — σε HD και 4K, χωρίς εγγραφή. Κάθε μέρα προσθέτουμε νέες ταινίες και νέα επεισόδια.',
      'Θα βρεις τις νέες κυκλοφορίες του 2026, χολιγουντιανές επιτυχίες, ταινίες δράσης, κωμωδίες, ταινίες τρόμου, θρίλερ, κινούμενα σχέδια για όλη την οικογένεια και δημοφιλείς σειρές με όλες τις σεζόν και τα επεισόδια.',
      'Δεν βρίσκεις έναν τίτλο; Παράγγειλέ τον και θα τον προσθέσουμε στον κατάλογο.',
    ],
    moviesHeading: 'Ταινίες ανά είδος',
    seriesHeading: 'Σειρές ανά είδος',
  ),
  AppLocale.es: (
    title: 'Ver películas y series online',
    paragraphs: [
      'AuroraFlix es el lugar para ver películas y series online gratis — en HD y 4K, sin registrarte. Cada día añadimos películas nuevas y nuevos episodios.',
      'Encontrarás los estrenos de 2026, éxitos de Hollywood, películas de acción, comedias, terror, suspense, animación para toda la familia y series de éxito con todas sus temporadas y episodios.',
      '¿No encuentras un título? Pídelo y lo añadimos al catálogo.',
    ],
    moviesHeading: 'Películas por género',
    seriesHeading: 'Series por género',
  ),
};
