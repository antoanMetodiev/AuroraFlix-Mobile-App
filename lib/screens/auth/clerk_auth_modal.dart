import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/clerk_api.dart';
import '../../core/auth/clerk_models.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import 'clerk_ui.dart';

enum ClerkAuthMode { signIn, signUp }

/// Opens Clerk's sign-in / sign-up as a modal over the current screen — the
/// website's `<SignInButton mode="modal">` / `<SignUpButton mode="modal">`.
/// Closes by itself once the person is signed in.
Future<void> showClerkAuthModal(BuildContext context, ClerkAuthMode mode) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => _ClerkAuthModal(initialMode: mode),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
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
}

enum _Page {
  signInStart,
  signInPassword,
  signInCode,
  signInAlternatives,
  forgotPassword,
  resetPasswordCode,
  newPassword,
  secondFactorCode,
  signUpStart,
  signUpVerify,
}

class _ClerkAuthModal extends ConsumerStatefulWidget {
  const _ClerkAuthModal({required this.initialMode});

  final ClerkAuthMode initialMode;

  @override
  ConsumerState<_ClerkAuthModal> createState() => _ClerkAuthModalState();
}

class _ClerkAuthModalState extends ConsumerState<_ClerkAuthModal> {
  late _Page _page = widget.initialMode == ClerkAuthMode.signIn ? _Page.signInStart : _Page.signUpStart;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otpKey = GlobalKey<ClerkOtpFieldState>();

  ClerkSignIn? _signIn;
  ClerkSignUp? _signUp;
  bool _busy = false;
  bool _googleBusy = false;
  bool _signOutOthers = true;

  /// Errors keyed by the field they belong to (`email`, `password`, `code`,
  /// `firstName`, `newPassword`, `confirm`), or `form` for the rest.
  Map<String, String> _errors = const {};

  AuthController get _auth => ref.read(authProvider.notifier);

