import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import 'data/account_sync.dart';
import 'data/auth_repository.dart';

/// Email sign-in in two steps on one screen: ask for a code, then enter it.
/// The same flow creates the account on first use.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  /// How long before another code can be requested. Matches the server's own
  /// limit, so the button never offers a resend that would be refused.
  static const resendCooldown = Duration(seconds: 60);

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  /// Set once a code has been sent; switches the screen to the code step.
  String? _sentTo;
  bool _busy = false;
  String? _error;

  Timer? _cooldownTimer;
  int _cooldownLeft = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _emailValid => _emailPattern.hasMatch(_emailController.text.trim());

  /// Supabase sends 6 digits by default; up to 10 if the project is changed.
  bool get _codeValid => RegExp(r'^\d{6,10}$').hasMatch(_codeController.text);

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = SignInScreen.resendCooldown.inSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldownLeft--);
      if (_cooldownLeft <= 0) timer.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
        final email = _emailController.text.trim();
        await ref.read(authRepositoryProvider).sendCode(email);
        if (!mounted) return;
        setState(() => _sentTo = email);
        _codeController.clear();
        _startCooldown();
      });

  Future<void> _verify() => _run(() async {
        final user = await ref.read(authRepositoryProvider).verifyCode(
              email: _sentTo!,
              code: _codeController.text,
            );
        final hasProfile = await ref.read(accountSyncProvider).signedIn(user);
        if (!mounted) return;
        context.go(hasProfile ? AppRoutes.today : AppRoutes.onboarding);
      });

  void _changeEmail() {
    _cooldownTimer?.cancel();
    setState(() {
      _sentTo = null;
      _error = null;
      _cooldownLeft = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.lg,
          ),
          child: sentTo == null ? _emailStep() : _codeStep(sentTo),
        ),
      ),
    );
  }

  Widget _emailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Continue with email', style: AppTypography.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'We will email you a code to sign in. No password needed.',
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _emailController,
          autofocus: true,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          textInputAction: TextInputAction.send,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_emailValid && !_busy) _sendCode();
          },
          decoration: const InputDecoration(
            hintText: 'you@example.com',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        _ErrorText(_error),
        const SizedBox(height: AppSpacing.lg),
        _PrimaryButton(
          label: 'Send code',
          busy: _busy,
          onPressed: _emailValid ? _sendCode : null,
        ),
      ],
    );
  }

  Widget _codeStep(String sentTo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Check your email', style: AppTypography.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        Text.rich(
          TextSpan(
            text: 'Enter the code we sent to ',
            style: AppTypography.bodyMedium,
            children: [
              TextSpan(
                text: sentTo,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textPrimary),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _codeController,
          autofocus: true,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          textInputAction: TextInputAction.done,
          style: AppTypography.headlineMedium.copyWith(letterSpacing: 6),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_codeValid && !_busy) _verify();
          },
          decoration: const InputDecoration(hintText: '123456'),
        ),
        _ErrorText(_error),
        const SizedBox(height: AppSpacing.lg),
        _PrimaryButton(
          label: 'Sign in',
          busy: _busy,
          onPressed: _codeValid ? _verify : null,
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: _busy || _cooldownLeft > 0 ? null : _sendCode,
          child: Text(
            _cooldownLeft > 0
                ? 'Resend code in ${_cooldownLeft}s'
                : 'Resend code',
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _changeEmail,
          child: const Text('Use a different email'),
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        message,
        style: AppTypography.bodySmall.copyWith(color: AppColors.error),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Text(label),
    );
  }
}
