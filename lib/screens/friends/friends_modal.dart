import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/friends/friends_api.dart';
import '../../core/friends/friends_store.dart';
import '../../core/i18n/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../widgets/empty_art.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';
import 'friend_widgets.dart';
import 'user_profile_modal.dart';

/// "Friends" (website: FriendsModal + FriendsPanel): Search / Requests /
/// Friends tabs in the big centered card.
Future<void> showFriendsModal(BuildContext context) async {
  // The heading follows the open tab (Search / Requests / Friends), as on the website.
  final tab = ValueNotifier(FriendsTab.search);
  await showAuroraModal(
    context,
    builder: (context) => Consumer(
      builder: (context, ref, _) => AuroraModalCard(
        header: ValueListenableBuilder(
          valueListenable: tab,
          builder: (context, open, _) => Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: Icon(open.icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  ref.watch(translatorProvider)(open.labelKey),
                  overflow: TextOverflow.ellipsis,
                  style: display(const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
                ),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: FriendsPanel(tab: tab)),
      ),
    ),
  );
}

enum FriendsTab {
  search('friends.tabSearch', LucideIcons.search),
  requests('friends.tabRequests', LucideIcons.inbox),
  friends('friends.tabFriends', LucideIcons.users);

  const FriendsTab(this.labelKey, this.icon);

  final String labelKey;
  final IconData icon;
}

class FriendsPanel extends ConsumerStatefulWidget {
  const FriendsPanel({super.key, required this.tab});

  /// The open tab — owned by showFriendsModal, whose heading follows it.
  final ValueNotifier<FriendsTab> tab;

  @override
  ConsumerState<FriendsPanel> createState() => _FriendsPanelState();
}

class _FriendsPanelState extends ConsumerState<FriendsPanel> {
  FriendsTab get _tab => widget.tab.value;
  final _query = TextEditingController();
  final _focus = FocusNode();
  List<FriendSearchResult> _results = const [];
  bool _searching = false;
  String? _busyId;
  Timer? _debounce;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// A blank query lists recently joined people right away; typing waits
  /// 250ms for a pause.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() => _searching = true);
    if (value.isEmpty) {
      _search();
    } else {
      _debounce = Timer(const Duration(milliseconds: 250), _search);
    }
  }

  Future<void> _search() async {
    final generation = ++_searchGeneration;
    setState(() => _searching = true);
    final found = await ref.read(friendsApiProvider).search(_query.text);
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _results = found;
      _searching = false;
    });
  }

  Future<void> _run(String clerkId, Future<void> Function() action) async {
    setState(() => _busyId = clerkId);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// A result's relationship comes from the live lists, not the search
  /// snapshot — and that gives pending rows a request id to act on.
  (Relationship, String?) _relationship(FriendsState friends, FriendSearchResult result) {
    if (friends.isLoading) return (result.relationship, null);
    final id = result.person.clerkId;
    if (friends.friends.any((friend) => friend.clerkId == id)) return (Relationship.friends, null);
    for (final request in friends.outgoing) {
      if (request.person.clerkId == id) return (Relationship.pendingSent, request.id);
    }
    for (final request in friends.incoming) {
      if (request.person.clerkId == id) return (Relationship.pendingReceived, request.id);
    }
    return (Relationship.none, null);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final friends = ref.watch(friendsProvider);
    final store = ref.read(friendsProvider.notifier);

    void openProfile(Friend person) => showUserProfileModal(context, person);

    Widget tabButton(FriendsTab tab, IconData icon, int badge) {
      final active = _tab == tab;
      return Expanded(
        child: Pressable(
          onTap: () => setState(() => widget.tab.value = tab),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: active
                  ? [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: active ? AppColors.onWhite : AppColors.fg(0.55)),
                if (badge > 0) ...[const SizedBox(width: 6), _CountBadge(count: '$badge', inverted: active)],
              ],
            ),
          ),
        ),
      );
    }

    Widget body;
    switch (_tab) {
      case FriendsTab.search:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListenableBuilder(
              listenable: _focus,
              builder: (context, _) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: AppColors.fg(_focus.hasFocus ? 0.1 : 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _focus.hasFocus ? Colors.white : AppColors.fg(0.15), width: _focus.hasFocus ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Icon(LucideIcons.search, size: 15, color: AppColors.fg(0.4)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _query,
                        focusNode: _focus,
                        onChanged: _onQueryChanged,
                        autocorrect: false,
                        cursorColor: Colors.white,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: t('friends.searchPlaceholder'),
                          hintStyle: TextStyle(color: AppColors.fg(0.35)),
                          contentPadding: const EdgeInsets.fromLTRB(12, 13, 8, 13),
                        ),
                      ),
                    ),
                    if (_searching) const Padding(padding: EdgeInsets.only(right: 14), child: Spinner(size: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_query.text.trim().isNotEmpty && _results.isEmpty && !_searching)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  t('friends.searchEmpty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.fg(0.5)),
                ),
              ),
            _ScrollingList(
              maxHeight: 320,
              children: [
                for (final result in _results)
                  () {
                    final (relationship, requestId) = _relationship(friends, result);
                    final id = result.person.clerkId;
                    final busy = _busyId == id;
                    return _PersonRow(
                      person: result.person,
                      onOpenProfile: openProfile,
                      actions: switch (relationship) {
                        Relationship.none => [
                          _ActionIcon(
                            icon: LucideIcons.userPlus,
                            label: t('friends.addFriend'),
                            primary: true,
                            busy: busy,
                            onTap: () => _run(id, () => store.send(id)),
                          ),
                        ],
                        Relationship.pendingSent => [
                          if (requestId != null)
                            _ActionIcon(
                              icon: LucideIcons.clock,
                              label: t('friends.cancel'),
                              busy: busy,
                              onTap: () => _run(id, () => store.cancelOrDecline(requestId)),
                            )
                          else
                            const _StatusPill(icon: LucideIcons.clock),
                        ],
                        Relationship.pendingReceived => [
                          if (requestId != null) ...[
                            _ActionIcon(
                              icon: LucideIcons.check,
                              label: t('friends.accept'),
                              primary: true,
                              busy: busy,
                              onTap: () => _run(id, () => store.accept(requestId)),
                            ),
                            _ActionIcon(
                              icon: LucideIcons.x,
                              label: t('friends.decline'),
                              busy: busy,
                              onTap: () => _run(id, () => store.cancelOrDecline(requestId)),
                            ),
                          ] else
                            const _StatusPill(icon: LucideIcons.inbox),
                        ],
                        Relationship.friends => [
                          _ActionIcon(
                            icon: LucideIcons.userMinus,
                            label: t('friends.remove'),
                            busy: busy,
                            onTap: () => _run(id, () => store.remove(id)),
                          ),
                        ],
                      },
                    );
                  }(),
              ],
            ),
          ],
        );
      case FriendsTab.requests:
        body = friends.isLoading
            ? const Loader(minHeight: 160)
            : _ScrollingList(
                maxHeight: 384,
                children: [
                  _RequestsList(
                    title: t('friends.incomingTitle'),
                    items: friends.incoming,
                    emptyLabel: t('friends.noPending'),
                    onOpenProfile: openProfile,
                    actions: (request) => [
                      _ActionIcon(icon: LucideIcons.check, label: t('friends.accept'), primary: true, onTap: () => store.accept(request.id)),
                      _ActionIcon(icon: LucideIcons.x, label: t('friends.decline'), onTap: () => store.cancelOrDecline(request.id)),
                    ],
                  ),
                  if (friends.outgoing.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _RequestsList(
                      title: t('friends.outgoingTitle'),
                      items: friends.outgoing,
                      onOpenProfile: openProfile,
                      actions: (request) => [
                        _ActionIcon(icon: LucideIcons.x, label: t('friends.cancel'), onTap: () => store.cancelOrDecline(request.id)),
                      ],
                    ),
                  ],
                ],
              );
      case FriendsTab.friends:
        body = friends.isLoading
            ? const Loader(minHeight: 160)
            : friends.friends.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const EmptyIllustration(art: EmptyArt.friends, width: 128, height: 96),
                    const SizedBox(height: 12),
                    Text(
                      t('friends.friendsEmpty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.fg(0.5)),
                    ),
                  ],
                ),
              )
            : _ScrollingList(
                maxHeight: 384,
                children: [
                  for (final friend in friends.friends)
                    _PersonRow(
                      person: friend,
                      onOpenProfile: openProfile,
                      actions: [_ActionIcon(icon: LucideIcons.userMinus, label: t('friends.remove'), onTap: () => store.remove(friend.clerkId))],
                      below: friends.watching[friend.clerkId] == null ? null : _FriendWatchingCard(watching: friends.watching[friend.clerkId]!),
                    ),
                ],
              );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.fg(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.fg(0.1)),
          ),
          child: Row(
            spacing: 4,
            children: [
              tabButton(FriendsTab.search, LucideIcons.search, 0),
              tabButton(FriendsTab.requests, LucideIcons.inbox, friends.incoming.length),
              tabButton(FriendsTab.friends, LucideIcons.users, 0),
            ],
          ),
        ),
        const SizedBox(height: 20),
        body,
      ],
    );
  }
}

