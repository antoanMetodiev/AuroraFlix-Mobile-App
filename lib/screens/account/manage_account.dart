import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/clerk_api.dart';
import '../../core/auth/clerk_models.dart';
import '../../core/theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/user_avatar.dart';
import '../auth/clerk_ui.dart';

/// "Manage account" — Clerk's UserProfile as the website shows it (dark,
/// English like the rest of Clerk's UI): Profile (picture and name, email
/// addresses, connected accounts) and Security (password, active devices,
/// delete account).
Future<void> showManageAccount(BuildContext context) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close',
  barrierColor: Colors.black.withValues(alpha: 0.6),
  transitionDuration: const Duration(milliseconds: 260),
  pageBuilder: (context, _, _) => const _ManageAccount(),
  transitionBuilder: (context, animation, _, child) {
    final curved = CurvedAnimation(parent: animation, curve: auroraEase, reverseCurve: Curves.easeIn);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4 * animation.value, sigmaY: 4 * animation.value),
      child: FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
      ),
    );
  },
);

enum _Page { profile, security }

/// Which inline form replaces a section's rows (Clerk swaps them in place).
enum _Form { none, profile, addEmail, verifyEmail, password, delete }

class _ManageAccount extends ConsumerStatefulWidget {
  const _ManageAccount();

  @override
  ConsumerState<_ManageAccount> createState() => _ManageAccountState();
}

class _ManageAccountState extends ConsumerState<_ManageAccount> {
  _Page _page = _Page.profile;
  _Form _form = _Form.none;
  String? _pendingEmailId;
  String? _pendingEmail;

  void _openForm(_Form form) => setState(() => _form = form);
  void _closeForm() => setState(() => _form = _Form.none);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final media = MediaQuery.of(context);

