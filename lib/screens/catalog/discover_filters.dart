import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/catalog_api.dart';
import '../../core/dates.dart';
import '../../core/i18n/dictionary.g.dart';
import '../../core/i18n/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/loader.dart';
import '../../widgets/modern_select.dart';
import '../../widgets/pressable.dart';

/// Every genre the catalog filters by (website: lib/genres.ts).
final allGenres = genreTranslations.keys.toList();

/// The list pages' filters, phone layout (website: DiscoverFilters): a
/// "Filters" pill with the active count that unfolds genre / year / sort
/// pickers and the actor search; active filters show as removable chips.
class DiscoverFiltersBar extends ConsumerStatefulWidget {
  const DiscoverFiltersBar({super.key, required this.query});

  final CatalogQuery query;

  @override
  ConsumerState<DiscoverFiltersBar> createState() => _DiscoverFiltersState();
}

class _DiscoverFiltersState extends ConsumerState<DiscoverFiltersBar> {
  bool _open = false;

  CatalogQuery get _query => widget.query;

  void _navigate(CatalogQuery next) => context.go(next.location());

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final query = _query;
    final activeCount = [query.genre, query.year, query.actor, query.sort, if (query.bgAudio) true].where((value) => value != null).length;

    final sortValue = switch (query.sort) {
      SortOption.topRated => 'top_rated',
      SortOption.oldest => 'oldest',
      _ => 'newest',
    };
    final currentYear = DateTime.now().year;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width * 0.03).add(const EdgeInsets.only(top: 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              onTap: () => setState(() => _open = !_open),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _open ? Colors.white : AppColors.fg(0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _open ? Colors.transparent : AppColors.fg(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.slidersHorizontal, size: 15, color: _open ? AppColors.onWhite : AppColors.fg(0.8)),
                    const SizedBox(width: 8),
                    Text(
                      t('filters.toggle'),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _open ? AppColors.onWhite : AppColors.fg(0.8)),
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.fg(0.25)),
                        child: Text(
                          '$activeCount',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _open ? AppColors.onWhite : AppColors.foreground),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: auroraEase,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ModernSelect(
                          expand: true,
                          value: query.genre ?? '',
                          options: [SelectOption('', t('filters.allGenres')), for (final genre in allGenres) SelectOption(genre, t.genre(genre))],
                          onChanged: (value) => _navigate(query.copyWith(genre: () => value.isEmpty ? null : value)),
                        ),
                        const SizedBox(height: 12),
                        ModernSelect(
                          expand: true,
                          value: query.year ?? '',
                          options: [
                            SelectOption('', t('filters.allYears')),
                            for (var year = currentYear; year >= 1950; year--) SelectOption('$year', '$year'),
                          ],
                          onChanged: (value) => _navigate(query.copyWith(year: () => value.isEmpty ? null : value)),
                        ),
                        const SizedBox(height: 12),
                        ModernSelect(
                          expand: true,
                          value: sortValue,
                          options: [
                            SelectOption('newest', t('filters.sortNewest')),
                            SelectOption('top_rated', t('filters.sortTopRated')),
                            SelectOption('oldest', t('filters.sortOldest')),
                          ],
                          onChanged: (value) => _navigate(
                            query.copyWith(
                              sort: () => switch (value) {
                                'top_rated' => SortOption.topRated,
                                'oldest' => SortOption.oldest,
                                _ => null,
                              },
                            ),
                          ),
                        ),
                        // Only movies carry the flag so far (ZenoPlay's БГ Аудио category).
                        if (query.type == RecordType.movie) ...[
                          const SizedBox(height: 12),
                          _BgAudioToggle(
                            on: query.bgAudio,
                            onTap: () => _navigate(query.copyWith(bgAudio: !query.bgAudio)),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _ActorField(
                          type: query.type,
                          initial: query.actor ?? '',
                          onPick: (name) => _navigate(query.copyWith(actor: () => name)),
                          onClear: () {
                            if (query.actor != null) _navigate(query.copyWith(actor: () => null));
                          },
                        ),
                      ],
                    ),
                  ),
          ),
          if (activeCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (query.genre != null)
                    _FilterChip(
                      label: '${t('filters.genre')}: ${t.genre(query.genre!)}',
                      onRemove: () => _navigate(query.copyWith(genre: () => null)),
                    ),
                  if (query.year != null)
                    _FilterChip(
                      label: '${t('filters.year')}: ${query.year}',
                      onRemove: () => _navigate(query.copyWith(year: () => null)),
                    ),
                  if (query.actor != null)
                    _FilterChip(
                      label: '${t('filters.actor')}: ${query.actor}',
                      onRemove: () => _navigate(query.copyWith(actor: () => null)),
                    ),
                  if (query.bgAudio) _FilterChip(label: t('filters.bgAudio'), onRemove: () => _navigate(query.copyWith(bgAudio: false))),
                  if (query.sort != null)
                    _FilterChip(
                      label: query.sort == SortOption.topRated ? t('filters.sortTopRated') : t('filters.sortOldest'),
                      onRemove: () => _navigate(query.copyWith(sort: () => null)),
                    ),
                  Pressable(
                    pressedScale: 1,
                    onTap: () => context.go(CatalogQuery(type: query.type).location()),
                    child: Text(
                      t('filters.clearAll'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.fg(0.5)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The "БГ аудио" pill — white while on, like the website's toggle.
class _BgAudioToggle extends ConsumerWidget {
  const _BgAudioToggle({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final color = on ? AppColors.onWhite : AppColors.fg(0.8);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: on ? Colors.white : AppColors.fg(0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? Colors.transparent : AppColors.fg(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.audioLines, size: 15, color: color),
            const SizedBox(width: 8),
            Text(
              t('filters.bgAudio'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.fg(0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.fg(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.fg(0.8)),
          ),
          const SizedBox(width: 6),
          Pressable(
            pressedScale: 1,
            onTap: onRemove,
            child: Icon(LucideIcons.x, size: 14, color: AppColors.fg(0.5)),
          ),
        ],
      ),
    );
  }
}

/// "Search by actor..." with live suggestions: photo (opens the actor page),
/// name + age (filters by them), and their socials.
class _ActorField extends ConsumerStatefulWidget {
  const _ActorField({required this.type, required this.initial, required this.onPick, required this.onClear});

  final RecordType type;
  final String initial;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;

  @override
  ConsumerState<_ActorField> createState() => _ActorFieldState();
}

class _ActorFieldState extends ConsumerState<_ActorField> {
  late final _controller = TextEditingController(text: widget.initial);
  final _focus = FocusNode();
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _fieldKey = GlobalKey();
  Timer? _debounce;
  List<Actor> _suggestions = const [];
  bool _searching = false;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _requestId++;
      setState(() {
        _searching = false;
        _suggestions = const [];
      });
      _portal.hide();
      widget.onClear();
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final id = ++_requestId;
      final results = await ref.read(catalogApiProvider).suggestActors(widget.type, value);
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
      results.isEmpty ? _portal.hide() : _portal.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) {
          final width = (_fieldKey.currentContext?.findRenderObject() as RenderBox?)?.size.width ?? 300;
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _portal.hide),
              ),
              CompositedTransformFollower(
                link: _link,
                targetAnchor: Alignment.bottomLeft,
                offset: const Offset(0, 6),
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    width: width,
                    constraints: const BoxConstraints(maxHeight: 384),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.fg(0.1)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 50, spreadRadius: -12, offset: const Offset(0, 20)),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) => _ActorSuggestion(
                        actor: _suggestions[index],
                        ageLabel: t('actor.age'),
                        onOpen: () {
                          _portal.hide();
                          openActor(context, _suggestions[index]);
                        },
                        onPick: () {
                          final name = _suggestions[index].nameInRealLife;
                          _controller.text = name;
                          _portal.hide();
                          widget.onPick(name);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: ListenableBuilder(
          listenable: _focus,
          builder: (context, _) => AnimatedContainer(
            key: _fieldKey,
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: AppColors.fg(_focus.hasFocus ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _focus.hasFocus ? Colors.white : AppColors.fg(0.1), width: _focus.hasFocus ? 2 : 1),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onChanged,
              onTap: () {
                if (_suggestions.isNotEmpty) _portal.show();
              },
              cursorColor: Colors.white,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: t('filters.actorPlaceholder'),
                hintStyle: TextStyle(color: AppColors.fg(0.35)),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                prefixIcon: Icon(LucideIcons.user, size: 15, color: AppColors.fg(0.4)),
                suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(14), child: Spinner(size: 13)) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActorSuggestion extends StatelessWidget {
  const _ActorSuggestion({required this.actor, required this.ageLabel, required this.onOpen, required this.onPick});

  final Actor actor;
  final String ageLabel;
  final VoidCallback onOpen;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final age = calculateAge(actor.birthday);
    final socials = <(FaIconData, String)>[
      if (actor.instagramUsername != null) (FontAwesomeIcons.instagram, 'https://www.instagram.com/${actor.instagramUsername}'),
      if (actor.twitterUsername != null) (FontAwesomeIcons.twitter, 'https://x.com/${actor.twitterUsername}'),
      if (actor.facebookUsername != null) (FontAwesomeIcons.facebook, 'https://www.facebook.com/${actor.facebookUsername}'),
      if (actor.youtubeChannel != null) (FontAwesomeIcons.youtube, 'https://www.youtube.com/${actor.youtubeChannel}'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          Pressable(
            pressedScale: 1,
            onTap: onOpen,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.fg(0.1),
                border: Border.all(color: AppColors.fg(0.15)),
              ),
              clipBehavior: Clip.antiAlias,
              child: AuroraImage(url: actor.imageURL != null ? tmdbImage(actor.imageURL, TmdbSize.w342) : fallbackActorImage),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Pressable(
              pressedScale: 1,
              onTap: onPick,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actor.nameInRealLife,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.fg(0.9)),
                  ),
                  if (age.isNotEmpty) Text('$ageLabel $age', style: TextStyle(fontSize: 12, color: AppColors.fg(0.45))),
                  if (socials.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          for (final (icon, url) in socials)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Pressable(
                                pressedScale: 1,
                                onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                                child: FaIcon(icon, size: 11, color: AppColors.fg(0.35)),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