/// White count bubble (black on the active tab).
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, this.inverted = false});

  final String count;
  final bool inverted;

  @override
  Widget build(BuildContext context) => Container(
    height: 16,
    constraints: const BoxConstraints(minWidth: 16),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: inverted ? AppColors.onWhite : Colors.white, borderRadius: BorderRadius.circular(999)),
    child: Text(
      count,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, height: 1, color: inverted ? Colors.white : AppColors.onWhite),
    ),
  );
}

/// A list that scrolls on its own past [maxHeight] (the site's max-h-80 /
/// max-h-96 lists).
class _ScrollingList extends StatelessWidget {
  const _ScrollingList({required this.maxHeight, required this.children});

  final double maxHeight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: children),
    ),
  );
}

/// Avatar + name (opens their profile), then the row's action buttons.
class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onOpenProfile, required this.actions, this.below});

  final Friend person;
  final ValueChanged<Friend> onOpenProfile;
  final List<Widget> actions;
  final Widget? below;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: Pressable(
                pressedScale: 1,
                onTap: () => onOpenProfile(person),
                child: Row(
                  children: [
                    FriendAvatar(person: person, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        person.displayName?.isNotEmpty == true ? person.displayName! : '?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: AppColors.fg(0.85)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...actions,
          ],
        ),
        ?below,
      ],
    ),
  );
}

