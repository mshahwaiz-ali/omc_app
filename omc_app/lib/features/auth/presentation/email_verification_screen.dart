import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
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
      final response = await ref
          .read(authRepositoryProvider)
          .completeRegistration(
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
        _canRetry = false;
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
    final theme = Theme.of(context);
    final title = _activated
        ? 'Account ready'
        : _tokenValid
        ? 'Set your password'
        : 'Verify your email';
    final subtitle = _activated
        ? 'Your OMC account is ready for sign in.'
        : _tokenValid
        ? 'Your email is verified. Complete account setup securely.'
        : _loading
        ? 'Checking the security link from your email.'
        : _canRetry
        ? 'The verification link could not be checked right now.'
        : 'This verification link is not available for account completion.';

    return AuthEntryScaffold(
      title: title,
      subtitle: subtitle,
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              Semantics(
                liveRegion: true,
                label: 'Checking verification link',
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else ...[
              Semantics(
                container: true,
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      _activated
                          ? Icons.verified_user_outlined
                          : _tokenValid
                          ? Icons.mark_email_read_outlined
                          : _canRetry
                          ? Icons.cloud_off_outlined
                          : Icons.link_off_rounded,
                      size: 40,
                      color: _activated
                          ? AppTheme.success
                          : _tokenValid
                          ? AppTheme.info
                          : _canRetry
                          ? AppTheme.warning
                          : AppTheme.danger,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _activated
                          ? 'Account creation complete'
                          : _tokenValid
                          ? 'Email verification complete'
                          : _canRetry
                          ? 'Verification check unavailable'
                          : 'Verification link unavailable',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_message, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
              if (_tokenValid && !_activated) ...[
                const SizedBox(height: AppSpacing.xl),
                Text('Create your password', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Use 8–128 characters and enter the same password in both fields.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('New password', style: theme.textTheme.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        validator: _validatePassword,
                        decoration: InputDecoration(
                          hintText: 'Enter a new password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
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
                      const SizedBox(height: AppSpacing.md),
                      Text('Confirm password', style: theme.textTheme.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        validator: _validateConfirmation,
                        onFieldSubmitted: (_) => _completeRegistration(),
                        decoration: InputDecoration(
                          hintText: 'Re-enter the new password',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirmPassword
                                ? 'Show password'
                                : 'Hide password',
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
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Create account',
                  icon: Icons.person_add_alt_1_rounded,
                  isLoading: _completing,
                  onPressed: _completing ? null : _completeRegistration,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (_canRetry) ...[
                AppButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: _inspectToken,
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              OutlinedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login_rounded),
                label: Text(_activated ? 'Continue to login' : 'Back to login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