    if (user == null) {
      // Signed out (account deleted / session ended) — nothing to manage.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    Widget navItem(_Page page, IconData icon, String label) {
      final active = _page == page;
      return Pressable(
        onTap: () => setState(() {
          _page = page;
          _form = _Form.none;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : ClerkColors.muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? Colors.white : ClerkColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    final sections = _page == _Page.profile
        ? <Widget>[
            _Section(
              title: 'Profile',
              child: _form == _Form.profile
                  ? _ProfileForm(user: user, onDone: _closeForm)
                  : Row(
                      children: [
                        UserAvatar(user: user, size: 44),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            user.fullName.isEmpty ? (user.email ?? '') : user.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        _TextButton(label: 'Update profile', onTap: () => _openForm(_Form.profile)),
                      ],
                    ),
            ),
            _Section(
              title: 'Email addresses',
              child: switch (_form) {
                _Form.addEmail => _AddEmailForm(
                  onCancel: _closeForm,
                  onAdded: (id, address) => setState(() {
                    _pendingEmailId = id;
                    _pendingEmail = address;
                    _form = _Form.verifyEmail;
                  }),
                ),
                _Form.verifyEmail => _VerifyEmailForm(emailId: _pendingEmailId!, address: _pendingEmail ?? '', onDone: _closeForm),
                _ => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final email in user.emails)
                      _Row(
                        leading: Flexible(
                          child: Text(email.address, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                        ),
                        badges: [
                          if (email.isPrimary) const _Badge('Primary'),
                          if (!email.verified) const _Badge('Unverified', danger: true),
                        ],
                        actions: [
                          if (!email.isPrimary && email.verified)
                            _MenuAction('Set as primary', () => ref.read(authProvider.notifier).setPrimaryEmail(email.id)),
                          if (!email.verified)
                            _MenuAction('Complete verification', () async {
                              await ref.read(authProvider.notifier).resendEmailCode(email.id);
                              setState(() {
                                _pendingEmailId = email.id;
                                _pendingEmail = email.address;
                                _form = _Form.verifyEmail;
                              });
                            }),
                          if (!email.isPrimary)
                            _MenuAction('Remove email', () => ref.read(authProvider.notifier).removeEmail(email.id), danger: true),
                        ],
                      ),
                    _AddLink(label: 'Add email address', onTap: () async => _openForm(_Form.addEmail)),
                  ],
                ),
              },
            ),
            _Section(
              title: 'Connected accounts',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final account in user.externalAccounts)
                    _Row(
                      leading: Flexible(
                        child: Row(
                          children: [
                            const ClerkGoogleLogo(),
                            const SizedBox(width: 10),
                            Text(
                              account.provider == 'google' ? 'Google' : account.provider,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            if (account.email != null) ...[
                              Text(' • ', style: TextStyle(fontSize: 13, color: ClerkColors.muted)),
                              Flexible(
                                child: Text(
                                  account.email!,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: ClerkColors.muted),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      actions: [
                        _MenuAction(
                          'Remove connected account',
                          () => ref.read(authProvider.notifier).removeExternalAccount(account.id),
                          danger: true,
                        ),
                      ],
                    ),
                  if (!user.externalAccounts.any((account) => account.provider == 'google'))
                    _AddLink(label: 'Connect account', onTap: () => ref.read(authProvider.notifier).connectGoogle()),
                ],
              ),
            ),
          ]
        : <Widget>[
            _Section(
              title: 'Password',
              child: _form == _Form.password
                  ? _PasswordForm(hasPassword: user.passwordEnabled, onDone: _closeForm)
                  : Row(
                      children: [
                        if (user.passwordEnabled) const Text('••••••••••', style: TextStyle(fontSize: 13, letterSpacing: 1)),
                        const Spacer(),
                        _TextButton(
                          label: user.passwordEnabled ? 'Update password' : 'Set password',
                          onTap: () => _openForm(_Form.password),
                        ),
                      ],
                    ),
            ),
            const _Section(title: 'Active devices', child: _ActiveDevices()),
            _Section(
              title: 'Delete account',
              last: true,
              child: _form == _Form.delete
                  ? _DeleteForm(onCancel: _closeForm)
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: _TextButton(label: 'Delete account', danger: true, onTap: () => _openForm(_Form.delete)),
                    ),
            ),
          ];

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  decoration: BoxDecoration(
                    color: ClerkColors.card,
                    borderRadius: BorderRadius.circular(ClerkColors.radius * 1.33),
                    border: Border.all(color: ClerkColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 45, offset: const Offset(0, 20))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Navbar (Clerk folds the side nav into a top bar on phones).
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                        color: Colors.white.withValues(alpha: 0.02),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                ),
                                Pressable(
                                  onTap: () => Navigator.of(context).pop(),
                                  semanticLabel: 'Close modal',
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(LucideIcons.x, size: 16, color: ClerkColors.muted),
                                  ),
                                ),
                              ],
                            ),
                            Text('Manage your account info.', style: TextStyle(fontSize: 13, color: ClerkColors.muted)),
                            const SizedBox(height: 12),
                            Row(
                              spacing: 4,
                              children: [
                                navItem(_Page.profile, LucideIcons.user, 'Profile'),
                                navItem(_Page.security, LucideIcons.shieldCheck, 'Security'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(height: 1, color: ClerkColors.border),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _page == _Page.profile ? 'Profile details' : 'Security',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 16),
                              Container(height: 1, color: ClerkColors.border),
                              ...sections,
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        color: Colors.white.withValues(alpha: 0.025),
                        child: const ClerkSecuredBy(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled block of the page, with a hairline under it.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.last = false});

  final String title;
  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: ClerkColors.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _MenuAction {
  const _MenuAction(this.label, this.onTap, {this.danger = false});

  final String label;
  final Future<void> Function() onTap;
  final bool danger;
}

/// One item (an email, a connected account, a device) with Clerk's "⋯" menu.
class _Row extends StatelessWidget {
  const _Row({required this.leading, this.badges = const [], this.actions = const []});

  final Widget leading;
  final List<Widget> badges;
  final List<_MenuAction> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        leading,
        for (final badge in badges) ...[const SizedBox(width: 8), badge],
        const Spacer(),
        if (actions.isNotEmpty)
          PopupMenuButton<_MenuAction>(
            tooltip: 'Open menu',
            color: const Color(0xFF1C1830),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: ClerkColors.border),
            ),
            icon: Icon(LucideIcons.ellipsis, size: 16, color: ClerkColors.muted),
            onSelected: (action) => _runGuarded(context, action.onTap),
            itemBuilder: (context) => [
              for (final action in actions)
                PopupMenuItem(
                  value: action,
                  height: 38,
                  child: Text(action.label, style: TextStyle(fontSize: 13, color: action.danger ? ClerkColors.danger : Colors.white)),
                ),
            ],
          ),
      ],
    ),
  );
}

