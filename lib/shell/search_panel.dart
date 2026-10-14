import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api/catalog_api.dart';
import '../core/dates.dart';
import '../core/i18n/locale.dart';
import '../core/theme.dart';
import '../core/tmdb.dart';
import '../models/models.dart';
import '../widgets/fade_in_image.dart';
import '../widgets/pressable.dart';

/// The header's search dropdown (website: NavSearch + SearchBox): a
/// Movies/Series switch, a pill input, and live suggestions — poster, title
/// and release date — that appear as you type.
class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({super.key, required this.open, required this.initialType, required this.onSelect, required this.onSubmit});

  final bool open;
  final RecordType initialType;
  final ValueChanged<CinemaRecord> onSelect;
  final void Function(RecordType type, String query) onSubmit;

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late RecordType _type = widget.initialType;
  List<CinemaRecord> _suggestions = const [];
  bool _searching = false;
  Timer? _debounce;

  /// Bumped per request, so a slow older response never overwrites a newer one.
  int _requestId = 0;

  @override
  void didUpdateWidget(SearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      _type = widget.initialType;
      _focusNode.requestFocus();
      if (_controller.text.trim().isNotEmpty) _search();
    } else if (!widget.open && oldWidget.open) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _requestId++;
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), _search);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final id = ++_requestId;
    setState(() => _searching = true);
    final results = await ref.read(catalogApiProvider).searchSuggestions(_type, query);
    if (!mounted || id != _requestId) return;
    setState(() {
      _suggestions = results;
      _searching = false;
    });
  }

  void _setType(RecordType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _suggestions = const [];
    });
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TypeSwitch(
          value: _type,
          labels: {RecordType.movie: t('search.movies'), RecordType.series: t('search.series')},
          onChanged: _setType,
        ),
        const SizedBox(height: 10),
        _SearchField(
          controller: _controller,
          focusNode: _focusNode,
          searching: _searching,
          hint: _type == RecordType.movie ? t('search.placeholderMovies') : t('search.placeholderSeries'),
          onChanged: _onChanged,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) widget.onSubmit(_type, value.trim());
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: auroraEase,
          alignment: Alignment.topCenter,
          child: _suggestions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                  child: Text(
                    _controller.text.trim().isEmpty || _searching ? t('app.searchHint') : t('common.noResults'),
                    style: TextStyle(fontSize: 12, color: AppColors.fg(0.4)),
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(top: 8),
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.fg(0.05)),
                    itemBuilder: (context, index) =>
                        _SuggestionRow(record: _suggestions[index], onTap: () => widget.onSelect(_suggestions[index])),
                  ),
                ),
        ),
      ],
    );
  }
}

class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.value, required this.labels, required this.onChanged});

  final RecordType value;
  final Map<RecordType, String> labels;
  final ValueChanged<RecordType> onChanged;

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
        children: [
          for (final type in RecordType.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: type == value ? Colors.white : Colors.white.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    labels[type]!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: type == value ? AppColors.onWhite : AppColors.fg(0.6),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final pill = BorderRadius.circular(999);

    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: AppColors.fg(focused ? 0.1 : 0.06),
            borderRadius: pill,
            border: Border.all(color: focused ? Colors.white : AppColors.fg(0.15), width: focused ? 1.5 : 1),
            boxShadow: focused
                ? [BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 28, spreadRadius: -6, offset: const Offset(0, 8))]
                : null,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.search,
            cursorColor: Colors.white,
            style: const TextStyle(fontSize: 14, color: AppColors.foreground),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.fg(0.35)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixIcon: SizedBox(
                width: 44,
                child: Center(
                  child: searching
                      ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.fg(0.7)))
                      : Icon(LucideIcons.search, size: 17, color: focused ? AppColors.foreground : AppColors.fg(0.4)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionRow extends ConsumerWidget {
  const _SuggestionRow({required this.record, required this.onTap});

  final CinemaRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poster = tmdbImage(record.posterImgURL, TmdbSize.w342);

    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poster != null)
              Container(
                width: 52,
                height: 75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                clipBehavior: Clip.antiAlias,
                child: AuroraImage(url: poster),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.title, style: const TextStyle(fontSize: 14, color: AppColors.foreground)),
                  if (record.releaseDate != null)
                    Text(
                      formatReleaseDate(record.releaseDate, ref.watch(localeProvider).name),
                      style: TextStyle(fontSize: 12, color: AppColors.fg(0.65)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
