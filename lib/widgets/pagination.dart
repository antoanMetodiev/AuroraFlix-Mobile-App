import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'pressable.dart';

/// Page numbers around [current], with the first/last pages and "…" gaps
/// (website: generatePages, 3 visible on a phone).
List<int?> _pages(int current, int total, int visible) {
  final pages = <int?>[];
  final half = visible ~/ 2;
  var start = (current - half).clamp(1, total);
  var end = start + visible - 1;
  if (end > total) {
    end = total;
    start = (end - visible + 1).clamp(1, total);
  }
  if (start > 1) pages.add(1);
  if (start > 2) pages.add(null);
  for (var page = start; page <= end; page++) {
    pages.add(page);
  }
  if (end < total - 1) pages.add(null);
  if (end < total) pages.add(total);
  return pages;
}

/// The website's PaginationControls: a frosted pill of round page buttons,
/// the current one white and glowing, ◀ ▶ at the ends.
class PaginationControls extends StatelessWidget {
  const PaginationControls({super.key, required this.current, required this.total, required this.onPage});

  final int current;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 32),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.fg(0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.fg(0.12)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 25, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PageButton(label: '◀', disabled: current == 1, onTap: () => onPage(current - 1)),
            for (final page in _pages(current, total, 3))
              page == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('…', style: TextStyle(fontSize: 12, color: AppColors.fg(0.65))),
                    )
                  : _PageButton(label: '$page', active: page == current, onTap: () => onPage(page)),
            _PageButton(label: '▶', disabled: current == total, onTap: () => onPage(current + 1)),
          ],
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.label, required this.onTap, this.active = false, this.disabled = false});

  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Pressable(
        onTap: disabled || active ? null : onTap,
        child: Opacity(
          opacity: disabled ? 0.35 : 1,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white : AppColors.fg(0.08),
              border: Border.all(color: active ? Colors.transparent : AppColors.fg(0.12)),
              boxShadow: active ? [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 15)] : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? AppColors.onWhite : AppColors.fg(0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
