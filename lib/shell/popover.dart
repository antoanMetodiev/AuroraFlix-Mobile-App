import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Header dropdown panel (search, menu): fades and scales in from the corner
/// it's anchored to — the site's `scale-95 opacity-0` → `scale-100
/// opacity-100` over 200ms — and ignores touches (and a remote's focus)
/// while closed.
///
/// With a remote, opening it moves the focus inside — the panel sits off to
/// the side, so the arrows alone wouldn't reach it — and keeps it there;
/// closing it hands the focus back to the button that opened it.
class Popover extends StatefulWidget {
  const Popover({super.key, required this.open, required this.child, this.alignment = Alignment.topRight, this.width, this.bare = false});

  final bool open;
  final Widget child;
  final Alignment alignment;
  final double? width;

  /// The child draws its own panel (e.g. the Clerk-styled account menu).
  final bool bare;

  @override
  State<Popover> createState() => _PopoverState();
}

class _PopoverState extends State<Popover> {
  final _scope = FocusScopeNode(debugLabel: 'Popover');
  FocusNode? _openedFrom;

  @override
  void didUpdateWidget(Popover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open == oldWidget.open || FocusManager.instance.highlightMode != FocusHighlightMode.traditional) return;
    if (widget.open) {
      _openedFrom = FocusManager.instance.primaryFocus;
      // After this frame, once the panel takes focus again. A panel that
      // focuses something itself (search's field) keeps that.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.open || _scope.hasFocus) return;
        FocusTraversalGroup.maybeOf(context)?.findFirstFocus(_scope)?.requestFocus();
      });
    } else {
      final openedFrom = _openedFrom;
      _openedFrom = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (openedFrom != null && openedFrom.context != null && FocusManager.instance.primaryFocus is FocusScopeNode) openedFrom.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 200);

    return IgnorePointer(
      ignoring: !widget.open,
      child: ExcludeFocus(
        excluding: !widget.open,
        child: FocusScope(
          node: _scope,
          child: AnimatedOpacity(
            opacity: widget.open ? 1 : 0,
            duration: duration,
            curve: Curves.easeOut,
            child: AnimatedScale(
              scale: widget.open ? 1 : 0.95,
              alignment: widget.alignment,
              duration: duration,
              curve: Curves.easeOut,
              child: widget.bare
                  ? SizedBox(width: widget.width, child: widget.child)
                  : Container(
                      width: widget.width,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.fg(0.1)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 45, offset: const Offset(0, 20))],
                      ),
                      child: widget.child,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
