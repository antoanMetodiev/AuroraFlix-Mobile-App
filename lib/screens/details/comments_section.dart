import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/comments_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/dates.dart';
import '../../core/i18n/locale.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/fade_in_image.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_heading.dart';
import '../auth/clerk_auth_modal.dart';

/// "Comments" (website: CommentsSection): write one when signed in, read
/// them 10 at a time, edit / delete your own, like / dislike anyone's and
/// see who reacted.
class CommentsSection extends ConsumerStatefulWidget {
  const CommentsSection({super.key, required this.recordId, required this.type});

  final String recordId;
  final RecordType type;

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection> {
  final _draft = TextEditingController();
  final _editDraft = TextEditingController();

  List<Comment> _comments = const [];
  Map<String, CommentReactions> _reactions = const {};
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _posting = false;
  bool _postError = false;
  String? _editingId;
  bool _savingEdit = false;
  String? _deletingId;

  CommentsApi get _api => ref.read(commentsApiProvider);

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _draft.dispose();
    _editDraft.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    final comments = await _api.page(widget.type, widget.recordId, 1);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _hasMore = comments.length == CommentsApi.pageSize;
      _page = 1;
      _loading = false;
    });
    final reactions = await _api.reactions(widget.type, comments.map((comment) => comment.id).toList());
    if (mounted) setState(() => _reactions = reactions);
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final comments = await _api.page(widget.type, widget.recordId, _page + 1);
    if (!mounted) return;
    setState(() {
      _comments = [..._comments, ...comments];
      _hasMore = comments.length == CommentsApi.pageSize;
      _page++;
      _loadingMore = false;
    });
    final reactions = await _api.reactions(widget.type, comments.map((comment) => comment.id).toList());
    if (mounted) setState(() => _reactions = {..._reactions, ...reactions});
  }

  Future<void> _submit() async {
    final text = _draft.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() {
      _posting = true;
      _postError = false;
    });
    final ok = await _api.post(widget.type, widget.recordId, text);
    if (!mounted) return;
    if (ok) {
      _draft.clear();
      await _loadFirstPage();
    }
    if (mounted) {
      setState(() {
        _posting = false;
        _postError = !ok;
      });
    }
  }

  Future<void> _saveEdit(String commentId) async {
    final text = _editDraft.text.trim();
    if (text.isEmpty || _savingEdit) return;
    setState(() => _savingEdit = true);
    final ok = await _api.update(widget.type, widget.recordId, commentId, text);
    if (!mounted) return;
    setState(() {
      _savingEdit = false;
      if (ok) {
        _comments = [for (final comment in _comments) comment.id == commentId ? comment.copyWith(text: text) : comment];
        _editingId = null;
      }
    });
  }

  Future<void> _delete(String commentId) async {
    if (_deletingId != null) return;
    setState(() => _deletingId = commentId);
    final ok = await _api.delete(widget.type, widget.recordId, commentId);
    if (!mounted) return;
    setState(() {
      _deletingId = null;
      if (ok) {
        _comments = _comments.where((comment) => comment.id != commentId).toList();
        _reactions = {..._reactions}..remove(commentId);
      }
    });
  }

  /// Optimistic, like the website: the thumbs flip at once and roll back if
  /// the request fails. Reacting the same way twice takes it back.
  Future<void> _react(String commentId, ReactionType reaction) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final me = Reactor(userId: user.id, fullName: user.fullName, imgURL: user.imageUrl, createdAt: DateTime.now().toIso8601String());
    final previous = _reactions[commentId] ?? const CommentReactions();
    final alreadyLiked = previous.likes.any((reactor) => reactor.userId == me.userId);
    final alreadyDisliked = previous.dislikes.any((reactor) => reactor.userId == me.userId);
    final likes = previous.likes.where((reactor) => reactor.userId != me.userId).toList();
    final dislikes = previous.dislikes.where((reactor) => reactor.userId != me.userId).toList();
    final togglingOff = (reaction == ReactionType.like && alreadyLiked) || (reaction == ReactionType.dislike && alreadyDisliked);
    if (!togglingOff) (reaction == ReactionType.like ? likes : dislikes).add(me);

    setState(() => _reactions = {..._reactions, commentId: CommentReactions(likes: likes, dislikes: dislikes)});
    final ok = await _api.react(widget.type, commentId, reaction);
    if (!ok && mounted) setState(() => _reactions = {..._reactions, commentId: previous});
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final locale = ref.watch(localeProvider);
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(t('comments.title'), icon: LucideIcons.messageCircle),
          if (auth.isSignedIn && user != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      TextField(
                        controller: _draft,
                        enabled: !_posting,
                        minLines: 3,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        cursorColor: Colors.white,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: t('comments.placeholder'),
                          hintStyle: TextStyle(color: AppColors.fg(0.35)),
                          filled: true,
                          fillColor: AppColors.fg(0.06),
                          contentPadding: const EdgeInsets.fromLTRB(16, 16, 56, 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppColors.fg(0.15)),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppColors.fg(0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Pressable(
                          onTap: _posting || _draft.text.trim().isEmpty ? null : _submit,
                          child: Opacity(
                            opacity: _posting || _draft.text.trim().isEmpty ? 0.4 : 1,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              child: _posting
                                  ? const Center(child: Spinner(size: 16, color: AppColors.onWhite))
                                  : const Icon(LucideIcons.send, size: 16, color: AppColors.onWhite),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_postError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(t('comments.postError'), style: const TextStyle(fontSize: 12, color: Color(0xFFF87171))),
                    ),
                ],
              ),
            )
          else if (auth.isLoaded)
            Container(
              margin: const EdgeInsets.only(bottom: 32),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.fg(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.fg(0.1)),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => showClerkAuthModal(context, ClerkAuthMode.signIn),
                    child: Text(
                      t('comments.signInCta'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),
                  Text(' ${t('comments.signInToComment')}', style: TextStyle(fontSize: 14, color: AppColors.fg(0.6))),
                ],
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Spinner(size: 28)),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                t('comments.empty'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.fg(0.4)),
              ),
            )
          else
            for (final comment in _comments)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _CommentTile(
                  comment: comment,
                  dateLabel: formatDateTime(comment.createdAt, locale.name),
                  isOwn: user != null && user.id == comment.authorId,
                  editing: _editingId == comment.id,
                  editController: _editDraft,
                  savingEdit: _savingEdit,
                  deleting: _deletingId == comment.id,
                  reactions: _reactions[comment.id],
                  currentUserId: user?.id,
                  onEdit: () => setState(() {
                    _editingId = comment.id;
                    _editDraft.text = comment.text;
                  }),
                  onCancelEdit: () => setState(() => _editingId = null),
                  onSaveEdit: () => _saveEdit(comment.id),
                  onDelete: () => _delete(comment.id),
                  onReact: (reaction) => _react(comment.id, reaction),
                ),
              ),
          if (_hasMore && !_loading)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Pressable(
                  onTap: _loadingMore ? null : _loadMore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.fg(0.04),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.fg(0.15)),
                    ),
                    child: _loadingMore
                        ? const Spinner(size: 16)
                        : Text(
                            t('sections.loadMore'),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.fg(0.8)),
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

