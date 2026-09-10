import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/navigation/navigation_coordinator.dart';
import '../../../app/theme.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_entry_widgets.dart';
import '../../device_lock/data/device_lock_service.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dirtyForm = DirtyFormController();

  bool _submitting = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _currentPasswordController.addListener(_dirtyForm.markDirty);
    _newPasswordController.addListener(_dirtyForm.markDirty);
    _confirmPasswordController.addListener(_dirtyForm.markDirty);
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _dirtyForm.dispose();
    super.dispose();
  }

  String? _requiredPassword(String? value, String label) {
    if (value == null || value.isEmpty) {
      return '$label is required.';
    }
    if (value.length > 128) {
      return '$label must be 128 characters or fewer.';
    }
    return null;
  }

  String? _newPasswordValidator(String? value) {
    final required = _requiredPassword(value, 'New password');
    if (required != null) return required;

    if (value!.length < 8) {
      return 'New password must be at least 8 characters.';
    }
    if (value == _currentPasswordController.text) {
      return 'New password must be different from your current password.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _message = null;
    });
    _dirtyForm.beginSubmitting();

    try {
      final response = await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
            confirmPassword: _confirmPasswordController.text,
          );

      final raw = response['message'];
      final data = raw is Map<String, dynamic> ? raw : response;
      final changed =
          data['changed'] == true ||
          data['changed'] == 1 ||
          data['changed']?.toString().toLowerCase() == 'true';

      if (!changed) {
        throw StateError(
          data['message']?.toString() ?? 'Password was not changed.',
        );
      }

      await ref.read(deviceLockServiceProvider).clearBiometricLogin();
      await ref.read(authControllerProvider.notifier).logout();
      _dirtyForm.submissionSucceeded();

      if (!mounted) return;
      context.go('/login');
    } catch (error) {
      if (!mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Password not changed',
        fallbackMessage:
            'Your password could not be changed. Check the current password and try again.',
      );

      setState(() {
        _message = failure.message;
      });
      _dirtyForm.submissionFailed();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  InputDecoration _passwordDecoration({
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        tooltip: obscure ? 'Show password' : 'Hide password',
        onPressed: _submitting ? null : onToggle,
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldLabelStyle = Theme.of(context).textTheme.labelLarge;

    return UnsavedChangesGuard(
      controller: _dirtyForm,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Change password'),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _submitting
                ? null
                : () => NavigationCoordinator.back(
                    context,
                    fallbackLocation: '/settings',
                  ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.formMaxWidth,
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width),
                  18,
                  AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width),
                  40,
                ),
                children: [
                  Text(
                    'Secure your account',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Confirm your current password, then choose a new one. A successful change clears biometric sign-in enrollment and signs this device out.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  PremiumCard(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Current password', style: fieldLabelStyle),
                            const SizedBox(height: AppSpacing.xs),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: _obscureCurrent,
                              enabled: !_submitting,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.password],
                              decoration: _passwordDecoration(
                                icon: Icons.lock_outline_rounded,
                                obscure: _obscureCurrent,
                                onToggle: () {
                                  setState(
                                    () => _obscureCurrent = !_obscureCurrent,
                                  );
                                },
                              ),
                              validator: (value) =>
                                  _requiredPassword(value, 'Current password'),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text('New password', style: fieldLabelStyle),
                            const SizedBox(height: AppSpacing.xs),
                            const _PasswordRequirements(),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _obscureNew,
                              enabled: !_submitting,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: _passwordDecoration(
                                icon: Icons.password_rounded,
                                obscure: _obscureNew,
                                onToggle: () {
                                  setState(() => _obscureNew = !_obscureNew);
                                },
                              ),
                              validator: _newPasswordValidator,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Confirm new password',
                              style: fieldLabelStyle,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              enabled: !_submitting,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: _passwordDecoration(
                                icon: Icons.lock_reset_outlined,
                                obscure: _obscureConfirm,
                                onToggle: () {
                                  setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  );
                                },
                              ),
                              validator: (value) {
                                final required = _requiredPassword(
                                  value,
                                  'Password confirmation',
                                );
                                if (required != null) return required;
                                if (value != _newPasswordController.text) {
                                  return 'Passwords do not match.';
                                }
                                return null;
                              },
                            ),
                            if (_message != null) ...[
                              const SizedBox(height: 14),
                              AuthErrorBanner(message: _message!),
                            ],
                            const SizedBox(height: 22),
                            AppButton(
                              label: 'Change password',
                              icon: Icons.lock_reset_rounded,
                              isLoading: _submitting,
                              onPressed: _submitting ? null : _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.infoSoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppTheme.info,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Use at least 8 characters, no more than 128, and choose a password different from your current one.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