/// Runs a Clerk call, showing its error (Clerk's own message) if it fails.
Future<void> _runGuarded(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } on ClerkException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message), backgroundColor: const Color(0xFF1C1830), behavior: SnackBarBehavior.floating));
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {this.danger = false});

  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: danger ? ClerkColors.danger.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: danger ? ClerkColors.danger.withValues(alpha: 0.3) : ClerkColors.border),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: danger ? ClerkColors.danger : ClerkColors.muted),
    ),
  );
}

/// Clerk's quiet text button ("Update profile", "Delete account").
class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onTap, this.danger = false});

  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: danger ? ClerkColors.danger : Colors.white),
      ),
    ),
  );
}

/// "+ Add email address" / "+ Connect account".
class _AddLink extends StatelessWidget {
  const _AddLink({required this.label, required this.onTap});

  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Pressable(
      onTap: () => _runGuarded(context, onTap),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.plus, size: 14, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}

/// Cancel / Save under an inline form.
class _FormButtons extends StatelessWidget {
  const _FormButtons({required this.onCancel, required this.onSave, this.saveLabel = 'Save', this.loading = false, this.danger = false});

  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final String saveLabel;
  final bool loading;
  final bool danger;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      _TextButton(label: 'Cancel', onTap: onCancel),
      const SizedBox(width: 8),
      Pressable(
        onTap: loading ? null : onSave,
        child: Opacity(
          opacity: onSave == null ? 0.5 : 1,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: danger ? const Color(0xFFEF4444) : Colors.white,
              borderRadius: BorderRadius.circular(ClerkColors.radius * 0.66),
            ),
            child: loading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: danger ? Colors.white : AppColors.onWhite),
                  )
                : Text(
                    saveLabel,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: danger ? Colors.white : AppColors.onWhite),
                  ),
          ),
        ),
      ),
    ],
  );
}

/// The card an inline form sits in.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(ClerkColors.radius),
      border: Border.all(color: ClerkColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ...children,
      ],
    ),
  );
}

/// "Update profile": picture (upload / remove) and first / last name.
class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.user, required this.onDone});

  final ClerkUser user;
  final VoidCallback onDone;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _first = TextEditingController(text: widget.user.firstName ?? '');
  late final _last = TextEditingController(text: widget.user.lastName ?? '');
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 90);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      await ref.read(authProvider.notifier).uploadProfileImage(await file.readAsBytes(), file.name);
      await ref.read(authProvider.notifier).reloadUser();
    } on ClerkException catch (error) {
      _error = error.message;
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).updateName(_first.text.trim(), _last.text.trim());
      widget.onDone();
    } on ClerkException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user ?? widget.user;
    return _FormCard(
      title: 'Update profile',
      children: [
        Row(
          children: [
            UserAvatar(user: user, size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _OutlinedButton(label: _uploading ? 'Uploading…' : 'Upload', onTap: _uploading ? null : _pickImage),
                      if (user.hasImage) ...[
                        const SizedBox(width: 4),
                        _TextButton(
                          label: 'Remove',
                          danger: true,
                          onTap: () => _runGuarded(context, ref.read(authProvider.notifier).removeProfileImage),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Recommended size 1:1, up to 10MB.', style: TextStyle(fontSize: 12, color: ClerkColors.muted)),
                ],
              ),
            ),
          ],
        ),
        ClerkTextField(label: 'First name', controller: _first, textInputAction: TextInputAction.next),
        ClerkTextField(label: 'Last name', controller: _last, onSubmitted: (_) => _save()),
        if (_error != null) ClerkFieldError(_error!),
        _FormButtons(onCancel: widget.onDone, onSave: _save, loading: _saving),
      ],
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ClerkColors.radius * 0.66),
        border: Border.all(color: ClerkColors.inputBorder),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ),
  );
}