  @override
  void dispose() {
    for (final controller in [_email, _password, _firstName, _lastName, _newPassword, _confirmPassword]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _go(_Page page) => setState(() {
    _page = page;
    _errors = const {};
  });

  /// Runs one Clerk step with the busy spinner, mapping its error onto the
  /// field Clerk says it's about.
  Future<void> _run(Future<void> Function() step, {String fallbackField = 'form'}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errors = const {};
    });
    try {
      await step();
    } on ClerkException catch (error) {
      if (!mounted) return;
      setState(() => _errors = {_fieldFor(error.paramName) ?? fallbackField: error.message});
      if (fallbackField == 'code') _otpKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _fieldFor(String? param) => switch (param) {
    'identifier' || 'email_address' => 'email',
    'password' => _page == _Page.newPassword ? 'newPassword' : 'password',
    'code' => 'code',
    'first_name' => 'firstName',
    'last_name' => 'lastName',
    _ => null,
  };

  void _closeIfSignedIn() {
    if (ref.read(authProvider).isSignedIn && mounted) Navigator.of(context).pop();
  }

  // --- Sign in ---------------------------------------------------------------

  Future<void> _submitIdentifier() => _run(() async {
    final signIn = await _auth.startSignIn(_email.text.trim());
    _signIn = signIn;
    _routeSignIn(signIn);
  }, fallbackField: 'email');

  /// Same choice Clerk makes: password first when the account has one,
  /// otherwise an emailed code.
  void _routeSignIn(ClerkSignIn signIn) {
    if (signIn.status == 'complete') return _closeIfSignedIn();
    if (signIn.status == 'needs_second_factor' || signIn.status == 'needs_client_trust') {
      _startSecondFactor(signIn);
      return;
    }
    if (signIn.firstFactor('password') != null) return _go(_Page.signInPassword);
    final emailCode = signIn.firstFactor('email_code');
    if (emailCode != null) _sendSignInCode(emailCode);
  }

  Future<void> _submitPassword() => _run(() async {
    final signIn = await _auth.attemptPassword(_signIn!.id, _password.text);
    _signIn = signIn;
    _routeSignIn(signIn);
  }, fallbackField: 'password');

  void _sendSignInCode(ClerkFactor factor) => _run(() async {
    _signIn = await _auth.prepareFirstFactor(_signIn!.id, factor);
    _go(_Page.signInCode);
  });

  Future<void> _submitSignInCode(String code) => _run(() async {
    final signIn = await _auth.attemptFirstFactorCode(_signIn!.id, 'email_code', code);
    _signIn = signIn;
    _routeSignIn(signIn);
  }, fallbackField: 'code');

  void _startSecondFactor(ClerkSignIn signIn) {
    final factor = signIn.secondFactor('email_code');
    if (factor == null) {
      setState(() => _errors = {'form': 'This account needs a verification method the app does not support yet.'});
      return;
    }
    _run(() async {
      _signIn = await _auth.prepareSecondFactor(signIn.id, factor);
      _go(_Page.secondFactorCode);
    });
  }

  Future<void> _submitSecondFactorCode(String code) => _run(() async {
    final signIn = await _auth.attemptSecondFactorCode(_signIn!.id, 'email_code', code);
    _signIn = signIn;
    _routeSignIn(signIn);
  }, fallbackField: 'code');

  // --- Forgot password -------------------------------------------------------

  void _sendResetCode() {
    final factor = _signIn?.firstFactor('reset_password_email_code');
    if (factor == null) return;
    _run(() async {
      _signIn = await _auth.prepareFirstFactor(_signIn!.id, factor);
      _go(_Page.resetPasswordCode);
    });
  }

  Future<void> _submitResetCode(String code) => _run(() async {
    final signIn = await _auth.attemptFirstFactorCode(_signIn!.id, 'reset_password_email_code', code);
    _signIn = signIn;
    if (signIn.status == 'needs_new_password') _go(_Page.newPassword);
  }, fallbackField: 'code');

  Future<void> _submitNewPassword() {
    if (_newPassword.text != _confirmPassword.text) {
      setState(() => _errors = {'confirm': "Passwords don't match."});
      return Future.value();
    }
    return _run(() async {
      final signIn = await _auth.resetPassword(_signIn!.id, _newPassword.text, signOutOfOtherSessions: _signOutOthers);
      _signIn = signIn;
      _routeSignIn(signIn);
    }, fallbackField: 'newPassword');
  }

  // --- Sign up ---------------------------------------------------------------

  Future<void> _submitSignUp() => _run(() async {
    var signUp = await _auth.startSignUp(
      email: _email.text.trim(),
      password: _password.text,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
    );
    if (signUp.unverifiedFields.contains('email_address')) {
      signUp = await _auth.prepareEmailVerification(signUp.id);
      _signUp = signUp;
      _go(_Page.signUpVerify);
    } else {
      _signUp = signUp;
      _closeIfSignedIn();
    }
  });

  Future<void> _submitSignUpCode(String code) => _run(() async {
    _signUp = await _auth.attemptEmailVerification(_signUp!.id, code);
    _closeIfSignedIn();
  }, fallbackField: 'code');

  // --- Google ----------------------------------------------------------------

  Future<void> _google() async {
    if (_googleBusy) return;
    setState(() {
      _googleBusy = true;
      _errors = const {};
    });
    try {
      await _auth.signInWithGoogle();
      _closeIfSignedIn();
    } on ClerkException catch (error) {
      if (mounted) setState(() => _errors = {'form': error.message});
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
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
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: auroraEase,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(key: ValueKey(_page), child: _buildPage()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One Clerk card: header, body, then the footer strip.
  Widget _card({
    required String title,
    String? subtitle,
    Widget? identity,
    required List<Widget> body,
    ClerkFooter footer = const ClerkFooter(),
    VoidCallback? onBack,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClerkHeader(title: title, subtitle: subtitle),
                  if (identity != null) ...[const SizedBox(height: 12), identity],
                  const SizedBox(height: 28),
                  ...body,
                  ClerkFieldError(_errors['form']),
                  if (onBack != null) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: ClerkLink(label: 'Back', muted: true, onTap: onBack),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(LucideIcons.x, size: 16, color: ClerkColors.muted),
                tooltip: 'Close',
              ),
            ),
          ],
        ),
        footer,
      ],
    );
  }

  Widget get _identity => ClerkIdentityPreview(
    identifier: _signIn?.identifier ?? _signUp?.emailAddress ?? _email.text.trim(),
    onEdit: () {
      _password.clear();
      _go(_page == _Page.signUpVerify ? _Page.signUpStart : _Page.signInStart);
    },
  );

