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

class CompleteCustomerActivationScreen extends ConsumerStatefulWidget {
  const CompleteCustomerActivationScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<CompleteCustomerActivationScreen> createState() =>
      _CompleteCustomerActivationScreenState();
}

class _CompleteCustomerActivationScreenState
    extends ConsumerState<CompleteCustomerActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  bool _completed = false;
  bool _linkInvalid = false;
  bool _reviewRequired = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _message;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = widget.token.trim();
    if (token.isEmpty) {
      setState(() {
        _message = 'This activation link is invalid or has expired.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      final response = await ref
          .read(authRepositoryProvider)
          .completeCustomerActivation(
            token: token,
            password: _passwordController.text,
            confirmPassword: _confirmController.text,
          );

      final raw = response['message'];
      final data = raw is Map<String, dynamic> ? raw : response;
      final ok =
          data['ok'] == true ||
          data['ok'] == 1 ||
          data['ok']?.toString().toLowerCase() == 'true';
      final status = data['status']?.toString().trim() ?? '';

      if (!mounted) return;

      setState(() {
        _completed = ok;
        _linkInvalid = !ok && status == 'invalid_or_expired';
        _reviewRequired = !ok && status == 'review_required';
        _message = data['message']?.toString().trim().isNotEmpty == true
            ? data['message'].toString().trim()
            : ok
            ? 'Your OMC account is activated. You can sign in now.'
            : _reviewRequired
            ? 'This account requires OMC review before app access can be activated.'
            : 'This activation link is invalid or has expired.';
      });
    } catch (error) {
      if (!mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Account not activated',
        fallbackMessage:
            'Your account could not be activated. Check the link and try again.',
      );

      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasToken = widget.token.trim().isNotEmpty;
    final theme = Theme.of(context);

    if (!hasToken || _linkInvalid) {
      return AuthEntryScaffold(
        title: 'Invalid activation link',
        subtitle: !hasToken
            ? 'This account activation link is missing or no longer valid.'
            : 'This account activation link is invalid or has expired.',
        leading: IconButton(
          tooltip: 'Back to login',
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        child: PremiumCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Semantics(
            container: true,
            liveRegion: _linkInvalid,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.link_off_rounded,
                  color: AppTheme.danger,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Request a new account activation link',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _linkInvalid && _message?.trim().isNotEmpty == true
                      ? _message!
                      : 'Request a new account activation email to continue securely.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Request new link',
                  icon: Icons.outgoing_mail,
                  onPressed: () => context.go('/activate-existing-account'),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Back to login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_reviewRequired) {
      return AuthEntryScaffold(
        title: 'Account review required',
        subtitle:
            'OMC needs to review this existing customer account before app access can be activated.',
        leading: IconButton(
          tooltip: 'Back to login',
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        child: PremiumCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.manage_accounts_outlined,
                  color: AppTheme.warning,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'OMC review is required',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _message ??
                      'This account requires OMC review before app access can be activated.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'This is an account-access review. It does not change any service request, payment, document, or settlement status.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Back to login',
                  icon: Icons.login_rounded,
                  onPressed: () => context.go('/login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AuthEntryScaffold(
      title: _completed ? 'Account activated' : 'Create your account password',
      subtitle: _completed
          ? 'Your existing OMC customer record is now linked to app access.'
          : 'Choose a secure password to finish activating access to your OMC account.',
      leading: IconButton(
        tooltip: 'Back to login',
        onPressed: _submitting ? null : () => context.go('/login'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _completed
            ? Semantics(
                container: true,
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppTheme.success,
                      size: 40,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'App account access is ready',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _message ??
                          'Your OMC account is activated. You can sign in now.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Continue to login',
                      icon: Icons.login_rounded,
                      onPressed: () => context.go('/login'),
                    ),
                  ],
                ),
              )
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Set your password', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Use at least 8 characters. This password is for signing in to your OMC account.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Password', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        hintText: 'Enter a new password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: _passwordValidator,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Confirm password', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: 'Re-enter the new password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirm
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(() => _obscureConfirm = !_obscureConfirm);
                          },
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final required = _passwordValidator(value);
                        if (required != null) return required;

                        if (value != _passwordController.text) {
                          return 'Passwords do not match.';
                        }

                        return null;
                      },
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AuthErrorBanner(message: _message!),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Activate account access',
                      icon: Icons.verified_user_outlined,
                      isLoading: _submitting,
                      onPressed: _submitting ? null : _submit,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