class _CommentTile extends ConsumerWidget {
  const _CommentTile({
    required this.comment,
    required this.dateLabel,
    required this.isOwn,
    required this.editing,
    required this.editController,
    required this.savingEdit,
    required this.deleting,
    required this.reactions,
    required this.currentUserId,
    required this.onEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onDelete,
    required this.onReact,
  });

  final Comment comment;
  final String dateLabel;
  final bool isOwn;
  final bool editing;
  final TextEditingController editController;
  final bool savingEdit;
  final bool deleting;
  final CommentReactions? reactions;
  final String? currentUserId;
  final VoidCallback onEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback onDelete;
  final ValueChanged<ReactionType> onReact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InitialAvatar(name: comment.authorName, imageUrl: comment.authorImgURL, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.fg(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.fg(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          Text(comment.authorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(dateLabel, style: TextStyle(fontSize: 12, color: AppColors.fg(0.4))),
                        ],
                      ),
                    ),
                    if (isOwn && !editing) ...[
                      _IconAction(icon: LucideIcons.pencil, onTap: onEdit),
                      deleting
                          ? const Padding(padding: EdgeInsets.all(7), child: Spinner(size: 14))
                          : _IconAction(icon: LucideIcons.trash2, onTap: onDelete),
                    ],
                  ],
                ),
                if (editing) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: editController,
                    enabled: !savingEdit,
                    minLines: 2,
                    maxLines: 2,
                    cursorColor: Colors.white,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.fg(0.06),
                      contentPadding: const EdgeInsets.all(12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.fg(0.15)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Pressable(
                        onTap: savingEdit ? null : onSaveEdit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                          child: savingEdit
                              ? const Spinner(size: 12, color: AppColors.onWhite)
                              : Text(
                                  t('comments.save'),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onWhite),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: savingEdit ? null : onCancelEdit,
                        child: Row(
                          children: [
                            Icon(LucideIcons.x, size: 13, color: AppColors.fg(0.6)),
                            const SizedBox(width: 4),
                            Text(
                              t('comments.cancel'),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.fg(0.6)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(comment.text, style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.fg(0.75))),
                  _ReactionsBar(reactions: reactions, currentUserId: currentUserId, onReact: onReact),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(width: 28, height: 28, child: Icon(icon, size: 14, color: AppColors.fg(0.4))),
    );
  }
}

/// Avatar from a URL, or the first letter of the name on a soft circle.
class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name, required this.imageUrl, required this.size});

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.fg(0.1)),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null
          ? AuroraImage(url: imageUrl)
          : Center(
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w600, color: AppColors.fg(0.7)),
              ),
            ),
    );
  }
}