  Widget _buildPage() {
    switch (_page) {
      case _Page.signInStart:
        return _card(
          title: 'Sign in to $clerkApplicationName',
          subtitle: 'Welcome back! Please sign in to continue',
          body: [
            ClerkGoogleButton(onPressed: _google, loading: _googleBusy),
            const SizedBox(height: 24),
            const ClerkDivider(),
            const SizedBox(height: 24),
            ClerkTextField(
              label: 'Email address',
              placeholder: 'Enter your email address',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              error: _errors['email'],
              onSubmitted: (_) => _submitIdentifier(),
            ),
            const SizedBox(height: 24),
            ClerkPrimaryButton(label: 'Continue', loading: _busy, onPressed: _submitIdentifier),
          ],
          footer: ClerkFooter(prompt: 'Don’t have an account?', actionLabel: 'Sign up', onAction: () => _go(_Page.signUpStart)),
        );

      case _Page.signInPassword:
        return _card(
          title: 'Enter your password',
          subtitle: 'Enter the password associated with your account',
          identity: _identity,
          body: [
            ClerkTextField(
              label: 'Password',
              placeholder: 'Enter your password',
              controller: _password,
              obscure: true,
              autofocus: true,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              error: _errors['password'],
              onSubmitted: (_) => _submitPassword(),
              action: _signIn?.firstFactor('reset_password_email_code') != null
                  ? ClerkLink(label: 'Forgot password?', onTap: () => _go(_Page.forgotPassword))
                  : null,
            ),
            const SizedBox(height: 24),
            ClerkPrimaryButton(label: 'Continue', loading: _busy, onPressed: _submitPassword),
            const SizedBox(height: 20),
            Center(
              child: ClerkLink(label: 'Use another method', muted: true, onTap: () => _go(_Page.signInAlternatives)),
            ),
          ],
        );

      case _Page.signInAlternatives:
        final emailCode = _signIn?.firstFactor('email_code');
        return _card(
          title: 'Use another method',
          subtitle: 'Facing issues? You can use any of these methods to sign in.',
          body: [
            if (emailCode != null)
              _BlockButton(
                icon: LucideIcons.mail,
                label: 'Email code to ${emailCode.safeIdentifier ?? _signIn?.identifier ?? ''}',
                onTap: () => _sendSignInCode(emailCode),
              ),
            if (_signIn?.firstFactor('password') != null) ...[
              const SizedBox(height: 8),
              _BlockButton(icon: LucideIcons.lock, label: 'Sign in with your password', onTap: () => _go(_Page.signInPassword)),
            ],
          ],
          onBack: () => _go(_Page.signInPassword),
        );

      case _Page.signInCode:
        return _codeCard(
          title: 'Check your email',
          subtitle: 'to continue to $clerkApplicationName',
          onCompleted: _submitSignInCode,
          onResend: () async {
            final factor = _signIn?.firstFactor('email_code');
            if (factor != null) _signIn = await _auth.prepareFirstFactor(_signIn!.id, factor);
          },
          onBack: () => _go(_Page.signInAlternatives),
        );

      case _Page.secondFactorCode:
        return _codeCard(
          title: 'Check your email',
          subtitle: 'to continue to $clerkApplicationName',
          onCompleted: _submitSecondFactorCode,
          onResend: () async {
            final factor = _signIn?.secondFactor('email_code');
            if (factor != null) _signIn = await _auth.prepareSecondFactor(_signIn!.id, factor);
          },
        );

      case _Page.forgotPassword:
        final emailCode = _signIn?.firstFactor('email_code');
        return _card(
          title: 'Forgot Password?',
          body: [
            ClerkPrimaryButton(label: 'Reset your password', caret: false, loading: _busy, onPressed: _sendResetCode),
            if (emailCode != null) ...[
              const SizedBox(height: 24),
              const ClerkDivider(label: 'Or, sign in with another method'),
              const SizedBox(height: 24),
              _BlockButton(
                icon: LucideIcons.mail,
                label: 'Email code to ${emailCode.safeIdentifier ?? _signIn?.identifier ?? ''}',
                onTap: () => _sendSignInCode(emailCode),
              ),
            ],
          ],
          onBack: () => _go(_Page.signInPassword),
        );

      case _Page.resetPasswordCode:
        return _codeCard(
          title: 'Reset password',
          subtitle: 'to reset your password',
          formTitle: 'Reset password code',
          onCompleted: _submitResetCode,
          onResend: () async {
            final factor = _signIn?.firstFactor('reset_password_email_code');
            if (factor != null) _signIn = await _auth.prepareFirstFactor(_signIn!.id, factor);
          },
          onBack: () => _go(_Page.forgotPassword),
        );

      case _Page.newPassword:
        return _card(
          title: 'Set new password',
          body: [
            ClerkTextField(
              label: 'New password',
              controller: _newPassword,
              obscure: true,
              autofocus: true,
              autofillHints: const [AutofillHints.newPassword],
              error: _errors['newPassword'],
            ),
            const SizedBox(height: 24),
            ClerkTextField(
              label: 'Confirm password',
              controller: _confirmPassword,
              obscure: true,
              autofillHints: const [AutofillHints.newPassword],
              error: _errors['confirm'],
              onSubmitted: (_) => _submitNewPassword(),
            ),
            const SizedBox(height: 20),
            _Checkbox(
              value: _signOutOthers,
              label: 'Sign out of all other devices',
              onChanged: (value) => setState(() => _signOutOthers = value),
            ),
            const SizedBox(height: 24),
            ClerkPrimaryButton(label: 'Reset Password', caret: false, loading: _busy, onPressed: _submitNewPassword),
          ],
        );

      case _Page.signUpStart:
        return _card(
          title: 'Create your account',
          subtitle: 'Welcome! Please fill in the details to get started.',
          body: [
            ClerkGoogleButton(onPressed: _google, loading: _googleBusy),
            const SizedBox(height: 24),
            const ClerkDivider(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClerkTextField(
                    label: 'First name',
                    placeholder: 'First name',
                    optional: true,
                    controller: _firstName,
                    autofillHints: const [AutofillHints.givenName],
                    textInputAction: TextInputAction.next,
                    error: _errors['firstName'],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ClerkTextField(
                    label: 'Last name',
                    placeholder: 'Last name',
                    optional: true,
                    controller: _lastName,
                    autofillHints: const [AutofillHints.familyName],
                    textInputAction: TextInputAction.next,
                    error: _errors['lastName'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ClerkTextField(
              label: 'Email address',
              placeholder: 'Enter your email address',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              error: _errors['email'],
            ),
            const SizedBox(height: 24),
            ClerkTextField(
              label: 'Password',
              placeholder: 'Enter your password',
              controller: _password,
              obscure: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              error: _errors['password'],
              onSubmitted: (_) => _submitSignUp(),
            ),
            const SizedBox(height: 24),
            ClerkPrimaryButton(label: 'Continue', loading: _busy, onPressed: _submitSignUp),
          ],
          footer: ClerkFooter(prompt: 'Already have an account?', actionLabel: 'Sign in', onAction: () => _go(_Page.signInStart)),
        );

      case _Page.signUpVerify:
        return _codeCard(
          title: 'Verify your email',
          subtitle: 'Enter the verification code sent to your email',
          onCompleted: _submitSignUpCode,
          onResend: () async => _signUp = await _auth.prepareEmailVerification(_signUp!.id),
          footer: ClerkFooter(prompt: 'Already have an account?', actionLabel: 'Sign in', onAction: () => _go(_Page.signInStart)),
        );
    }
  }

  Widget _codeCard({
    required String title,
    required String subtitle,
    String formTitle = 'Verification code',
    required ValueChanged<String> onCompleted,
    required Future<void> Function() onResend,
    VoidCallback? onBack,
    ClerkFooter footer = const ClerkFooter(),
  }) {
    return _card(
      title: title,
      subtitle: subtitle,
      identity: _identity,
      body: [
        Text(
          formTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        const SizedBox(height: 12),
        ClerkOtpField(key: _otpKey, onCompleted: onCompleted, error: _errors['code'], enabled: !_busy),
        const SizedBox(height: 16),
        ClerkResendLink(onResend: onResend),
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          ),
        ],
      ],
      onBack: onBack,
      footer: footer,
    );
  }
}

/// Full-width outlined choice button ("Email code to …").
class _BlockButton extends StatelessWidget {
  const _BlockButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(ClerkColors.radius * 0.66),
          border: Border.all(color: ClerkColors.inputBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: ClerkColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.value, required this.label, required this.onChanged});

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: value ? Colors.white : ClerkColors.input,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: value ? Colors.white : ClerkColors.inputBorder),
            ),
            child: value ? const Icon(LucideIcons.check, size: 12, color: AppColors.onWhite) : null,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.white)),
        ],
      ),
    );
  }
}
