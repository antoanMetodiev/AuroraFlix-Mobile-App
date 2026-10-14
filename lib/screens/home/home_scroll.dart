import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Places on the home screen something elsewhere can ask it to scroll to —
/// the website's `/#pricing` link.
enum HomeAnchor { pricing }

class HomeScrollRequest {
  const HomeScrollRequest(this.anchor, this.id);

  final HomeAnchor anchor;

  /// Bumped per request, so asking twice for the same place scrolls twice.
  final int id;
}

class HomeScrollRequestController extends Notifier<HomeScrollRequest?> {
  @override
  HomeScrollRequest? build() => null;

  void request(HomeAnchor anchor) => state = HomeScrollRequest(anchor, (state?.id ?? 0) + 1);
}

final homeScrollRequestProvider = NotifierProvider<HomeScrollRequestController, HomeScrollRequest?>(HomeScrollRequestController.new);
