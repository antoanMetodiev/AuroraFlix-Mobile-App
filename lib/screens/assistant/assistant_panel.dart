import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/assistant/assistant_api.dart';
import '../../core/i18n/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/tmdb.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';
import '../friends/friend_widgets.dart';

const _suggestionKeys = ['assistant.suggestion1', 'assistant.suggestion2', 'assistant.suggestion3'];

/// "AuroraFlix Assistant" (website: AssistantPanel): a chat about movies and
/// series — the greeting with three suggestions, bubbles, and a card for
/// every title it names that's in our catalog.
Future<void> showAssistantPanel(BuildContext context) => showAuroraModal(context, builder: (context) => const _AssistantPanel());

class _AssistantPanel extends ConsumerStatefulWidget {
  const _AssistantPanel();

  @override
  ConsumerState<_AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends ConsumerState<_AssistantPanel> {
  final _messages = <AssistantMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  });

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;
    final t = ref.read(translatorProvider);
    final history = [..._messages, AssistantMessage(fromUser: true, content: trimmed)];
    setState(() {
      _messages.add(history.last);
      _input.clear();
      _loading = true;
    });
    _scrollToEnd();

    AssistantMessage reply;
    try {
      reply = await ref.read(assistantApiProvider).send(trimmed, ref.read(localeProvider).name, history);
    } on AssistantException catch (error) {
      reply = AssistantMessage(
        fromUser: false,
        isError: true,
        content: error.failure == AssistantFailure.rateLimited ? t('assistant.rateLimited') : t('assistant.errorGeneric'),
      );
    }
    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _loading = false;
    });
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    Widget roundButton(IconData icon, double iconSize, String label, VoidCallback onTap) => Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.fg(0.05)),
        child: Icon(icon, size: iconSize, color: AppColors.fg(0.6)),
      ),
    );

    final card = Container(
      height: (size.height * 0.82).clamp(0, 760).toDouble(),
      constraints: const BoxConstraints(maxWidth: 512),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 90, spreadRadius: -15, offset: const Offset(0, 30))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 224,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0.06), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(LucideIcons.sparkles, size: 19, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('assistant.title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                          ),
                          Text(t('assistant.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.fg(0.5))),
                        ],
                      ),
                    ),
                    if (_messages.isNotEmpty) ...[
                      roundButton(LucideIcons.rotateCcw, 16, t('assistant.newChat'), () => setState(_messages.clear)),
                      const SizedBox(width: 6),
                    ],
                    roundButton(LucideIcons.x, 19, t('assistant.closeAria'), () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_messages.isEmpty) ...[
                      _Bubble(message: AssistantMessage(fromUser: false, content: t('assistant.greeting'))),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 38),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final key in _suggestionKeys)
                              Pressable(
                                onTap: () => _send(t(key)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: Text(t(key), style: TextStyle(fontSize: 12, color: AppColors.fg(0.7))),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    for (final message in _messages) ...[
                      _Bubble(message: message),
                      for (final card in message.cards)
                        Padding(
                          padding: const EdgeInsets.only(left: 38, top: 12),
                          child: _SpotlightCard(card: card),
                        ),
                      const SizedBox(height: 16),
                    ],
                    if (_loading) _Bubble(message: AssistantMessage(fromUser: false, content: t('assistant.thinking')), thinking: true),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Opacity(
                        opacity: _loading ? 0.6 : 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.fg(0.05),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.fg(0.1)),
                          ),
                          child: TextField(
                            controller: _input,
                            enabled: !_loading,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: _send,
                            textInputAction: TextInputAction.send,
                            cursorColor: Colors.white,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: t('assistant.placeholder'),
                              hintStyle: TextStyle(color: AppColors.fg(0.4)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Pressable(
                      onTap: _loading || _input.text.trim().isEmpty ? null : () => _send(_input.text),
                      semanticLabel: t('assistant.send'),
                      child: Opacity(
                        opacity: _loading || _input.text.trim().isEmpty ? 0.4 : 1,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                          child: const Icon(LucideIcons.send, size: 16, color: AppColors.onWhite),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Padding(
        // Centered a little above the middle (pb-[6vh]); lifted by the keyboard.
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, keyboard > 0 ? keyboard + 8 : size.height * 0.06),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Material(type: MaterialType.transparency, child: card),
          ),
        ),
      ),
    );
  }
}