/// 👍 n / 👎 n toggles, plus a "who reacted" button per side that unfolds the
/// list of people (website: CommentReactionsBar).
class _ReactionsBar extends ConsumerStatefulWidget {
  const _ReactionsBar({required this.reactions, required this.currentUserId, required this.onReact});

  final CommentReactions? reactions;
  final String? currentUserId;
  final ValueChanged<ReactionType> onReact;

  @override
  ConsumerState<_ReactionsBar> createState() => _ReactionsBarState();
}

class _ReactionsBarState extends ConsumerState<_ReactionsBar> {
  ReactionType? _panel;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final locale = ref.watch(localeProvider);
    final signedIn = widget.currentUserId != null;
    final likes = widget.reactions?.likes ?? const <Reactor>[];
    final dislikes = widget.reactions?.dislikes ?? const <Reactor>[];
    final iLiked = signedIn && likes.any((reactor) => reactor.userId == widget.currentUserId);
    final iDisliked = signedIn && dislikes.any((reactor) => reactor.userId == widget.currentUserId);
    final activeList = _panel == ReactionType.like ? likes : dislikes;

    Widget thumb(IconData icon, int count, bool mine, Color activeColor, Color activeText, ReactionType type) => Opacity(
      opacity: signedIn ? 1 : 0.4,
      child: Pressable(
        onTap: signedIn ? () => widget.onReact(type) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: mine ? activeColor : AppColors.fg(0.03),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: mine ? Colors.transparent : AppColors.fg(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: mine ? activeText : AppColors.fg(0.6)),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mine ? activeText : AppColors.fg(0.6)),
              ),
            ],
          ),
        ),
      ),
    );

    Widget who(List<Reactor> reactors, ReactionType type) => Pressable(
      onTap: () => setState(() => _panel = _panel == type ? null : type),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        decoration: BoxDecoration(
          color: AppColors.fg(0.03),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.fg(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InitialAvatar(name: reactors.first.displayName, imageUrl: reactors.first.imgURL, size: 20),
            const SizedBox(width: 4),
            Icon(LucideIcons.ellipsis, size: 14, color: AppColors.fg(0.5)),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                thumb(LucideIcons.thumbsUp, likes.length, iLiked, Colors.white, AppColors.onWhite, ReactionType.like),
                if (likes.isNotEmpty) ...[const SizedBox(width: 6), who(likes, ReactionType.like)],
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                thumb(LucideIcons.thumbsDown, dislikes.length, iDisliked, const Color(0xE6F43F5E), Colors.white, ReactionType.dislike),
                if (dislikes.isNotEmpty) ...[const SizedBox(width: 6), who(dislikes, ReactionType.dislike)],
              ],
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topLeft,
          child: _panel == null
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: 256,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.fg(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.fg(0.1))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                (_panel == ReactionType.dislike ? t('comments.dislikedBy') : t('comments.likedBy')).toUpperCase(),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: AppColors.fg(0.7)),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _panel = null),
                              child: Icon(LucideIcons.x, size: 13, color: AppColors.fg(0.4)),
                            ),
                          ],
                        ),
                      ),
                      if (activeList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            t('comments.noReactionsYet'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.fg(0.4)),
                          ),
                        )
                      else
                        for (final reactor in activeList)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                _InitialAvatar(name: reactor.displayName, imageUrl: reactor.imgURL, size: 28),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reactor.displayName,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 14, color: AppColors.fg(0.85)),
                                      ),
                                      Text(
                                        formatDateTime(reactor.createdAt ?? '', locale.name),
                                        style: TextStyle(fontSize: 11, color: AppColors.fg(0.4)),
                                      ),
                                    ],
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
    );
  }
}
