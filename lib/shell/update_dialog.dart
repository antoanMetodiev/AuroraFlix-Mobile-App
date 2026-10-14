import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n/locale.dart';
import '../core/theme.dart';
import '../core/update/app_update.dart';
import '../screens/friends/friend_widgets.dart';
import '../widgets/pressable.dart';

/// "A new version is out" — downloads the APK inside the app and opens
/// Android's installer (the person confirms once; Android never installs a
/// sideloaded app silently).
Future<void> showUpdateDialog(BuildContext context, AppRelease release) =>
    showAuroraModal(context, builder: (context) => _UpdateDialog(release: release));

class _UpdateDialog extends ConsumerStatefulWidget {
  const _UpdateDialog({required this.release});

  final AppRelease release;

  @override
  ConsumerState<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<_UpdateDialog> {
  StreamSubscription<OtaEvent>? _download;

  /// 0–100 while downloading, null before.
  int? _progress;
  bool _failed = false;

  @override
  void dispose() {
    _download?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _progress = 0;
      _failed = false;
    });
    try {
      _download = OtaUpdate()
          .execute(widget.release.url, destinationFilename: 'auroraflix-${widget.release.versionName}.apk')
          .listen(_onEvent, onError: (_) => _fail());
    } catch (_) {
      _fail();
    }
  }

  void _onEvent(OtaEvent event) {
    if (!mounted) return;
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        setState(() => _progress = int.tryParse(event.value ?? '') ?? _progress);
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        setState(() => _progress = 100);
      case OtaStatus.CANCELED:
        setState(() => _progress = null);
      default:
        _fail();
    }
  }

  void _fail() {
    if (mounted) setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translatorProvider);
    final locale = ref.watch(localeProvider);
    final release = widget.release;
    final notes = release.notes[locale.name] ?? release.notes['en'] ?? release.notes['bg'];
    final downloading = _progress != null && !_failed;

    Widget pill(String label, VoidCallback onTap, {required bool primary, IconData? icon}) => Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: primary ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: primary ? null : Border.all(color: AppColors.fg(0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: primary ? AppColors.onWhite : AppColors.fg(0.7)), const SizedBox(width: 8)],
              Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary ? AppColors.onWhite : AppColors.fg(0.7)),
              ),
            ],
          ),
        ),
      ),
    );

    return AuroraModalCard(
      header: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: const Icon(LucideIcons.download, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(t('app.updateTitle'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('app.updateDesc', {'version': release.versionName}), style: TextStyle(fontSize: 14, color: AppColors.fg(0.7))),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(notes, style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.fg(0.55))),
            ],
            const SizedBox(height: 24),
            if (downloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _progress! / 100,
                  minHeight: 6,
                  backgroundColor: AppColors.fg(0.1),
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t('app.updateDownloading', {'percent': _progress!}),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.fg(0.5)),
              ),
            ] else ...[
              if (_failed) ...[
                Text(
                  t('app.updateFailed'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.fg(0.6)),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                spacing: 12,
                children: [
                  if (_failed)
                    pill(
                      t('app.updateInBrowser'),
                      () => launchUrl(Uri.parse(release.url), mode: LaunchMode.externalApplication),
                      primary: false,
                    )
                  else
                    pill(t('app.updateLater'), () => Navigator.of(context).pop(), primary: false),
                  pill(t('app.updateNow'), _start, primary: true, icon: LucideIcons.download),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
