import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/auth_repository.dart';
import 'auth_entry_widgets.dart';

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

  final _accountFormKey = GlobalKey<FormState>();
  final _verificationFormKey = GlobalKey<FormState>();
  final _securityFormKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _cnicController = TextEditingController();
  final _addressController = TextEditingController();
  final _educationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _remarksController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submittedSuccessfully = false;
  int _step = 0;
  String _selectedRole = _roles.first;
  String? _submitError;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _whatsappController.dispose();
    _cnicController.dispose();
    _addressController.dispose();
    _educationController.dispose();
    _experienceController.dispose();
    _remarksController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_accountFormKey.currentState?.validate() ?? false)) {
      setState(() => _step = 0);
      return;
    }
    if (!(_verificationFormKey.currentState?.validate() ?? false)) {
      setState(() => _step = 1);
      return;
    }
    if (!(_securityFormKey.currentState?.validate() ?? false)) {
      setState(() => _step = 2);
      return;
    }

    if (!_acceptedTerms) {
      setState(() {
        _step = 2;
        _submitError =
            'Please accept the terms and review process before creating an account.';
      });
      return;
    }

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

      setState(() {
        _submittedSuccessfully = true;
      });
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

  void _nextStep() {
    final key = switch (_step) {
      0 => _accountFormKey,
      1 => _verificationFormKey,
      _ => _securityFormKey,
    };

    if (!(key.currentState?.validate() ?? false)) return;
    setState(() {
      _submitError = null;
      _step = (_step + 1).clamp(0, 2);
    });
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
    if (_submittedSuccessfully) {
      return const _SignupSuccessScreen();
    }

    return AuthEntryScaffold(
      title: 'Create your OMC account',
      subtitle:
          'Choose your role, submit details, and OMC will review access before protected services open.',
      leading: IconButton(
        tooltip: 'Back to login',
        onPressed: _isSubmitting ? null : () => context.go('/login'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      footer: _LoginFooter(isSubmitting: _isSubmitting),
      child: PremiumCard(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SignupStepper(step: _step),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: switch (_step) {
                  0 => _AccountStep(
                    formKey: _accountFormKey,
                    roles: _roles,
                    selectedRole: _selectedRole,
                    onRoleChanged: (role) {
                      setState(() {
                        _selectedRole = role;
                      });
                    },
                    fullNameController: _fullNameController,
                    emailController: _emailController,
                    mobileController: _mobileController,
                    whatsappController: _whatsappController,
                    requiredValidator: _required,
                    emailValidator: _emailValidator,
                    phoneValidator: _pakistanPhoneValidator,
                  ),
                  1 => _VerificationStep(
                    formKey: _verificationFormKey,
                    selectedRole: _selectedRole,
                    cnicController: _cnicController,
                    addressController: _addressController,
                    educationController: _educationController,
                    experienceController: _experienceController,
                    remarksController: _remarksController,
                    requiredValidator: _required,
                    cnicValidator: _cnicValidator,
                  ),
                  _ => _SecurityStep(
                    formKey: _securityFormKey,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    obscurePassword: _obscurePassword,
                    obscureConfirmPassword: _obscureConfirmPassword,
                    acceptedTerms: _acceptedTerms,
                    onTogglePassword: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    onToggleConfirmPassword: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    onTermsChanged: _isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _acceptedTerms = value ?? false;
                            });
                          },
                    requiredValidator: _required,
                    passwordValidator: _passwordValidator,
                  ),
                },
              ),
            ),
            if (_submitError != null && _submitError!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              AuthErrorBanner(message: _submitError!),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _submitError = null;
                                _step = (_step - 1).clamp(0, 2);
                              });
                            },
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: _step == 2 ? 'Create account' : 'Continue',
                    icon: _step == 2
                        ? Icons.person_add_alt_1_rounded
                        : Icons.arrow_forward_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting
                        ? null
                        : _step == 2
                        ? _submit
                        : _nextStep,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.formKey,
    required this.roles,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.fullNameController,
    required this.emailController,
    required this.mobileController,
    required this.whatsappController,
    required this.requiredValidator,
    required this.emailValidator,
    required this.phoneValidator,
  });

  final GlobalKey<FormState> formKey;
  final List<String> roles;
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController mobileController;
  final TextEditingController whatsappController;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?, String) phoneValidator;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepTitle(
            title: 'Account type',
            subtitle: 'Select how you want to use OMC.',
          ),
          const SizedBox(height: 14),
          for (final role in roles) ...[
            _RoleCard(
              role: role,
              selected: selectedRole == role,
              onTap: () => onRoleChanged(role),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          TextFormField(
            controller: fullNameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (value) => requiredValidator(value, 'Full name'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: emailValidator,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: mobileController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              prefixIcon: Icon(Icons.phone_outlined),
              prefixText: '+92 ',
            ),
            validator: (value) => phoneValidator(value, 'Mobile number'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: whatsappController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'WhatsApp number',
              prefixIcon: Icon(Icons.chat_outlined),
              prefixText: '+92 ',
            ),
            validator: (value) => phoneValidator(value, 'WhatsApp number'),
          ),
        ],
      ),
    );
  }
}

