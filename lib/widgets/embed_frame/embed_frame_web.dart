import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

int _nextViewId = 0;

/// Native builds push a route for a fullscreen video; the browser's own
/// fullscreen doesn't, so nothing ever needs to wait for it here.
bool get isEmbedFullscreen => false;

/// Browser build: a plain <iframe>, exactly as the website renders it.
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
  late final String _viewType = 'aurora-embed-${_nextViewId++}';
  StreamSubscription<web.MessageEvent>? _messages;
  web.HTMLIFrameElement? _iframe;

  /// Whether this embed's page is the one on screen — every tab (and a page
  /// under a pushed one) stays alive offstage, so leaving the page blanks
  /// the iframe and coming back loads the embed afresh.
  bool _onScreen = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onScreen = TickerMode.valuesOf(context).enabled;
    if (onScreen == _onScreen) return;
    _onScreen = onScreen;
    _iframe?.src = onScreen ? widget.url : 'about:blank';
  }

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = widget.url
        // "*": a bare "fullscreen" only covers the first origin, and some
        // players redirect to another domain (EmbedMaster).
        ..allow = 'accelerometer *; autoplay *; clipboard-write *; encrypted-media *; gyroscope *; picture-in-picture *; fullscreen *'
        ..allowFullscreen = true
        ..setAttribute('scrolling', 'no');
      if (widget.sandbox != null) iframe.setAttribute('sandbox', widget.sandbox!);
      _iframe = iframe;

      final percent = '${100 / widget.uiScale}%';
      iframe.style
        ..border = '0'
        ..position = 'absolute'
        ..top = '0'
        ..left = '0'
        ..width = percent
        ..height = percent
        ..transform = 'scale(${widget.uiScale})'
        ..transformOrigin = '0 0';
      iframe.onLoad.listen((_) => widget.onLoaded?.call());

      final host = web.HTMLDivElement();
      host.style
        ..position = 'relative'
        ..width = '100%'
        ..height = '100%'
        ..overflow = 'hidden'
        ..background = '#000';
      host.append(iframe);
      return host;
    });

    _messages = web.window.onMessage.listen((event) {
      widget.onMessage?.call(event.origin, event.data.dartify());
    });
  }

  @override
  void dispose() {
    _messages?.cancel();
    _iframe?.src = 'about:blank';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}

JSFunction? _leaveGuard;

/// Website: while a player that can't be sandboxed is playing, a click in
/// it can send the whole tab to an ad site — so the browser asks "Leave
/// site?" first.
void setLeavePageGuard(bool enabled) {
  if (enabled && _leaveGuard == null) {
    _leaveGuard = ((web.Event event) {
      event.preventDefault();
    }).toJS;
    web.window.addEventListener('beforeunload', _leaveGuard);
  } else if (!enabled && _leaveGuard != null) {
    web.window.removeEventListener('beforeunload', _leaveGuard);
    _leaveGuard = null;
  }
}
