import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/friends/friends_api.dart';
import '../../core/friends/friends_store.dart';
import '../../core/i18n/locale.dart';
import '../../core/theme.dart';
import 'friend_widgets.dart';
import 'user_profile_modal.dart';

/// Unseen notifications for the bell's "+N" — every 25s and on every live
/// friend event (website: NotificationsBell's poll).
class NotificationCountController extends Notifier<int> {
  @override
  int build() {
    final signedInAs = ref.watch(authProvider.select((auth) => auth.user?.id));
    if (signedInAs == null) return 0;

    final timer = Timer.periodic(const Duration(seconds: 25), (_) => refresh());
    final events = ref.read(friendsEventsProvider).friendEvents.listen((_) => refresh());
    ref.onDispose(() {
      timer.cancel();
      events.cancel();
    });
    Future.microtask(refresh);
    return 0;
  }

  Future<void> refresh() async {
    final count = await ref.read(friendsApiProvider).notificationCount();
    if (ref.read(authProvider).isSignedIn) state = count;
  }

  void clear() => state = 0;
}

final notificationCountProvider = NotifierProvider<NotificationCountController, int>(NotificationCountController.new);

/// The bell's dropdown: who sent / accepted / declined a request — opening
/// it marks them all as seen. Tapping one opens that person's profile.
class NotificationsPanel extends ConsumerStatefulWidget {
  const NotificationsPanel({super.key, required this.open});

  final bool open;

  @override
  ConsumerState<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends ConsumerState<NotificationsPanel> {
  List<FriendNotification>? _items;

  @override
  void initState() {
    super.initState();
    if (widget.open) _consume();
  }

  @override
  void didUpdateWidget(NotificationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) _consume();
    if (!widget.open && oldWidget.open) _items = null;
  }

  Future<void> _consume() async {
    List<FriendNotification> items;
    try {
      items = await ref.read(friendsApiProvider).consumeNotifications();
    } catch (_) {
      items = const [];
    }
    if (!mounted) return;
    ref.read(notificationCountProvider.notifier).clear();
    if (widget.open) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final items = _items;

    Widget message(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: AppColors.fg(0.5)),
      ),
    );

    if (items == null) return message(t('friends.notificationsLoading'));
    if (items.isEmpty) return message(t('friends.notificationsEmpty'));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: SingleChildScrollView(
        child: Column(
          spacing: 4,
          children: [
            for (final notification in items)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showUserProfileModal(context, notification.actor),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      FriendAvatar(person: notification.actor, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: notification.actor.displayName?.isNotEmpty == true ? notification.actor.displayName! : '?',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(
                                text:
                                    ' ${switch (notification.type) {
                                      NotificationType.request => t('friends.notifSentRequest'),
                                      NotificationType.accepted => t('friends.notifAcceptedRequest'),
                                      NotificationType.declined => t('friends.notifDeclinedRequest'),
                                    }}',
                              ),
                            ],
                          ),
                          style: TextStyle(fontSize: 14, color: AppColors.fg(0.85)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
