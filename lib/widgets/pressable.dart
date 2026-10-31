import 'package:flutter/material.dart';

/// Tap target that shrinks a little while pressed — the site's
/// `active:scale-95` — and springs back on release.
///
/// It's also a focus stop for a TV remote or a keyboard: the arrows move
/// between Pressables, OK / Enter taps the focused one, and it lifts with a
/// white ring — the site's `focus-visible:ring-2 ring-white`. The ring only
/// shows while navigating with keys, so touch screens never see it.
/// [focusRadius] should match the child's corner radius (999 for pills).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.95,
    this.semanticLabel,
    this.focusRadius = 14,
    this.autofocus = false,
    this.focusNode,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final String? semanticLabel;
  final double focusRadius;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _setFocused(bool value) {
    if (_focused != value) setState(() => _focused = value);
  }

  /// Brings the focused one to the middle of every list it's in, rather than
  /// just to the edge — where the floating header and tab bar would cover it.
  void _scrollIntoView(bool focused) {
    if (!focused || FocusManager.instance.highlightMode != FocusHighlightMode.traditional) return;
    Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.focusRadius);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: widget.onTap != null,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        mouseCursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onShowFocusHighlight: _setFocused,
        onFocusChange: _scrollIntoView,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed ? widget.pressedScale : (_focused ? 1.05 : 1),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            // Always the same two boxes, so focusing doesn't rebuild the child.
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [if (_focused) BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: -2)],
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: _focused ? Colors.white : Colors.transparent, width: 2.5),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