class _RequestsList extends StatelessWidget {
  const _RequestsList({required this.title, required this.items, required this.onOpenProfile, required this.actions, this.emptyLabel});

  final String title;
  final List<FriendRequestItem> items;
  final String? emptyLabel;
  final ValueChanged<Friend> onOpenProfile;
  final List<Widget> Function(FriendRequestItem request) actions;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: AppColors.fg(0.5)),
        ),
      ),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(emptyLabel ?? '', style: TextStyle(fontSize: 14, color: AppColors.fg(0.5))),
        )
      else
        for (final request in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _PersonRow(person: request.person, onOpenProfile: onOpenProfile, actions: actions(request)),
          ),
    ],
  );
}

/// 36px round action: white for the main one, outlined otherwise.
class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.label, required this.onTap, this.primary = false, this.busy = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: busy ? null : onTap,
    semanticLabel: label,
    child: Opacity(
      opacity: busy ? 0.4 : 1,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary ? Colors.white : null,
          border: primary ? null : Border.all(color: AppColors.fg(0.15)),
        ),
        child: busy
            ? Center(child: Spinner(size: 13, color: primary ? AppColors.onWhite : null))
            : Icon(icon, size: 15, color: primary ? AppColors.onWhite : AppColors.fg(0.6)),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.fg(0.1)),
    ),
    child: Icon(icon, size: 13, color: AppColors.fg(0.45)),
  );
}

/// Green "Watching" card under a friend who's playing something.
class _FriendWatchingCard extends ConsumerWidget {
  const _FriendWatchingCard({required this.watching});

  final WatchingTarget watching;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(titlePreviewProvider((watching.type, watching.tmdbId)));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Pressable(
        onTap: () => closeModalsAnd(context, (context) => openWatching(context, watching)),
        pressedScale: 0.98,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.emerald.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.emerald.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              WatchingPoster(watching: watching, posterPath: preview.value?.posterImgURL, width: 40, height: 56, radius: 6),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WatchingLabel(),
                    Text(
                      watching.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.fg(0.9)),
                    ),
                    WatchingPlayback(watching: watching),
                    const SizedBox(height: 4),
                    PreviewGenres(loaded: preview.hasValue || preview.hasError, genres: previewGenres(preview.value, 2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
