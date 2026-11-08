import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/catalog_api.dart';
import '../../core/i18n/locale.dart';
import '../../core/library/localized_titles.dart';
import '../../core/library/playlists.dart';
import '../../core/library/watchlist.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../models/models.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/library_poster_card.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';
import '../../widgets/rating_ring.dart';
import '../watchlist/watchlist_screen.dart';

const _searchPageSize = 10;

/// One playlist (website: PlaylistCard): a header row — public/private
/// badge, name, "Public · 5 titles", rename / delete, chevron — that unfolds
/// to "Add titles" and the playlist's posters. Rename and delete swap the
/// header for an inline form / confirmation.
class PlaylistCard extends ConsumerStatefulWidget {
  const PlaylistCard({super.key, required this.playlist, required this.canManage, this.itemsPageSize});

  final Playlist playlist;
  final bool canManage;

  /// Show this many items at first, then this many more per "Load more".
  final int? itemsPageSize;

  @override
  ConsumerState<PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends ConsumerState<PlaylistCard> {
  bool _expanded = true;
  bool _adding = false;
  bool _editing = false;
  bool _confirmingDelete = false;
  bool _deleting = false;
  List<LibraryItem>? _items;
  late int _visibleItems = widget.itemsPageSize ?? 1 << 30;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await ref.read(playlistsApiProvider).items(widget.playlist.id);
    if (mounted) setState(() => _items = items);
  }

