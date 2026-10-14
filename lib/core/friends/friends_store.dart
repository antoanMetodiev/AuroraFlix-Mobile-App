import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/auth_controller.dart';
import '../config.dart';
import 'friends_api.dart';

/// A friend started / switched / stopped watching something — pushed over
/// the socket with the friend's name and picture so a toast needs no lookup.
class WatchingPush {
  const WatchingPush({required this.actor, required this.watching});

  final Friend actor;
  final WatchingTarget? watching;
}

/// Live events from the gateway's WebSocket. Friend events (requests,
/// accepts, removals) refresh the lists and the bell; watching pushes patch
/// "who's watching" and pop the toast.
class FriendsEvents {
  final _friends = StreamController<String>.broadcast();
  final _watching = StreamController<WatchingPush>.broadcast();

  Stream<String> get friendEvents => _friends.stream;
  Stream<WatchingPush> get watchingPushes => _watching.stream;
}

final friendsEventsProvider = Provider<FriendsEvents>((ref) => FriendsEvents());

class FriendsState {
  const FriendsState({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.watching = const {},
    this.isLoading = false,
  });

  final List<Friend> friends;
  final List<FriendRequestItem> incoming;
  final List<FriendRequestItem> outgoing;

  /// clerkId → what that friend is playing right now.
  final Map<String, WatchingTarget> watching;
  final bool isLoading;

  List<Friend> get watchingFriends => friends.where((friend) => watching.containsKey(friend.clerkId)).toList();

  FriendsState copyWith({
    List<Friend>? friends,
    List<FriendRequestItem>? incoming,
    List<FriendRequestItem>? outgoing,
    Map<String, WatchingTarget>? watching,
    bool? isLoading,
  }) => FriendsState(
    friends: friends ?? this.friends,
    incoming: incoming ?? this.incoming,
    outgoing: outgoing ?? this.outgoing,
    watching: watching ?? this.watching,
    isLoading: isLoading ?? this.isLoading,
  );
}

const _watchingPollInterval = Duration(seconds: 5);
const _listsPollInterval = Duration(seconds: 30);
const _reconnectStart = Duration(milliseconds: 300);
const _reconnectMax = Duration(seconds: 8);

/// One shared friends store (website: useFriends + useFriendRequestSocket):
/// friends, incoming / outgoing requests and who's watching what. Refreshed
/// on sign-in, on every live event, after every action and every 30s;
/// "watching" every 5s on top of the live pushes.
class FriendsController extends Notifier<FriendsState> {
  Future<void>? _inFlight;

  @override
  FriendsState build() {
    final auth = ref.watch(authProvider.select((auth) => (auth.isLoaded, auth.user?.id)));
    if (!auth.$1) return const FriendsState(isLoading: true);
    if (auth.$2 == null) return const FriendsState();

    final timers = [Timer.periodic(_watchingPollInterval, (_) => _refreshWatching()), Timer.periodic(_listsPollInterval, (_) => refresh())];
    final socket = _FriendsSocket(getToken: () => ref.read(authProvider.notifier).getToken(), onMessage: _onMessage)..connect();
    ref.onDispose(() {
      for (final timer in timers) {
        timer.cancel();
      }
      socket.close();
    });

    Future.microtask(refresh);
    return const FriendsState(isLoading: true);
  }

  FriendsApi get _api => ref.read(friendsApiProvider);

  bool get _signedIn => ref.read(authProvider).isSignedIn;

  Future<void> refresh() {
    if (!_signedIn) return Future.value();
    return _inFlight ??= () async {
      try {
        final (friends, incoming, outgoing, watching) = await (
          _api.friends(),
          _api.incoming(),
          _api.outgoing(),
          _api.friendsWatching(),
        ).wait;
        if (_signedIn) {
          state = FriendsState(friends: friends, incoming: incoming, outgoing: outgoing, watching: watching);
        }
      } finally {
        _inFlight = null;
      }
    }();
  }

  Future<void> _refreshWatching() async {
    final watching = await _api.friendsWatching();
    if (_signedIn) state = state.copyWith(watching: watching);
  }

  void _onMessage(Map<String, dynamic> data) {
    final events = ref.read(friendsEventsProvider);
    if (data['type'] != 'friend_watching') {
      events._friends.add('${data['type']}');
      refresh();
      return;
    }

    final clerkId = '${data['clerkId']}';
    final watching = WatchingTarget.fromJson(data['watching']);
    final next = {...state.watching};
    if (watching == null) {
      next.remove(clerkId);
    } else {
      next[clerkId] = watching;
    }
    state = state.copyWith(watching: next);
    events._watching.add(
      WatchingPush(
        actor: Friend(
          clerkId: clerkId,
          displayName: data['actorDisplayName'] as String?,
          profileImageURL: data['actorProfileImageURL'] as String?,
        ),
        watching: watching,
      ),
    );
  }

  Future<void> accept(String requestId) async {
    await _api.accept(requestId);
    await refresh();
  }

  Future<void> cancelOrDecline(String requestId) async {
    await _api.cancelOrDecline(requestId);
    await refresh();
  }

  /// Sending to someone who already invited you accepts their request.
  Future<void> send(String clerkId) async {
    await _api.send(clerkId);
    await refresh();
  }

  Future<void> remove(String clerkId) async {
    await _api.remove(clerkId);
    await refresh();
  }
}

final friendsProvider = NotifierProvider<FriendsController, FriendsState>(FriendsController.new);

/// `wss://…/ws?token=<session token>`, reconnecting with a doubling backoff
/// (300ms → 8s) whenever it drops.
class _FriendsSocket {
  _FriendsSocket({required this.getToken, required this.onMessage});

  final Future<String?> Function() getToken;
  final void Function(Map<String, dynamic> data) onMessage;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnect;
  Duration _delay = _reconnectStart;
  bool _closed = false;

  Future<void> connect() async {
    if (_closed) return;
    final token = await getToken();
    if (token == null || _closed) return;

    try {
      final channel = WebSocketChannel.connect(Uri.parse('$wsBaseUrl/ws?token=${Uri.encodeComponent(token)}'));
      _channel = channel;
      _subscription = channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode('$message');
            if (data is Map<String, dynamic>) onMessage(data);
          } catch (_) {
            // Not ours to act on.
          }
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
      await channel.ready;
      _delay = _reconnectStart;
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_closed || (_reconnect?.isActive ?? false)) return;
    _subscription?.cancel();
    _channel = null;
    _reconnect = Timer(_delay, connect);
    final doubled = _delay * 2;
    _delay = doubled > _reconnectMax ? _reconnectMax : doubled;
  }

  void close() {
    _closed = true;
    _reconnect?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
  }
}
