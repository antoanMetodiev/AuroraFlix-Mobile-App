import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _device = MethodChannel('auroraflix/device');

/// Whether the app runs on an Android TV (UiModeManager / leanback, see
/// MainActivity). The browser build has no TV, so there `?tv=1` in the
/// address turns the TV layout on for testing at 1920×1080.
Future<bool> detectTv() async {
  if (kIsWeb) return Uri.base.queryParameters['tv'] == '1';
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await _device.invokeMethod<bool>('isTv') ?? false;
  } catch (_) {
    return false;
  }
}

/// Read once in main() and fixed for the app's lifetime.
final isTvProvider = Provider<bool>((ref) => throw UnimplementedError('Overridden in main()'));

/// Every page lives in its own focus scope (a route of the shell's
/// navigator), apart from the header and the tab bar, and a remote's arrows
/// stop at a scope's edge. This lets them carry on from a page's top / bottom
/// up into the header or down into the tab bar. Dialogs and sheets keep
/// their edges, so focus can't wander out to the page behind them.
void bridgePageFocusScopes() {
  // A remote has no pointer, so the focus ring shows from the start.
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  FocusManager.instance.addListener(() {
    final scope = FocusManager.instance.primaryFocus?.nearestScope;
    final context = scope?.context;
    if (scope == null || context == null || scope == FocusManager.instance.rootScope) return;
    // Only a page's own scope — not a dialog's, nor a panel's inside a page.
    // (A route's own scope is the outermost one inside it.)
    final route = ModalRoute.of(context);
    final outer = scope.enclosingScope?.context;
    if (route is! PageRoute || (outer != null && ModalRoute.of(outer) == route)) return;
    scope.directionalTraversalEdgeBehavior = TraversalEdgeBehavior.parentScope;
    // Seen from the header, the page's scope is one screen-sized target
    // whose centre beats the buttons beside the logo — only its items count.
    scope.skipTraversal = true;
  });
}