  Future<void> _remove(String recordId) async {
    setState(() => _items = _items?.where((item) => item.id != recordId).toList());
    await ref.read(playlistsApiProvider).removeItem(widget.playlist.id, recordId);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final playlist = widget.playlist;
    // Titles / posters in the app's current language.
    final items = localizeLibraryItems(ref, _items);
    final coverPosters = [for (final item in items ?? const <LibraryItem>[]) ?tmdbImage(item.posterImgURL, TmdbSize.w342)].take(4).toList();

    Widget header;
    if (_editing) {
      header = _PlaylistForm(
        initialName: playlist.name,
        initialPublic: playlist.isPublic,
        confirmLabel: t('playlists.save'),
        onCancel: () => setState(() => _editing = false),
        onSubmit: (name, isPublic) async {
          final ok = await ref.read(playlistsProvider.notifier).update(playlist.id, name, isPublic);
          if (ok && mounted) setState(() => _editing = false);
        },
      );
    } else if (_confirmingDelete) {
      header = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                t('playlists.deleteConfirm'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.fg(0.8)),
              ),
            ),
            const SizedBox(width: 12),
            RoundIconButton(icon: LucideIcons.x, label: t('playlists.cancel'), onTap: () => setState(() => _confirmingDelete = false)),
            const SizedBox(width: 6),
            RoundIconButton(
              icon: LucideIcons.check,
              label: t('playlists.delete'),
              primary: true,
              onTap: _deleting
                  ? null
                  : () async {
                      setState(() => _deleting = true);
                      await ref.read(playlistsProvider.notifier).delete(playlist.id);
                    },
            ),
          ],
        ),
      );
    } else {
      header = Pressable(
        pressedScale: 1,
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _CoverMosaic(posters: coverPosters),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: display(const TextStyle(fontSize: 20, height: 1.15, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(
                          icon: playlist.isPublic ? LucideIcons.globe : LucideIcons.lock,
                          label: playlist.isPublic ? t('playlists.visibilityPublic') : t('playlists.visibilityPrivate'),
                          white: playlist.isPublic,
                        ),
                        _Chip(icon: LucideIcons.film, label: t('playlists.itemCount', {'count': _items?.length ?? playlist.itemCount})),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.canManage) ...[
                RoundIconButton(icon: LucideIcons.pencil, label: t('playlists.rename'), onTap: () => setState(() => _editing = true)),
                const SizedBox(width: 6),
                RoundIconButton(icon: LucideIcons.trash2, label: t('playlists.delete'), onTap: () => setState(() => _confirmingDelete = true)),
                const SizedBox(width: 8),
              ],
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(LucideIcons.chevronDown, size: 17, color: AppColors.fg(0.5)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final showBody = _expanded && !_editing && !_confirmingDelete;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E10),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: _expanded ? 0.15 : 0.1)),
        boxShadow: _expanded ? [BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 70, spreadRadius: -30, offset: const Offset(0, 30))] : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // The newest title's poster, blurred behind the header.
          if (coverPosters.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 192,
              // Its own layer, painted once — scrolling never re-runs the blur.
              child: IgnorePointer(
                child: RepaintBoundary(
                  // Scaled up 25% for the blur — clipped so it never shows past the veil.
                  child: ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Transform.scale(
                          scale: 1.25,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24, tileMode: TileMode.decal),
                            // A small poster is plenty under a blur this strong.
                            child: AuroraImage(url: coverPosters.first),
                          ),
                        ),
                        // The site shows it at 30% over the card; a dark veil does
                        // the same without an extra layer.
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xB30E0E10), Color(0xC70E0E10), Color(0xFF0E0E10)],
                              stops: [0, 0.45, 0.85],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 96,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0.05), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: auroraEase,
                alignment: Alignment.topCenter,
                child: !showBody
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.canManage)
                              _AddItemsPanel(
                                playlistId: playlist.id,
                                existingIds: {...?_items?.map((item) => item.id)},
                                open: _adding,
                                onToggle: () => setState(() => _adding = !_adding),
                                onAdded: (item) => setState(() => _items = [item, ...?_items]),
                              ),
                            if (_items == null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(child: Spinner(size: 32)),
                              )
                            else if (_items!.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.fg(0.05)),
                                      child: Icon(LucideIcons.film, size: 18, color: AppColors.fg(0.3)),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(t('playlists.noItems'), style: TextStyle(fontSize: 14, color: AppColors.fg(0.5))),
                                  ],
                                ),
                              )
                            else
                              Padding(
                                padding: EdgeInsets.only(top: widget.canManage ? 20 : 0),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Two a row on a phone, three from 460px (the site's grid).
                                    final columns = constraints.maxWidth >= 720 ? 4 : (constraints.maxWidth >= 428 ? 3 : 2);
                                    final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        for (final item in items!.take(_visibleItems))
                                          SizedBox(
                                            width: width,
                                            child: LibraryPosterCard(
                                              key: ValueKey(item.id),
                                              item: item,
                                              onTap: () => closeModalsAnd(context, (context) => openLibraryItem(context, item)),
                                              // Every playlist starts expanded, so most tiles sit below the fold.
                                              lazy: true,
                                              compact: true,
                                              removeLabel: t('playlists.removeItemAria'),
                                              onRemove: widget.canManage ? () => _remove(item.id) : null,
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            if (widget.itemsPageSize != null && (_items?.length ?? 0) > _visibleItems)
                              LoadMoreButton(onTap: () => setState(() => _visibleItems += widget.itemsPageSize!)),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The playlist's cover: its first four posters in a 2×2 tile (fewer: the
/// first one fills it, none: an icon).
class _CoverMosaic extends StatelessWidget {
  const _CoverMosaic({required this.posters});

  final List<String> posters;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (posters.isEmpty) {
      content = Center(child: Icon(LucideIcons.listVideo, size: 26, color: Colors.white.withValues(alpha: 0.6)));
    } else if (posters.length < 4) {
      content = AuroraImage(url: posters.first);
    } else {
      content = ColoredBox(
        color: Colors.black,
        child: Column(
          children: [
            for (final row in [posters.sublist(0, 2), posters.sublist(2, 4)])
              Expanded(
                child: Row(
                  children: [
                    for (final poster in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(0.5),
                          child: AuroraImage(url: poster),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.04)],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 30, spreadRadius: -10, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

/// Small pill under the playlist's name — white for "Public".
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.white = false});

  final IconData icon;
  final String label;
  final bool white;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: white ? Colors.white : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(999),
      border: white ? null : Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: white ? AppColors.onWhite : AppColors.fg(0.75)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: white ? AppColors.onWhite : AppColors.fg(0.75)),
        ),
      ],
    ),
  );
}

/// Quiet full-width "Load more" under a paged list.
class LoadMoreButton extends ConsumerWidget {
  const LoadMoreButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          ref.watch(translatorProvider)('playlists.loadMore'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.fg(0.6)),
        ),
      ),
    ),
  );
}

/// 36px round button — outlined, or white for the confirming action.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.label, required this.onTap, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary ? Colors.white : Colors.transparent,
            border: primary ? null : Border.all(color: AppColors.fg(0.15)),
          ),
          child: Icon(icon, size: 15, color: primary ? AppColors.onWhite : AppColors.fg(0.6)),
        ),
      ),
    );
  }
}

/// Private | Public pill switch.
class VisibilityToggle extends ConsumerWidget {
  const VisibilityToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
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
          for (final (isPublic, icon, label) in [
            (false, LucideIcons.lock, t('playlists.visibilityPrivate')),
            (true, LucideIcons.globe, t('playlists.visibilityPublic')),
          ])
            Pressable(
              pressedScale: 1,
              onTap: () => onChanged(isPublic),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: value == isPublic ? Colors.white : Colors.white.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: value == isPublic ? AppColors.onWhite : AppColors.fg(0.6)),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: value == isPublic ? AppColors.onWhite : AppColors.fg(0.6)),
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

