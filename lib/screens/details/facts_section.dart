import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/locale.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_heading.dart';

/// A title's facts panel (GET /get-movie-facts, /get-series-facts).
final _factsProvider = FutureProvider.family<Map<String, dynamic>?, ({RecordType type, String tmdbId})>((ref, key) async {
  final data = await ref.watch(apiClientProvider).getJson(key.type == RecordType.movie ? '/get-movie-facts' : '/get-series-facts', {
    'tmdbId': key.tmdbId,
  });
  return data is Map<String, dynamic> ? data : null;
});

/// The most common original languages, named in the app's four languages
/// (Flutter has no locale-aware language names); others show their code.
const _languageNames = <String, Map<String, String>>{
  'en': {'en': 'English', 'bg': 'Английски', 'el': 'Αγγλικά', 'es': 'Inglés'},
  'es': {'en': 'Spanish', 'bg': 'Испански', 'el': 'Ισπανικά', 'es': 'Español'},
  'fr': {'en': 'French', 'bg': 'Френски', 'el': 'Γαλλικά', 'es': 'Francés'},
  'de': {'en': 'German', 'bg': 'Немски', 'el': 'Γερμανικά', 'es': 'Alemán'},
  'it': {'en': 'Italian', 'bg': 'Италиански', 'el': 'Ιταλικά', 'es': 'Italiano'},
  'ja': {'en': 'Japanese', 'bg': 'Японски', 'el': 'Ιαπωνικά', 'es': 'Japonés'},
  'ko': {'en': 'Korean', 'bg': 'Корейски', 'el': 'Κορεατικά', 'es': 'Coreano'},
  'zh': {'en': 'Chinese', 'bg': 'Китайски', 'el': 'Κινεζικά', 'es': 'Chino'},
  'cn': {'en': 'Cantonese', 'bg': 'Кантонски', 'el': 'Καντονέζικα', 'es': 'Cantonés'},
  'hi': {'en': 'Hindi', 'bg': 'Хинди', 'el': 'Χίντι', 'es': 'Hindi'},
  'ru': {'en': 'Russian', 'bg': 'Руски', 'el': 'Ρωσικά', 'es': 'Ruso'},
  'pt': {'en': 'Portuguese', 'bg': 'Португалски', 'el': 'Πορτογαλικά', 'es': 'Portugués'},
  'tr': {'en': 'Turkish', 'bg': 'Турски', 'el': 'Τουρκικά', 'es': 'Turco'},
  'th': {'en': 'Thai', 'bg': 'Тайландски', 'el': 'Ταϊλανδικά', 'es': 'Tailandés'},
  'sv': {'en': 'Swedish', 'bg': 'Шведски', 'el': 'Σουηδικά', 'es': 'Sueco'},
  'da': {'en': 'Danish', 'bg': 'Датски', 'el': 'Δανικά', 'es': 'Danés'},
  'no': {'en': 'Norwegian', 'bg': 'Норвежки', 'el': 'Νορβηγικά', 'es': 'Noruego'},
  'pl': {'en': 'Polish', 'bg': 'Полски', 'el': 'Πολωνικά', 'es': 'Polaco'},
  'nl': {'en': 'Dutch', 'bg': 'Нидерландски', 'el': 'Ολλανδικά', 'es': 'Neerlandés'},
  'bg': {'en': 'Bulgarian', 'bg': 'Български', 'el': 'Βουλγαρικά', 'es': 'Búlgaro'},
  'el': {'en': 'Greek', 'bg': 'Гръцки', 'el': 'Ελληνικά', 'es': 'Griego'},
  'uk': {'en': 'Ukrainian', 'bg': 'Украински', 'el': 'Ουκρανικά', 'es': 'Ucraniano'},
  'ar': {'en': 'Arabic', 'bg': 'Арабски', 'el': 'Αραβικά', 'es': 'Árabe'},
  'he': {'en': 'Hebrew', 'bg': 'Иврит', 'el': 'Εβραϊκά', 'es': 'Hebreo'},
  'id': {'en': 'Indonesian', 'bg': 'Индонезийски', 'el': 'Ινδονησιακά', 'es': 'Indonesio'},
  'tl': {'en': 'Tagalog', 'bg': 'Тагалог', 'el': 'Ταγκαλόγκ', 'es': 'Tagalo'},
  'fi': {'en': 'Finnish', 'bg': 'Фински', 'el': 'Φινλανδικά', 'es': 'Finés'},
};

typedef _Tile = ({IconData icon, String label, String value});
typedef _Person = ({String name, String? photo, String initials, List<String> jobs});

/// Crew shown — any more and the card gets crowded (same as the website).
const _maxCrew = 3;
typedef _Page = ({Widget icon, String url, String label});

/// The website's FactsSection, at phone width: the people behind the title
/// (director / writers, a series' creators) with their photos, the key
/// numbers as tiles (original title and language, budget and revenue,
/// network), and the official / social pages as pills. Nothing until a title
/// has facts.
class FactsSection extends ConsumerWidget {
  const FactsSection({super.key, required this.record});

  final CinemaRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tmdbId = record.tmdbId;
    if (tmdbId == null || tmdbId.isEmpty) return const SizedBox.shrink();
    final facts = ref.watch(_factsProvider((type: record.type, tmdbId: tmdbId))).value;
    if (facts == null) return const SizedBox.shrink();

