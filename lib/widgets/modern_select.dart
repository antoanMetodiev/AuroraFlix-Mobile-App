import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';
import 'pressable.dart';

class SelectOption {
  const SelectOption(this.value, this.label);

  final String value;
  final String label;
}

/// The website's ModernSelect: a pill showing the current choice that turns
/// white while open, with a rounded, scrollable list of options (checkmark
/// on the selected one) unfolding beneath it.
class ModernSelect extends StatefulWidget {
  const ModernSelect({super.key, required this.value, required this.options, required this.onChanged, this.expand = false});

  final String value;
  final List<SelectOption> options;
  final ValueChanged<String> onChanged;

  /// Full width (the phone layout of the list filters).
  final bool expand;

  @override
  State<ModernSelect> createState() => _ModernSelectState();
}

class _ModernSelectState extends State<ModernSelect> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _buttonKey = GlobalKey();

  void _toggle() => setState(() => _portal.isShowing ? _portal.hide() : _portal.show());

  void _close() => setState(_portal.hide);

  @override
  Widget build(BuildContext context) {
    final open = _portal.isShowing;
    final label = widget.options.where((option) => option.value == widget.value).firstOrNull?.label ?? '';

    final button = Pressable(
      key: _buttonKey,
      onTap: _toggle,
      pressedScale: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: open ? Colors.white : AppColors.fg(0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: open ? Colors.transparent : AppColors.fg(0.1)),
          boxShadow: open
              ? [BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: -4, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Flexible(
              fit: widget.expand ? FlexFit.tight : FlexFit.loose,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: open ? AppColors.onWhite : AppColors.fg(0.85),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(LucideIcons.chevronDown, size: 16, color: open ? AppColors.onWhite : AppColors.fg(0.85)),
            ),
          ],
        ),
      ),
    );

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) {
          final buttonBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
          final minWidth = buttonBox?.size.width ?? 0;
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close),
              ),
              CompositedTransformFollower(
                link: _link,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 8),
                child: _OptionsPanel(
                  options: widget.options,
                  value: widget.value,
                  minWidth: minWidth,
                  onSelect: (value) {
                    _close();
                    widget.onChanged(value);
                  },
                ),
              ),
            ],
          );
        },
        child: button,
      ),
    );
  }
}

class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({required this.options, required this.value, required this.minWidth, required this.onSelect});

  final List<SelectOption> options;
  final String value;
  final double minWidth;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = options.indexWhere((option) => option.value == value);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.95 + 0.05 * t, alignment: Alignment.topRight, child: child),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth, maxHeight: 320),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.fg(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 50, spreadRadius: -12, offset: const Offset(0, 20)),
            ],
          ),
          child: IntrinsicWidth(
            child: SingleChildScrollView(
              // Long lists (years) open scrolled to the current choice.
              controller: ScrollController(initialScrollOffset: selectedIndex > 4 ? (selectedIndex - 2) * 38.0 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < options.length; index++)
                    Builder(
                      builder: (context) {
                        final option = options[index];
                        final active = option.value == value;
                        return Pressable(
                          pressedScale: 1,
                          onTap: () => onSelect(option.value),
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: active ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.label,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: active ? Colors.white : AppColors.fg(0.7),
                                    ),
                                  ),
                                ),
                                if (active) ...[const SizedBox(width: 16), const Icon(LucideIcons.check, size: 14, color: Colors.white)],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