/// Name field + visibility + ✕ / ✓ — used to create and to rename.
class _PlaylistForm extends ConsumerStatefulWidget {
  const _PlaylistForm({required this.initialName, required this.initialPublic, required this.confirmLabel, required this.onCancel, required this.onSubmit});

  final String initialName;
  final bool initialPublic;
  final String confirmLabel;
  final VoidCallback onCancel;
  final Future<void> Function(String name, bool isPublic) onSubmit;

  @override
  ConsumerState<_PlaylistForm> createState() => PlaylistFormState();
}

class PlaylistFormState extends ConsumerState<_PlaylistForm> {
  late final _name = TextEditingController(text: widget.initialName);
  late bool _public = widget.initialPublic;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    await widget.onSubmit(_name.text.trim(), _public);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillTextField(
            controller: _name,
            hint: t('playlists.namePlaceholder'),
            autofocus: true,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              VisibilityToggle(value: _public, onChanged: (value) => setState(() => _public = value)),
              const Spacer(),
              RoundIconButton(icon: LucideIcons.x, label: t('playlists.cancel'), onTap: widget.onCancel),
              const SizedBox(width: 8),
              RoundIconButton(icon: LucideIcons.check, label: widget.confirmLabel, primary: true, onTap: _saving || _name.text.trim().isEmpty ? null : _submit),
            ],
          ),
        ],
      ),
    );
  }
}

/// The create form, standalone (top of the playlists screen).
class CreatePlaylistForm extends ConsumerWidget {
  const CreatePlaylistForm({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.fg(0.1)),
      ),
      child: _PlaylistForm(
        initialName: '',
        initialPublic: false,
        confirmLabel: t('playlists.create'),
        onCancel: onDone,
        onSubmit: (name, isPublic) async {
          if (await ref.read(playlistsProvider.notifier).create(name, isPublic)) onDone();
        },
      ),
    );
  }
}

/// Rounded faint input with a white focus ring (the site's playlist inputs).
class PillTextField extends StatefulWidget {
  const PillTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
    this.prefixIcon,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final Widget? suffix;

  @override
  State<PillTextField> createState() => _PillTextFieldState();
}

class _PillTextFieldState extends State<PillTextField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _focus,
      builder: (context, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: AppColors.fg(_focus.hasFocus ? 0.1 : 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _focus.hasFocus ? Colors.white : AppColors.fg(0.15), width: _focus.hasFocus ? 1.5 : 1),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          cursorColor: Colors.white,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: widget.hint,
            hintStyle: TextStyle(color: AppColors.fg(0.35)),
            contentPadding: EdgeInsets.fromLTRB(widget.prefixIcon == null ? 16 : 0, 11, 16, 11),
            prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon, size: 15, color: AppColors.fg(0.4)),
            suffixIcon: widget.suffix,
          ),
        ),
      ),
    );
  }
}

/// Poster tile for a saved title (playlist item, a friend's like): rating
/// badge, title and type icon; an optional remove ✕.
class LibraryPosterTile extends StatelessWidget {
  const LibraryPosterTile({super.key, required this.item, this.removeLabel = '', this.onRemove, this.lazy = false});

  final LibraryItem item;

  /// Load the poster only once it's on screen (see AuroraImage.lazy).
  final bool lazy;
  final String removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final rating = double.tryParse(item.tmdbRating ?? '');

    return Stack(
      children: [
        Pressable(
          onTap: () => closeModalsAnd(context, (context) => openLibraryItem(context, item)),
          pressedScale: 0.96,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.fg(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AuroraImage(url: tmdbImage(item.posterImgURL, TmdbSize.w500), lazy: lazy),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xF2000000), Color(0x0D000000), Colors.transparent],
                      ),
                    ),
                  ),
                  if (rating != null && rating > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '★ ',
                                style: TextStyle(color: ratingColor(rating)),
                              ),
                              TextSpan(text: rating.toStringAsFixed(1)),
                            ],
                          ),
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Icon(item.isSeries ? LucideIcons.tv : LucideIcons.film, size: 10, color: Colors.white.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 6,
            left: 6,
            child: Pressable(
              onTap: onRemove,
              semanticLabel: removeLabel,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.6)),
                child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

/// Dashed "Add titles" button that unfolds a movie/series search; each
/// result has a + (or ✓ once it's in the playlist).
class _AddItemsPanel extends ConsumerStatefulWidget {
  const _AddItemsPanel({required this.playlistId, required this.existingIds, required this.open, required this.onToggle, required this.onAdded});

  final String playlistId;
  final Set<String> existingIds;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<LibraryItem> onAdded;

  @override
  ConsumerState<_AddItemsPanel> createState() => _AddItemsPanelState();
}