class _AddEmailForm extends ConsumerStatefulWidget {
  const _AddEmailForm({required this.onCancel, required this.onAdded});

  final VoidCallback onCancel;
  final void Function(String id, String address) onAdded;

  @override
  ConsumerState<_AddEmailForm> createState() => _AddEmailFormState();
}

class _AddEmailFormState extends ConsumerState<_AddEmailForm> {
  final _email = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final address = _email.text.trim();
    if (address.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref.read(authProvider.notifier).addEmail(address);
      widget.onAdded(id, address);
    } on ClerkException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _FormCard(
    title: 'Add email address',
    children: [
      Text(
        "You'll need to verify this email address before it can be added to your account.",
        style: TextStyle(fontSize: 13, color: ClerkColors.muted),
      ),
      ClerkTextField(
        label: 'Email address',
        controller: _email,
        placeholder: 'Enter your email address',
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        error: _error,
        onSubmitted: (_) => _add(),
      ),
      _FormButtons(onCancel: widget.onCancel, onSave: _add, saveLabel: 'Add', loading: _saving),
    ],
  );
}

class _VerifyEmailForm extends ConsumerStatefulWidget {
  const _VerifyEmailForm({required this.emailId, required this.address, required this.onDone});

  final String emailId;
  final String address;
  final VoidCallback onDone;

  @override
  ConsumerState<_VerifyEmailForm> createState() => _VerifyEmailFormState();
}

class _VerifyEmailFormState extends ConsumerState<_VerifyEmailForm> {
  bool _verifying = false;
  String? _error;

  Future<void> _verify(String code) async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).verifyEmail(widget.emailId, code);
      widget.onDone();
    } on ClerkException catch (error) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _FormCard(
    title: 'Verify email address',
    children: [
      Text('Enter the verification code sent to ${widget.address}', style: TextStyle(fontSize: 13, color: ClerkColors.muted)),
      ClerkOtpField(onCompleted: _verify, error: _error, enabled: !_verifying),
      ClerkResendLink(onResend: () => ref.read(authProvider.notifier).resendEmailCode(widget.emailId)),
      _FormButtons(onCancel: widget.onDone, onSave: null, saveLabel: 'Verify', loading: _verifying),
    ],
  );
}

class _PasswordForm extends ConsumerStatefulWidget {
  const _PasswordForm({required this.hasPassword, required this.onDone});

