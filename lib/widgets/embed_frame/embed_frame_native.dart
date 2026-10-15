import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// The page the embed is hosted in. Using auroraflix.cloud as its address
/// means the player sees the same Referer as on the website.
const _hostUrl = 'https://auroraflix.cloud/';

String _escapeAttribute(String value) => const HtmlEscape(HtmlEscapeMode.attribute).convert(value);

/// One <iframe> filling the page, scaled by [uiScale] (VidFast's controls are
/// shown smaller, like on the site), forwarding its `postMessage`s and its
/// load event to the app.
String _hostPage({required String url, String? sandbox, required double uiScale}) {
  final size = '${100 / uiScale}%';
  return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>
  html, body { margin: 0; height: 100%; background: #000; overflow: hidden; }
  iframe { position: absolute; top: 0; left: 0; border: 0; width: $size; height: $size;
           transform: scale($uiScale); transform-origin: 0 0; }
</style>
</head>
<body>
<!-- "*" on every feature: a bare "fullscreen" only allows the iframe's first
     origin, and some players (EmbedMaster) redirect to another domain, which
     then silently loses fullscreen. -->
<iframe src="${_escapeAttribute(url)}"
        allow="accelerometer *; autoplay *; clipboard-write *; encrypted-media *; gyroscope *; picture-in-picture *; fullscreen *"
        allowfullscreen scrolling="no"
        ${sandbox == null ? '' : 'sandbox="${_escapeAttribute(sandbox)}"'}></iframe>
<script>
  // Not an inline onload="…" attribute: the JSON's quotes would end the
  // attribute early (HTML has no backslash escapes) and it never fired.
  document.querySelector('iframe').addEventListener('load', function () {
    try { AuroraBridge.postMessage(JSON.stringify({ loaded: true })); } catch (e) {}
  });
  window.addEventListener('message', function (event) {
    try { AuroraBridge.postMessage(JSON.stringify({ origin: event.origin, data: event.data })); } catch (e) {}
  });
</script>
</body>
</html>''';
}

/// Native build: a WebView hosting the <iframe>.
///
/// It also does what the browser can't for the website: new windows
/// (pop-up ads) never open, and the host page can't be navigated away (redirect
/// ads) — only the iframe itself moves. A video going fullscreen gets the
/// whole screen in landscape.
class EmbedFrame extends StatefulWidget {
  const EmbedFrame({super.key, required this.url, this.sandbox, this.uiScale = 1, this.onLoaded, this.onMessage});

  final String url;

  /// The iframe's `sandbox` attribute (ad-free players), or null for none.
  final String? sandbox;
  final double uiScale;
  final VoidCallback? onLoaded;

  /// `postMessage` events from the embedded page: (origin, data).
  final void Function(String origin, Object? data)? onMessage;

  @override
  State<EmbedFrame> createState() => _EmbedFrameState();
}

class _EmbedFrameState extends State<EmbedFrame> {
  late final WebViewController _controller = _createController();

  WebViewController _createController() {
    final PlatformWebViewControllerCreationParams params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true, mediaTypesRequiringUserAction: const {})
        : const PlatformWebViewControllerCreationParams();

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('AuroraBridge', onMessageReceived: _onBridgeMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Only the iframe may navigate; the host page stays put.
          onNavigationRequest: (request) => request.isMainFrame && !request.url.startsWith(_hostUrl) && request.url != 'about:blank'
              ? NavigationDecision.prevent
              : NavigationDecision.navigate,
        ),
      );

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
      platform.setCustomWidgetCallbacks(onShowCustomWidget: _showFullscreen, onHideCustomWidget: _hideFullscreen);
    }

    controller.loadHtmlString(
      _hostPage(url: widget.url, sandbox: widget.sandbox, uiScale: widget.uiScale),
      baseUrl: _hostUrl,
    );
    return controller;
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is Map && decoded['loaded'] == true) {
        widget.onLoaded?.call();
      } else if (decoded is Map) {
        widget.onMessage?.call('${decoded['origin']}', decoded['data']);
      }
    } catch (_) {}
  }

  bool _fullscreen = false;

  Future<void> _showFullscreen(Widget video, void Function() onHidden) async {
    _fullscreen = true;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    // The video's native view takes its size when it's first shown and
    // doesn't follow the rotation afterwards — pushed right away, it kept the
    // portrait size and sat as a small window in the middle of the black
    // screen. So wait for the screen to actually be landscape first.
    await _untilLandscape();
    if (!mounted || !_fullscreen) return;

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (context, _, _) => PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) onHidden();
          },
          child: ColoredBox(
            color: Colors.black,
            child: SizedBox.expand(child: video),
          ),
        ),
      ),
    );
  }

  /// Resolves once the screen is wider than tall (or after ~1.2s, whichever
  /// comes first), plus a moment for the system bars to finish hiding.
  Future<void> _untilLandscape() async {
    final view = View.of(context);
    final deadline = DateTime.now().add(const Duration(milliseconds: 1200));
    while (view.physicalSize.width <= view.physicalSize.height && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  void _hideFullscreen() {
    if (!_fullscreen) return;
    _fullscreen = false;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  void dispose() {
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  // Inside a scrolling page the scroll view used to win every touch that
  // moved even slightly, so a player's seek bar never got its drag (or even
  // a tap). The player gets sideways drags, taps and long presses; vertical
  // swipes still scroll the page.
  static final _gestures = <Factory<OneSequenceGestureRecognizer>>{
    Factory<HorizontalDragGestureRecognizer>(HorizontalDragGestureRecognizer.new),
    Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
    Factory<LongPressGestureRecognizer>(LongPressGestureRecognizer.new),
  };

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller, gestureRecognizers: _gestures);
}

/// Website: a "Leave site?" prompt while a redirect-prone player plays. In
/// the native build the WebView already blocks those redirects.
void setLeavePageGuard(bool enabled) {}