/// One chat bubble: white on the right for you, faint on the left with the
/// bot icon for the assistant, red for errors. `**bold**` is shown bold.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.thinking = false});

  final AssistantMessage message;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    final background = fromUser
        ? Colors.white
        : message.isError
        ? const Color(0xFFEF4444).withValues(alpha: 0.1)
        : AppColors.fg(0.06);
    final color = fromUser
        ? AppColors.onWhite
        : message.isError
        ? const Color(0xFFFCA5A5)
        : AppColors.fg(thinking ? 0.6 : 0.85);

    final lines = message.content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(fromUser ? 16 : 4),
          topRight: Radius.circular(fromUser ? 4 : 16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
        border: message.isError ? Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.2)) : null,
      ),
      child: thinking
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Spinner(size: 14, color: AppColors.fg(0.6)),
                const SizedBox(width: 8),
                Text(message.content, style: TextStyle(fontSize: 14, color: color)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                for (final line in lines)
                  Text.rich(
                    TextSpan(
                      children: [
                        for (final (index, chunk) in line.split('**').indexed)
                          TextSpan(
                            text: chunk,
                            style: index.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
                          ),
                      ],
                    ),
                    style: TextStyle(fontSize: 14, height: 1.6, color: color),
                  ),
              ],
            ),
    );

    // Bubbles take at most 85% of the width (max-w-[85%]).
    return LayoutBuilder(
      builder: (context, constraints) {
        final limited = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.85),
          child: bubble,
        );
        if (fromUser) return Align(alignment: Alignment.centerRight, child: limited);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2, right: 10),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
              child: const Icon(LucideIcons.bot, size: 14, color: Colors.white),
            ),
            Flexible(child: limited),
          ],
        );
      },
    );
  }
}

/// A title the assistant named: poster, rating / year / genres, the
/// description, a strip of stills and "View".
class _SpotlightCard extends ConsumerWidget {
  const _SpotlightCard({required this.card});

  final AssistantCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);
    final poster = tmdbImage(card.posterImgURL, TmdbSize.w500);
    final rating = double.tryParse(card.tmdbRating ?? '');
    final genres = (card.genres ?? '').split(',').map((genre) => genre.trim()).where((genre) => genre.isNotEmpty).take(3);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.fg(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 96,
                  height: 144,
                  decoration: BoxDecoration(color: AppColors.fg(0.1), borderRadius: BorderRadius.circular(8)),
                  clipBehavior: Clip.antiAlias,
                  child: poster != null
                      ? AuroraImage(url: poster)
                      : Icon(card.type.name == 'movie' ? LucideIcons.film : LucideIcons.tv, size: 24, color: AppColors.fg(0.3)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Text(
                        card.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (rating != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 12, color: AppColors.amber),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.amber),
                                ),
                              ],
                            ),
                          if (card.year != null)
                            Text(
                              card.year!,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.fg(0.55)),
                            ),
                          for (final genre in genres)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.fg(0.1), borderRadius: BorderRadius.circular(999)),
                              child: Text(
                                genre,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.fg(0.6)),
                              ),
                            ),
                        ],
                      ),
                      if (card.description != null && card.description!.isNotEmpty)
                        Text(
                          card.description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, height: 1.6, color: AppColors.fg(0.6)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (card.images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                spacing: 6,
                children: [
                  for (final image in card.images)
                    Expanded(
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: AppColors.fg(0.05)),
                        clipBehavior: Clip.antiAlias,
                        child: AuroraImage(url: tmdbImage(image, TmdbSize.w500)),
                      ),
                    ),
                ],
              ),
            ),
          Pressable(
            onTap: () => closeModalsAnd(context, (context) => openTitle(context, card.type, card.id)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t('assistant.viewTitle'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.arrowRight, size: 13, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
