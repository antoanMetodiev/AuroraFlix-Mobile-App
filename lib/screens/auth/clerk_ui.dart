import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../widgets/pressable.dart';

/// Clerk's dark theme as the website configures it (ClerkLocalizedProvider):
/// `dark` base, primary white, background black, inputs white/6%, white
/// input text, 0.75rem radius, and the card itself painted
/// rgba(28,24,48,0.97) with a white/10 border.
abstract final class ClerkColors {
  static const card = Color.fromRGBO(28, 24, 48, 0.97);
  static const text = Colors.white;
  static final muted = Colors.white.withValues(alpha: 0.65);
  static final input = Colors.white.withValues(alpha: 0.06);
  static final inputBorder = Colors.white.withValues(alpha: 0.11);
  static final border = Colors.white.withValues(alpha: 0.1);
  static const danger = Color(0xFFF87171);
  static const radius = 12.0;
}

/// Clerk's base type size is 0.8125rem.
const double _base = 13;

class ClerkHeader extends StatelessWidget {
  const ClerkHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, height: 1.4, fontWeight: FontWeight.w700, color: ClerkColors.text),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: _base, height: 1.4, color: ClerkColors.muted),
          ),
        ],
      ],
    );
  }
}

/// White primary button with Clerk's little ▸ caret; shows a spinner while
/// [loading].
class ClerkPrimaryButton extends StatelessWidget {
  const ClerkPrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.caret = true});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool caret;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Pressable(
      onTap: enabled ? onPressed : null,
      pressedScale: 0.98,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled || loading ? 1 : 0.6,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ClerkColors.radius * 0.66),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2, offset: const Offset(0, 1))],
          ),
          child: loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onWhite))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onWhite),
                    ),
                    if (caret) ...[const SizedBox(width: 6), const Icon(Icons.play_arrow_rounded, size: 12, color: AppColors.onWhite)],
                  ],
                ),
        ),
      ),
    );
  }
}