class _AddItemsPanelState extends ConsumerState<_AddItemsPanel> {
  final _query = TextEditingController();
  RecordType _type = RecordType.movie;
  List<CinemaRecord> _results = const [];
  bool _searching = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _addingId;
  bool _limitReached = false;
  Timer? _debounce;
  Timer? _limitTimer;
  int _requestId = 0;

  @override
  void dispose() {
    _query.dispose();
    _debounce?.cancel();
    _limitTimer?.cancel();
    super.dispose();
  }

  void _search() {
    _debounce?.cancel();
    final query = _query.text.trim();
    if (query.isEmpty) {
      _requestId++;
      setState(() {
        _results = const [];
        _hasMore = false;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final id = ++_requestId;
      final found = await ref.read(catalogApiProvider).searchSuggestions(_type, query, limit: _searchPageSize);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = found;
        _hasMore = found.length == _searchPageSize;
        _searching = false;
      });
    });
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final more = await ref.read(catalogApiProvider).searchSuggestions(_type, _query.text.trim(), limit: _searchPageSize, offset: _results.length);
    if (!mounted) return;
    setState(() {
      _results = [..._results, ...more];
      _hasMore = more.length == _searchPageSize;
      _loadingMore = false;
    });
  }

  Future<void> _add(CinemaRecord record) async {
    final item = LibraryItem.fromRecord(record);
    setState(() => _addingId = item.id);
    final result = await ref.read(playlistsApiProvider).addItem(widget.playlistId, item);
    if (!mounted) return;
    setState(() => _addingId = null);
    if (result == AddToPlaylistResult.ok) widget.onAdded(item);
    if (result == AddToPlaylistResult.limit) {
      setState(() => _limitReached = true);
      _limitTimer?.cancel();
      _limitTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _limitReached = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          onTap: widget.onToggle,
          pressedScale: 0.98,
          child: CustomPaint(
            painter: _DashedBorderPainter(color: widget.open ? Colors.white.withValues(alpha: 0.3) : AppColors.fg(0.15)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: widget.open ? AppColors.fg(0.05) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.open ? LucideIcons.x : LucideIcons.plus, size: 15, color: widget.open ? AppColors.foreground : AppColors.fg(0.6)),
                  const SizedBox(width: 8),
                  Text(
                    t('playlists.addTitles'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.open ? AppColors.foreground : AppColors.fg(0.6)),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_limitReached)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              t('playlists.itemLimitReached'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.fg(0.6)),
            ),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: auroraEase,
          alignment: Alignment.topCenter,
          child: !widget.open
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.fg(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.fg(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.fg(0.05),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.fg(0.1)),
                        ),
                        child: Row(
                          children: [
                            for (final type in RecordType.values)
                              Expanded(
                                child: Pressable(
                                  pressedScale: 1,
                                  onTap: () {
                                    setState(() {
                                      _type = type;
                                      _results = const [];
                                      _hasMore = false;
                                    });
                                    _search();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _type == type ? Colors.white : Colors.white.withValues(alpha: 0),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      type == RecordType.movie ? t('search.movies') : t('search.series'),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _type == type ? AppColors.onWhite : AppColors.fg(0.6)),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      PillTextField(
                        controller: _query,
                        hint: _type == RecordType.movie ? t('search.placeholderMovies') : t('search.placeholderSeries'),
                        autofocus: true,
                        prefixIcon: LucideIcons.search,
                        onChanged: (_) => _search(),
                        suffix: _searching ? const Padding(padding: EdgeInsets.all(14), child: Spinner(size: 13)) : null,
                      ),
                      if (_results.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 256),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(top: 8),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final record = _results[index];
                              final key = recordKey(record);
                              final alreadyIn = widget.existingIds.contains(key);
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Row(
                                  children: [
                                    if (record.posterImgURL != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(width: 42, height: 60, child: AuroraImage(url: tmdbImage(record.posterImgURL, TmdbSize.w342))),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        record.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 14, color: AppColors.fg(0.85)),
                                      ),
                                    ),
                                    if (alreadyIn)
                                      SizedBox(width: 32, height: 32, child: Icon(LucideIcons.check, size: 15, color: AppColors.fg(0.4)))
                                    else
                                      Pressable(
                                        onTap: _addingId == key ? null : () => _add(record),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                          child: _addingId == key
                                              ? const Center(child: Spinner(size: 13, color: AppColors.onWhite))
                                              : const Icon(LucideIcons.plus, size: 15, color: AppColors.onWhite),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      if (_hasMore)
                        Pressable(
                          onTap: _loadingMore ? null : _loadMore,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: _loadingMore
                                  ? const Spinner(size: 13)
                                  : Text(
                                      t('playlists.loadMore'),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.fg(0.6)),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)));
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 9) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
