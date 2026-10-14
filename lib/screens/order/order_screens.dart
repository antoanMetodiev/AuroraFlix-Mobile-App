import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/catalog_api.dart';
import '../../core/i18n/locale.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../shell/app_shell.dart';
import '../../widgets/footer.dart';
import '../../widgets/loader.dart';
import '../../widgets/pressable.dart';

/// Centered page body that fills the screen above the footer — both order
/// pages use it (website: `min-h-[calc(100vh-4rem)]` centered column).
class _CenteredPage extends StatelessWidget {
  const _CenteredPage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final padding = shellContentPadding(context);
    final minHeight = MediaQuery.sizeOf(context).height - padding.top - padding.bottom;
    return ListView(
      padding: padding,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: children),
          ),
        ),
        const SiteFooter(),
      ],
    );
  }
}

/// "What would you like to order?" — Movie / Series (website: OrderSelectPage).
class OrderSelectScreen extends ConsumerWidget {
  const OrderSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translatorProvider);

    Widget option(RecordType type, IconData icon, String label) => Pressable(
      onTap: () => context.push('/order/${type.name}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.fg(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.fg(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.fg(0.7)),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );

    return _CenteredPage(
      children: [
        Text(
          t('order.selectTitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6),
        ),
        const SizedBox(height: 16),
        Text(
          t('order.selectDesc'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.fg(0.5)),
        ),
        const SizedBox(height: 40),
        option(RecordType.movie, LucideIcons.clapperboard, t('order.movie')),
        const SizedBox(height: 16),
        option(RecordType.series, LucideIcons.tv, t('order.series')),
      ],
    );
  }
}

const _cooldownKey = 'AURORAFLIX_ORDER_COOLDOWN_UNTIL';
const _cooldownSeconds = 10;

enum _Status { idle, sending, success, error }

/// "Order Movie" / "Order Series" with the request field (website:
/// OrderTypePage + OrderForm) — a 10-second cooldown after each request
/// that survives leaving the page.
class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key, required this.type});

  final RecordType type;

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  _Status _status = _Status.idle;
  int _remaining = 0;
  bool _submitting = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final until = ref.read(sharedPreferencesProvider).getInt(_cooldownKey) ?? 0;
    _setRemaining(((until - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, _cooldownSeconds));
  }

  void _setRemaining(int seconds) {
    _remaining = seconds;
    _ticker?.cancel();
    if (seconds <= 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remaining = (_remaining - 1).clamp(0, _cooldownSeconds));
      if (_remaining == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canSubmit => _remaining == 0 && !_submitting;

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty || !_canSubmit) return;
    setState(() {
      _submitting = true;
      _status = _Status.sending;
    });
    final ok = await ref.read(catalogApiProvider).order(widget.type, title);
    await ref.read(sharedPreferencesProvider).setInt(_cooldownKey, DateTime.now().millisecondsSinceEpoch + _cooldownSeconds * 1000);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _setRemaining(_cooldownSeconds);
      _status = ok ? _Status.success : _Status.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final isMovie = widget.type == RecordType.movie;
    final message = switch (_status) {
      _Status.sending => t('order.sending'),
      _Status.success => isMovie ? t('order.successMovies') : t('order.successSeries'),
      _Status.error => t('order.error'),
      _Status.idle => t('order.idleMessage'),
    };
    final buttonEnabled = _canSubmit && _controller.text.trim().isNotEmpty;

    return _CenteredPage(
      children: [
        Text(
          isMovie ? t('order.orderMovie') : t('order.orderSeries'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6),
        ),
        const SizedBox(height: 48),
        Stack(
          clipBehavior: Clip.none,
          children: [
            if (_remaining > 0)
              Positioned(
                right: 0,
                top: -32,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.fg(0.1), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    '${_remaining}s',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.fg(0.8)),
                  ),
                ),
              ),
            ListenableBuilder(
              listenable: _focus,
              builder: (context, _) => Opacity(
                opacity: _canSubmit ? 1 : 0.5,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: AppColors.fg(_focus.hasFocus ? 0.1 : 0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _focus.hasFocus ? Colors.white : AppColors.fg(0.15), width: _focus.hasFocus ? 1.5 : 1),
                    boxShadow: _focus.hasFocus
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.35),
                              blurRadius: 28,
                              spreadRadius: -6,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          enabled: _canSubmit,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _submit(),
                          textInputAction: TextInputAction.send,
                          cursorColor: Colors.white,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: isMovie ? t('order.placeholderMovie') : t('order.placeholderSeries'),
                            hintStyle: TextStyle(color: AppColors.fg(0.35)),
                            contentPadding: const EdgeInsets.fromLTRB(24, 15, 8, 15),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Pressable(
                          onTap: buttonEnabled ? _submit : null,
                          semanticLabel: t('order.submitAria'),
                          child: Opacity(
                            opacity: buttonEnabled || _submitting ? 1 : 0.4,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              child: _submitting
                                  ? const Center(child: Spinner(size: 16, color: AppColors.onWhite))
                                  : const Icon(LucideIcons.send, size: 16, color: AppColors.onWhite),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.fg(0.55)),
        ),
      ],
    );
  }
}