  final bool hasPassword;
  final VoidCallback onDone;

  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _signOutOthers = true;
  bool _saving = false;
  String? _error;
  String? _confirmError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_next.text != _confirm.text) {
      setState(() => _confirmError = "Passwords don't match.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _confirmError = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .updatePassword(current: widget.hasPassword ? _current.text : null, next: _next.text, signOutOthers: _signOutOthers);
      widget.onDone();
    } on ClerkException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _FormCard(
    title: widget.hasPassword ? 'Update password' : 'Set password',
    children: [
      if (widget.hasPassword) ClerkTextField(label: 'Current password', controller: _current, obscure: true),
      ClerkTextField(label: 'New password', controller: _next, obscure: true),
      ClerkTextField(label: 'Confirm password', controller: _confirm, obscure: true, error: _confirmError),
      Pressable(
        pressedScale: 1,
        onTap: () => setState(() => _signOutOthers = !_signOutOthers),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _signOutOthers,
                onChanged: (value) => setState(() => _signOutOthers = value ?? false),
                activeColor: Colors.white,
                checkColor: AppColors.onWhite,
                side: BorderSide(color: ClerkColors.inputBorder),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sign out of all other devices', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(
                    'It is recommended to sign out of all other devices which may have used your old password.',
                    style: TextStyle(fontSize: 12, color: ClerkColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (_error != null) ClerkFieldError(_error!),
      _FormButtons(onCancel: widget.onDone, onSave: _save, loading: _saving),
    ],
  );
}

/// "Active devices": every signed-in session, this one marked, the others
/// with "Sign out of device".
class _ActiveDevices extends ConsumerStatefulWidget {
  const _ActiveDevices();

  @override
  ConsumerState<_ActiveDevices> createState() => _ActiveDevicesState();
}

class _ActiveDevicesState extends ConsumerState<_ActiveDevices> {
  List<ClerkDeviceSession>? _devices;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final devices = await ref.read(authProvider.notifier).activeDevices();
      if (mounted) setState(() => _devices = devices);
    } on ClerkException {
      if (mounted) setState(() => _devices = const []);
    }
  }

  String _ago(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} minutes ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final devices = _devices;
    if (devices == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        ),
      );
    }
    final current = ref.watch(authProvider).session?.id;
    final sorted = [...devices]..sort((a, b) => (a.id == current ? 0 : 1).compareTo(b.id == current ? 0 : 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final device in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                  child: Icon(device.isMobile ? LucideIcons.smartphone : LucideIcons.monitor, size: 18, color: ClerkColors.muted),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              device.deviceType ?? (device.isMobile ? 'Mobile device' : 'Desktop'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (device.id == current) ...[const SizedBox(width: 8), const _Badge('This device')],
                        ],
                      ),
                      if (device.browserName != null)
                        Text(
                          '${device.browserName} ${device.browserVersion ?? ''}'.trim(),
                          style: TextStyle(fontSize: 12, color: ClerkColors.muted),
                        ),
                      if (device.ipAddress != null)
                        Text(
                          [
                            device.ipAddress,
                            if (device.city != null || device.country != null)
                              '(${[device.city, device.country].whereType<String>().join(', ')})',
                          ].join(' '),
                          style: TextStyle(fontSize: 12, color: ClerkColors.muted),
                        ),
                      Text(_ago(device.lastActiveAt), style: TextStyle(fontSize: 12, color: ClerkColors.muted)),
                    ],
                  ),
                ),
                if (device.id != current)
                  PopupMenuButton<int>(
                    tooltip: 'Open menu',
                    color: const Color(0xFF1C1830),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: ClerkColors.border),
                    ),
                    icon: Icon(LucideIcons.ellipsis, size: 16, color: ClerkColors.muted),
                    onSelected: (_) => _runGuarded(context, () async {
                      await ref.read(authProvider.notifier).signOutDevice(device.id);
                      await _load();
                    }),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 0,
                        height: 38,
                        child: Text('Sign out of device', style: TextStyle(fontSize: 13, color: ClerkColors.danger)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DeleteForm extends ConsumerStatefulWidget {
  const _DeleteForm({required this.onCancel});

  final VoidCallback onCancel;

  @override
  ConsumerState<_DeleteForm> createState() => _DeleteFormState();
}

class _DeleteFormState extends ConsumerState<_DeleteForm> {
  static const _phrase = 'Delete account';
  final _confirm = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).deleteAccount();
    } on ClerkException catch (error) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _FormCard(
    title: 'Delete account',
    children: [
      Text(
        'Are you sure you want to delete your account? This action is permanent and irreversible.',
        style: TextStyle(fontSize: 13, color: ClerkColors.muted),
      ),
      ClerkTextField(label: 'Type "$_phrase" below to continue.', controller: _confirm, placeholder: _phrase, error: _error),
      ListenableBuilder(
        listenable: _confirm,
        builder: (context, _) => _FormButtons(
          onCancel: widget.onCancel,
          onSave: _confirm.text == _phrase ? _delete : null,
          saveLabel: 'Delete account',
          loading: _deleting,
          danger: true,
        ),
      ),
    ],
  );
}