class _VerificationStep extends StatelessWidget {
  const _VerificationStep({
    required this.formKey,
    required this.selectedRole,
    required this.cnicController,
    required this.addressController,
    required this.educationController,
    required this.experienceController,
    required this.remarksController,
    required this.requiredValidator,
    required this.cnicValidator,
  });

  final GlobalKey<FormState> formKey;
  final String selectedRole;
  final TextEditingController cnicController;
  final TextEditingController addressController;
  final TextEditingController educationController;
  final TextEditingController experienceController;
  final TextEditingController remarksController;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) cnicValidator;

  @override
  Widget build(BuildContext context) {
    final isTaxAssociate = selectedRole == 'Tax Associate';

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepTitle(
            title: 'Verification details',
            subtitle: 'These details help OMC verify your profile.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: cnicController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: const InputDecoration(
              labelText: 'CNIC',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
            validator: cnicValidator,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: addressController,
            textInputAction: TextInputAction.next,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (value) => requiredValidator(value, 'Address'),
          ),
          if (isTaxAssociate) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: educationController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Education',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              validator: (value) => requiredValidator(value, 'Education'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: experienceController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Experience',
                prefixIcon: Icon(Icons.timeline_outlined),
              ),
              validator: (value) => requiredValidator(value, 'Experience'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: remarksController,
              textInputAction: TextInputAction.done,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              validator: (value) => requiredValidator(value, 'Remarks'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SecurityStep extends StatelessWidget {
  const _SecurityStep({
    required this.formKey,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.acceptedTerms,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onTermsChanged,
    required this.requiredValidator,
    required this.passwordValidator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool acceptedTerms;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final ValueChanged<bool?>? onTermsChanged;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) passwordValidator;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepTitle(
            title: 'Security and review',
            subtitle: 'Set a password and confirm the account review process.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: obscurePassword ? 'Show password' : 'Hide password',
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: passwordValidator,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: confirmPasswordController,
            obscureText: obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_person_outlined),
              suffixIcon: IconButton(
                tooltip: obscureConfirmPassword
                    ? 'Show password'
                    : 'Hide password',
                onPressed: onToggleConfirmPassword,
                icon: Icon(
                  obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              final requiredMessage = requiredValidator(
                value,
                'Confirm password',
              );
              if (requiredMessage != null) return requiredMessage;

              if (value != passwordController.text) {
                return 'Passwords do not match.';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5EAF2)),
            ),
            child: CheckboxListTile(
              value: acceptedTerms,
              onChanged: onTermsChanged,
              contentPadding: const EdgeInsets.only(left: 4, right: 10),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I confirm my details are correct and understand my account will be reviewed before protected services are enabled.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _ReviewNotice(),
        ],
      ),
    );
  }
}

class _SignupStepper extends StatelessWidget {
  const _SignupStepper({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Account', 'Verify', 'Secure'];

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: i <= step
                    ? AppTheme.primaryRed.withValues(
                        alpha: i == step ? 1 : 0.10,
                      )
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: i == step
                      ? Colors.white
                      : i < step
                      ? AppTheme.primaryRed
                      : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (i != labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13.5,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final String role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = switch (role) {
      'Consultant' => (
        Icons.support_agent_rounded,
        'Work with OMC service and customer workflows.',
      ),
      'Business Partner' => (
        Icons.handshake_outlined,
        'Collaborate on referrals and partner-led services.',
      ),
      'Tax Associate' => (
        Icons.calculate_outlined,
        'Submit credentials for tax associate access.',
      ),
      _ => (
        Icons.person_outline_rounded,
        'Request services and track your own account.',
      ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryRed.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.primaryRed : const Color(0xFFE5EAF2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryRed.withValues(alpha: 0.14)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.$1, color: AppTheme.primaryRed),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.$2,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppTheme.primaryRed : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_rounded, color: Color(0xFFEA580C), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your account is under review. OMC team will verify your profile before enabling service access.',
              style: TextStyle(
                color: Color(0xFF9A3412),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  const _LoginFooter({required this.isSubmitting});

  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
            onPressed: isSubmitting ? null : () => context.go('/login'),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}

class _SignupSuccessScreen extends StatelessWidget {
  const _SignupSuccessScreen();

  @override
  Widget build(BuildContext context) {
    return AuthEntryScaffold(
      title: 'Account submitted for review',
      subtitle:
          'Your account is under review. OMC team will verify your profile before enabling service access.',
      child: PremiumCard(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF16A34A),
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'We received your details.',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Login after approval to access protected services, documents, payments and tracking.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
            AppButton(
              label: 'Go to Login',
              icon: Icons.login_rounded,
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}