const _googleLogo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path fill="#FFC107" d="M43.611 20.083H42V20H24v8h11.303c-1.649 4.657-6.08 8-11.303 8-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z"/><path fill="#FF3D00" d="m6.306 14.691 6.571 4.819C14.655 15.108 18.961 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 16.318 4 9.656 8.337 6.306 14.691z"/><path fill="#4CAF50" d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238A11.91 11.91 0 0 1 24 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z"/><path fill="#1976D2" d="M43.611 20.083H42V20H24v8h11.303a12.04 12.04 0 0 1-4.087 5.571l.003-.002 6.19 5.238C36.971 39.205 44 34 44 24c0-1.341-.138-2.65-.389-3.917z"/></svg>
''';

/// Google's "G", as on Clerk's buttons.
class ClerkGoogleLogo extends StatelessWidget {
  const ClerkGoogleLogo({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.string(_googleLogo, width: size, height: size);
}

/// "Continue with Google" — Clerk's block social button.
class ClerkGoogleButton extends StatelessWidget {
  const ClerkGoogleButton({super.key, required this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: loading ? null : onPressed,
      pressedScale: 0.98,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(ClerkColors.radius * 0.66),
          border: Border.all(color: ClerkColors.inputBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              SvgPicture.string(_googleLogo, width: 16, height: 16),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(fontSize: _base, fontWeight: FontWeight.w500, color: ClerkColors.text),
            ),
          ],
        ),
      ),
    );
  }
}

class ClerkDivider extends StatelessWidget {
  const ClerkDivider({super.key, this.label = 'or'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: 1, color: ClerkColors.border));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: TextStyle(fontSize: _base, color: ClerkColors.muted),
          ),
        ),
        line,
      ],
    );
  }
}

/// Label + input (+ error under it), Clerk's form field. [action] is the
/// small link at the label's right (e.g. "Forgot password?").
class ClerkTextField extends StatefulWidget {
  const ClerkTextField({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.optional = false,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.error,
    this.action,
    this.onSubmitted,
    this.autofocus = false,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final bool optional;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final String? error;
  final Widget? action;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputAction? textInputAction;

  @override
  State<ClerkTextField> createState() => _ClerkTextFieldState();
}

class _ClerkTextFieldState extends State<ClerkTextField> {
  final _focus = FocusNode();
  late bool _hidden = widget.obscure;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(fontSize: _base, fontWeight: FontWeight.w500, color: ClerkColors.text),
            ),
            const Spacer(),
            if (widget.optional) Text('Optional', style: TextStyle(fontSize: 12, color: ClerkColors.muted)),
            ?widget.action,
          ],
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: _focus,
          builder: (context, _) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 38,
            decoration: BoxDecoration(
              color: ClerkColors.input,
              borderRadius: BorderRadius.circular(ClerkColors.radius * 0.66),
              border: Border.all(
                color: hasError
                    ? ClerkColors.danger
                    : _focus.hasFocus
                    ? Colors.white.withValues(alpha: 0.5)
                    : ClerkColors.inputBorder,
              ),
              boxShadow: _focus.hasFocus
                  ? [BoxShadow(color: (hasError ? ClerkColors.danger : Colors.white).withValues(alpha: 0.18), spreadRadius: 3)]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    obscureText: _hidden,
                    keyboardType: widget.keyboardType,
                    autofillHints: widget.autofillHints,
                    textInputAction: widget.textInputAction,
                    onSubmitted: widget.onSubmitted,
                    cursorColor: Colors.white,
                    style: const TextStyle(fontSize: _base, color: Colors.white),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: widget.placeholder,
                      hintStyle: TextStyle(fontSize: _base, color: Colors.white.withValues(alpha: 0.35)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    ),
                  ),
                ),
                if (widget.obscure)
                  Pressable(
                    pressedScale: 1,
                    onTap: () => setState(() => _hidden = !_hidden),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(_hidden ? LucideIcons.eye : LucideIcons.eyeOff, size: 16, color: ClerkColors.muted),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ClerkFieldError(widget.error),
      ],
    );
  }
}

/// Red message with an alert icon under a field, sliding open.
class ClerkFieldError extends StatelessWidget {
  const ClerkFieldError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(LucideIcons.circleAlert, size: 14, color: ClerkColors.danger),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      message!,
                      style: const TextStyle(fontSize: _base, height: 1.35, color: ClerkColors.danger),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Small text link (Clerk's "Forgot password?", "Use another method").
class ClerkLink extends StatelessWidget {
  const ClerkLink({super.key, required this.label, required this.onTap, this.muted = false});

  final String label;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 1,
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: Text(
          label,
          style: TextStyle(
            fontSize: _base,
            fontWeight: FontWeight.w500,
            color: onTap == null ? ClerkColors.muted : (muted ? ClerkColors.muted : Colors.white),
          ),
        ),
      ),
    );
  }
}

/// The "who am I signing in as" pill under a header — email + edit pencil.
class ClerkIdentityPreview extends StatelessWidget {
  const ClerkIdentityPreview({super.key, required this.identifier, required this.onEdit});

  final String identifier;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ClerkColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                identifier,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: _base, color: ClerkColors.text),
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              pressedScale: 1,
              onTap: onEdit,
              child: Icon(LucideIcons.pencil, size: 13, color: ClerkColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Six-box one-time-code input. Submits by itself once all six digits are in.
class ClerkOtpField extends StatefulWidget {
  const ClerkOtpField({super.key, required this.onCompleted, this.error, this.enabled = true});

  final ValueChanged<String> onCompleted;
  final String? error;
  final bool enabled;

  @override
  State<ClerkOtpField> createState() => ClerkOtpFieldState();
}

class ClerkOtpFieldState extends State<ClerkOtpField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  void clear() {
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const length = 6;
    return Column(
      children: [
        GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: Stack(
            children: [
              // The real (invisible) input — the boxes just draw its value.
              Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: length,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      setState(() {});
                      if (value.length == length) widget.onCompleted(value);
                    },
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                  ),
                ),
              ),
              IgnorePointer(
                child: ListenableBuilder(
                  listenable: _focus,
                  builder: (context, _) {
                    final value = _controller.text;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < length; i++)
                          Container(
                            width: 40,
                            height: 44,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ClerkColors.input,
                              borderRadius: BorderRadius.circular(ClerkColors.radius * 0.66),
                              border: Border.all(
                                color: widget.error != null
                                    ? ClerkColors.danger
                                    : (_focus.hasFocus && i == value.length.clamp(0, length - 1))
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : ClerkColors.inputBorder,
                              ),
                            ),
                            child: Text(
                              i < value.length ? value[i] : '',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        ClerkFieldError(widget.error),
      ],
    );
  }
}

/// "Didn't receive a code? Resend (30)" — the count runs down before it can
/// be pressed again.
class ClerkResendLink extends StatefulWidget {
  const ClerkResendLink({super.key, required this.onResend});

  final Future<void> Function() onResend;

  @override
  State<ClerkResendLink> createState() => _ClerkResendLinkState();
}

class _ClerkResendLinkState extends State<ClerkResendLink> {
  static const _cooldown = 30;
  int _remaining = _cooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    setState(() => _remaining = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) timer.cancel();
      setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _remaining > 0;
    return Center(
      child: ClerkLink(
        label: "Didn't receive a code? Resend${waiting ? ' ($_remaining)' : ''}",
        muted: true,
        onTap: waiting
            ? null
            : () async {
                await widget.onResend();
                _start();
              },
      ),
    );
  }
}

/// Footer under the card: the switch line ("Don't have an account? Sign up")
/// and Clerk's "Secured by clerk" badge.
class ClerkFooter extends StatelessWidget {
  const ClerkFooter({super.key, this.prompt, this.actionLabel, this.onAction});

  final String? prompt;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        border: Border(top: BorderSide(color: ClerkColors.border)),
      ),
      child: Column(
        children: [
          if (prompt != null) ...[
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                Text(
                  '$prompt ',
                  style: TextStyle(fontSize: _base, color: ClerkColors.muted),
                ),
                ClerkLink(label: actionLabel!, onTap: onAction),
              ],
            ),
            const SizedBox(height: 14),
          ],
          const ClerkSecuredBy(),
        ],
      ),
    );
  }
}

class ClerkSecuredBy extends StatelessWidget {
  const ClerkSecuredBy({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: 0.6);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Secured by ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
        ),
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.2),
          ),
        ),
        const SizedBox(width: 2),
        Text(
          'clerk',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: color),
        ),
      ],
    );
  }
}