    final t = ref.watch(translatorProvider);
    final locale = ref.watch(localeProvider).name;
    final usd = NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: 0);
    String? text(String key) => facts[key] is String && (facts[key] as String).isNotEmpty ? facts[key] as String : null;
    int? number(String key) => facts[key] is num && (facts[key] as num) > 0 ? (facts[key] as num).toInt() : null;
    String job(String name) => t('facts.job.$name') == 'facts.job.$name' ? name : t('facts.job.$name');

    // Only icons the released app already ships (a Shorebird patch can't add
    // icon glyphs).
    final language = text('originalLanguage');
    final networks = (facts['networks'] as List?)?.whereType<String>().toList() ?? const [];
    final tiles = <_Tile>[
      if (text('originalTitle') case final value?) (icon: LucideIcons.clapperboard, label: t('facts.originalTitle'), value: value),
      if (language != null)
        (icon: LucideIcons.messageCircle, label: t('facts.originalLanguage'), value: _languageNames[language]?[locale] ?? language.toUpperCase()),
      if (number('budget') case final value?) (icon: LucideIcons.creditCard, label: t('facts.budget'), value: usd.format(value)),
      if (number('revenue') case final value?) (icon: LucideIcons.flame, label: t('facts.revenue'), value: usd.format(value)),
      if (networks.isNotEmpty) (icon: LucideIcons.tv, label: t('facts.networks'), value: networks.join(', ')),
    ];
    final crew = <_Person>[
      for (final member in (facts['crew'] as List?) ?? const [])
        if (member is Map && member['name'] is String)
          (
            name: member['name'] as String,
            photo: member['profilePath'] as String?,
            initials: (member['name'] as String)
                .split(RegExp(r'\s+'))
                .where((part) => part.isNotEmpty)
                .take(2)
                .map((part) => part[0].toUpperCase())
                .join(),
            jobs: [
              for (final name in (member['jobs'] as List?) ?? const [])
                if (name is String) job(name),
            ],
          ),
    ];
    final iconColor = AppColors.fg(0.8);
    final pages = <_Page>[
      if (text('homepage') case final value?) (icon: Icon(LucideIcons.globe, size: 15, color: iconColor), url: value, label: t('facts.homepage')),
      if (text('imdbId') case final value?)
        (icon: FaIcon(FontAwesomeIcons.imdb, size: 15, color: iconColor), url: 'https://www.imdb.com/title/$value/', label: 'IMDb'),
      if (text('facebookId') case final value?)
        (icon: FaIcon(FontAwesomeIcons.facebook, size: 15, color: iconColor), url: 'https://www.facebook.com/$value', label: 'Facebook'),
      if (text('instagramId') case final value?)
        (icon: FaIcon(FontAwesomeIcons.instagram, size: 15, color: iconColor), url: 'https://www.instagram.com/$value/', label: 'Instagram'),
      if (text('twitterId') case final value?)
        (icon: FaIcon(FontAwesomeIcons.twitter, size: 15, color: iconColor), url: 'https://x.com/$value', label: 'X'),
      if (text('youtubeId') case final value?)
        (
          icon: FaIcon(FontAwesomeIcons.youtube, size: 15, color: iconColor),
          url: 'https://www.youtube.com/${value.startsWith('@') ? value : '@$value'}',
          label: 'YouTube',
        ),
    ];
    if (tiles.isEmpty && crew.isEmpty && pages.isEmpty) return const SizedBox.shrink();

    final eyebrow = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.8, color: AppColors.fg(0.45));
    final card = BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(t('facts.title')),
          if (crew.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: card.copyWith(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.02)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('facts.crew').toUpperCase(), style: eyebrow),
                  const SizedBox(height: 4),
                  // At most three, as a list with thin dividers between them.
                  for (var i = 0; i < crew.length && i < _maxCrew; i++)
                    Container(
                      padding: EdgeInsets.only(top: 12, bottom: i == crew.length - 1 || i == _maxCrew - 1 ? 0 : 12),
                      decoration: i == 0
                          ? null
                          : BoxDecoration(
                              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                            ),
                      child: _PersonRow(person: crew[i]),
                    ),
                ],
              ),
            ),
          if (tiles.isNotEmpty) ...[
            if (crew.isNotEmpty) const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final tile in tiles)
                      SizedBox(
                        width: width,
                        child: _FactTile(tile: tile, decoration: card, eyebrow: eyebrow),
                      ),
                  ],
                );
              },
            ),
          ],
          if (pages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final page in pages)
                  Pressable(
                    onTap: () => launchUrl(Uri.parse(page.url), mode: LaunchMode.externalApplication),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          page.icon,
                          const SizedBox(width: 8),
                          Text(
                            page.label,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.fg(0.8)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person});

  final _Person person;

  @override
  Widget build(BuildContext context) {
    final photo = person.photo;
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
            gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0.05)]),
          ),
          clipBehavior: Clip.antiAlias,
          child: photo != null
              ? AuroraImage(url: tmdbImage(photo, TmdbSize.w300))
              : Text(person.initials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final job in person.jobs)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        job,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.fg(0.75)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.tile, required this.decoration, required this.eyebrow});

  final _Tile tile;
  final BoxDecoration decoration;
  final TextStyle eyebrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Big faint icon in the corner.
          Positioned(right: -22, bottom: -22, child: Icon(tile.icon, size: 80, color: Colors.white.withValues(alpha: 0.05))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: -6, offset: const Offset(0, 6))],
                ),
                child: Icon(tile.icon, size: 18, color: AppColors.onWhite),
              ),
              const SizedBox(height: 14),
              Text(tile.label.toUpperCase(), style: eyebrow),
              const SizedBox(height: 4),
              Text(tile.value, style: const TextStyle(fontSize: 17, height: 1.25, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
