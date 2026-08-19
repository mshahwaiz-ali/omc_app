import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/auth_repository.dart';
import 'auth_entry_widgets.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = true;
  bool _completing = false;
  bool _tokenValid = false;
  bool _activated = false;
  bool _canRetry = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _message = 'Checking your verification link...';

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_inspectToken);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _responseData(Map<String, dynamic> response) {
    final raw = response['message'];
    return raw is Map<String, dynamic> ? raw : response;
  }

  bool _isTrue(Object? value) {
    return value == true ||
        value == 1 ||
        value?.toString().toLowerCase() == 'true';
  }

  Future<void> _inspectToken() async {
    final token = widget.token.trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _tokenValid = false;
        _canRetry = false;
        _message = 'This verification link is invalid or has expired.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _tokenValid = false;
      _canRetry = false;
      _message = 'Checking your verification link...';
    });

    try {
      final response = await ref
          .read(authRepositoryProvider)
          .getRegistrationVerificationStatus(token: token);
      final data = _responseData(response);
      final status = data['status']?.toString().trim().toLowerCase() ?? '';
      final valid = _isTrue(data['ok']) && status == 'awaiting_password';

      if (!mounted) return;
      setState(() {
        _loading = false;
        _tokenValid = valid;
        _activated = false;
        _canRetry = false;
        _message = valid
            ? 'Email verified. Set a password to finish creating your account.'
            : (data['message']?.toString().trim().isNotEmpty == true
                  ? data['message'].toString().trim()
                  : 'This verification link is invalid or has expired.');
      });
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Verification failed',
        fallbackMessage:
            'The verification link could not be checked. Please try again.',
      );
      setState(() {
        _loading = false;
        _tokenValid = false;
        _canRetry = true;
        _message = failure.message;
      });
    }
  }

  Future<void> _completeRegistration() async {
    if (_completing || !_tokenValid) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _completing = true;
      _canRetry = false;
    });

    try {
      final response = await ref.read(authRepositoryProvider).completeRegistration(
            token: widget.token.trim(),
            password: _passwordController.text,
          );
      final data = _responseData(response);
      final status = data['status']?.toString().trim().toLowerCase() ?? '';
      final activated = _isTrue(data['ok']) && status == 'activated';

      if (!mounted) return;
      setState(() {
        _completing = false;
        _activated = activated;
        _tokenValid = !activated && status == 'awaiting_password';
        _canRetry = !activated && !_tokenValid;
        _message = data['message']?.toString().trim().isNotEmpty == true
            ? data['message'].toString().trim()
            : activated
            ? 'Your account is ready. You can sign in now.'
            : 'This verification link is invalid or has expired.';
      });
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Account setup failed',
        fallbackMessage:
            'Your account could not be completed. Check the password and try again.',
      );
      setState(() {
        _completing = false;
        _message = failure.message;
      });
    }
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (password.length > 128) {
      return 'Password must be 128 characters or fewer.';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if ((value ?? '') != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = _activated
        ? 'Account ready'
        : _tokenValid
        ? 'Set your password'
        : 'Verify your email';
    final subtitle = _activated
        ? 'Your OMC account is ready for sign in.'
        : _tokenValid
        ? 'Your email is verified. Complete account setup securely.'
        : 'We are checking the security link from your email.';

    return AuthEntryScaffold(
      title: title,
      subtitle: subtitle,
      child: PremiumCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Icon(
                _activated
                    ? Icons.verified_user_outlined
                    : _tokenValid
                    ? Icons.mark_email_read_outlined
                    : Icons.link_off_rounded,
                size: 44,
                color: _activated || _tokenValid
                    ? const Color(0xFF15803D)
                    : AppTheme.textSecondary,
              ),
              const SizedBox(height: 18),
              Text(
                _message,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_tokenValid && !_activated) ...[
                const SizedBox(height: 22),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        validator: _validatePassword,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        validator: _validateConfirmation,
                        onFieldSubmitted: (_) => _completeRegistration(),
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppButton(
                  label: _completing ? 'Creating account...' : 'Create Account',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: _completing ? null : _completeRegistration,
                ),
              ],
              const SizedBox(height: 22),
              if (_canRetry) ...[
                AppButton(
                  label: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onPressed: _inspectToken,
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login_rounded),
                label: Text(_activated ? 'Continue to Login' : 'Back to Login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
