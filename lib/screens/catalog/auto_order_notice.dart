import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/catalog_api.dart';
import '../../core/api/catalog_cache.dart';
import '../../core/i18n/locale.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../router.dart';
import '../../widgets/cinema_record_card.dart';
import '../../widgets/pressable.dart';
import 'catalog_screen.dart';

/// Searches already ordered this session, so coming back to one doesn't
/// order it again.
final _ordered = <String>{};

/// When the screen looks again by itself after the order went out.
const _recheckAfter = [Duration(seconds: 6), Duration(seconds: 15)];

enum _Status { sending, sent, error }

/// Shown instead of the empty grid when a title search finds nothing — the
/// website's AutoOrderNotice: the search text is sent off as an order (same
/// request as the Order screen), so the generator adds the title, and the
/// results are re-checked a couple of times; once it's in, the grid replaces
/// this.
class AutoOrderNotice extends ConsumerStatefulWidget {
  const AutoOrderNotice({super.key, required this.query});

  final CatalogQuery query;

  @override
  ConsumerState<AutoOrderNotice> createState() => _AutoOrderNoticeState();
}

class _AutoOrderNoticeState extends ConsumerState<AutoOrderNotice> {
  _Status _status = _Status.sending;
  final _timers = <Timer>[];

  RecordType get _type => widget.query.type;
  String get _search => widget.query.search ?? '';

  @override
  void initState() {
    super.initState();
    final key = '${_type.name}:${_search.trim().toLowerCase()}';
    if (_ordered.contains(key)) {
      _status = _Status.sent;
      _scheduleRechecks();
      return;
    }
    _order(key);
  }

  Future<void> _order(String key) async {
    final ok = await ref.read(catalogApiProvider).order(_type, _search);
    if (!mounted) return;
    if (!ok) {
      setState(() => _status = _Status.error);
      return;
    }
    _ordered.add(key);
    // Lets the lists skip their cache too, so it shows there as well.
    markCatalogFresh();
    setState(() => _status = _Status.sent);
    _scheduleRechecks();
  }

  void _scheduleRechecks() {
    for (final delay in _recheckAfter) {
      _timers.add(Timer(delay, _recheck));
    }
  }

  void _recheck() {
    if (mounted) ref.invalidate(catalogPageProvider(widget.query));
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);

    return EmptyResults(
      title: t('search.autoOrderTitle', {'query': _search}),
      message: switch (_status) {
        _Status.sending => t('search.autoOrderSending'),
        _Status.sent => t('search.autoOrderSent'),
        _Status.error => t('search.autoOrderFailed'),
      },
      action: switch (_status) {
        _Status.sending => SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.fg(0.6)),
        ),
        _Status.sent => _WhiteButton(icon: LucideIcons.refreshCw, label: t('search.checkAgain'), onTap: _recheck),
        _Status.error => _WhiteButton(
          label: t('search.orderManually'),
          onTap: () => context.go('/order/${_type == RecordType.movie ? 'movie' : 'series'}'),
        ),
      },
    );
  }
}

/// The site's white pill button (`rounded-full bg-white … shadow`).
class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 15, color: AppColors.onWhite), const SizedBox(width: 8)],
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onWhite)),
          ],
        ),
      ),
    );
  }
}
