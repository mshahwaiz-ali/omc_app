import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/omc_logo.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/auth_repository.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  static const List<String> _roles = [
    'Customer',
    'Consultant',
    'Business Partner',
    'Tax Associate',
  ];

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _cnicController = TextEditingController();
  final _addressController = TextEditingController();
  final _educationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _remarksController = TextEditingController();

  bool _isSubmitting = false;
  String? _submitError;

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = _roles.first;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _whatsappController.dispose();
    _cnicController.dispose();
    _addressController.dispose();
    _educationController.dispose();
    _experienceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            data: {
              'full_name': _fullNameController.text.trim(),
              'first_name': _firstNameFromFullName(_fullNameController.text),
              'last_name': _lastNameFromFullName(_fullNameController.text),
              'email': _emailController.text.trim(),
              'phone': _toPakistanPhoneNumber(_mobileController.text),
              'mobile': _toPakistanPhoneNumber(_mobileController.text),
              'whatsapp_no': _toPakistanPhoneNumber(_whatsappController.text),
              'cnic': _normalizeCnic(_cnicController.text),
              'customer_type': _selectedRole,
              'register_as': _selectedRole,
              'address': _addressController.text.trim(),
              'password': _passwordController.text,
              'confirm_password': _confirmPasswordController.text,
              if (_selectedRole == 'Tax Associate') ...{
                'education': _educationController.text.trim(),
                'experience': _experienceController.text.trim(),
                'remarks': _remarksController.text.trim(),
              },
            },
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully. Please login.'),
        ),
      );

      context.go('/login');
    } on ApiError catch (error) {
      if (!mounted) return;

      setState(() {
        _submitError = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _submitError = 'Unable to create account right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _firstNameFromFullName(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return value.trim();
    return parts.first;
  }

  String _lastNameFromFullName(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return '';
    return parts.skip(1).join(' ');
  }

  String _normalizeCnic(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _toPakistanPhoneNumber(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('92')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+92$digits';
  }

  String? _pakistanPhoneValidator(String? value, String label) {
    final requiredMessage = _required(value, label);
    if (requiredMessage != null) return requiredMessage;

    var digits = value!.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('92')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (!RegExp(r'^3\d{9}$').hasMatch(digits)) {
      return '$label must be a valid Pakistan number, e.g. 3063191907.';
    }

    return null;
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final requiredMessage = _required(value, 'Email');
    if (requiredMessage != null) return requiredMessage;

    final email = value!.trim();
    final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!isValid) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _cnicValidator(String? value) {
    final requiredMessage = _required(value, 'CNIC');
    if (requiredMessage != null) return requiredMessage;

    final digits = value!.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) {
      return 'CNIC must be exactly 13 digits.';
    }

    return null;
  }

  String? _passwordValidator(String? value) {
    final requiredMessage = _required(value, 'Password');
    if (requiredMessage != null) return requiredMessage;

    if (value!.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back to login',
          onPressed: _isSubmitting ? null : () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SignupHeader(),
                  const SizedBox(height: 24),
                  PremiumCard(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _fullNameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (value) => _required(value, 'Full name'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: _emailValidator,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Mobile number',
                              prefixIcon: Icon(Icons.phone_outlined),
                              prefixText: '+92 ',
                            ),
                            validator: (value) =>
                                _pakistanPhoneValidator(value, 'Mobile number'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _whatsappController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'WhatsApp number',
                              prefixIcon: Icon(Icons.chat_outlined),
                              prefixText: '+92 ',
                            ),
                            validator: (value) => _pakistanPhoneValidator(
                              value,
                              'WhatsApp number',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _cnicController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9-]'),
                              ),
                              LengthLimitingTextInputFormatter(15),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'CNIC',
                              prefixIcon: Icon(Icons.credit_card_outlined),
                            ),
                            validator: _cnicValidator,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            decoration: const InputDecoration(
                              labelText: 'Register as',
                              prefixIcon: Icon(Icons.work_outline_rounded),
                            ),
                            items: _roles
                                .map(
                                  (role) => DropdownMenuItem<String>(
                                    value: role,
                                    child: Text(role),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedRole = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _addressController,
                            textInputAction: TextInputAction.next,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            validator: (value) => _required(value, 'Address'),
                          ),
                          if (_selectedRole == 'Tax Associate') ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _educationController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Education',
                                prefixIcon: Icon(Icons.school_outlined),
                              ),
                              validator: _selectedRole == 'Tax Associate'
                                  ? (value) => _required(value, 'Education')
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _experienceController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Experience',
                                prefixIcon: Icon(Icons.timeline_outlined),
                              ),
                              validator: _selectedRole == 'Tax Associate'
                                  ? (value) => _required(value, 'Experience')
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _remarksController,
                              textInputAction: TextInputAction.next,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Remarks',
                                prefixIcon: Icon(Icons.notes_outlined),
                              ),
                              validator: _selectedRole == 'Tax Associate'
                                  ? (value) => _required(value, 'Remarks')
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
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
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon: const Icon(
                                Icons.lock_person_outlined,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmPassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final requiredMessage = _required(
                                value,
                                'Confirm password',
                              );
                              if (requiredMessage != null) {
                                return requiredMessage;
                              }

                              if (value != _passwordController.text) {
                                return 'Passwords do not match.';
                              }

                              return null;
                            },
                          ),
                          if (_submitError != null &&
                              _submitError!.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _SignupErrorBanner(message: _submitError!),
                          ],
                          const SizedBox(height: 20),
                          AppButton(
                            label: 'Create account',
                            icon: Icons.person_add_alt_1_rounded,
                            isLoading: _isSubmitting,
                            onPressed: _isSubmitting ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already registered?',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => context.go('/login'),
                          child: const Text('Login'),
                        ),
                      ],
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

class _SignupErrorBanner extends StatelessWidget {
  const _SignupErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupHeader extends StatelessWidget {
  const _SignupHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const OmcLogo.full(width: 190, height: 66),
        const SizedBox(height: 24),
        const Text(
          'Create your OMC account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 28,
            height: 1.12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Secure access to services, tax tools, support and account updates.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
