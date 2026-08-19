import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/auth_repository.dart';
import 'auth_entry_widgets.dart';
import 'signup_steps.dart';

typedef SignupSubmit =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

final signupSubmitProvider = Provider<SignupSubmit>((ref) {
  final repository = ref.read(authRepositoryProvider);
  return (data) => repository.signUp(data: data);
});

typedef SignupUsernameAvailabilityCheck =
    Future<Map<String, dynamic>> Function(String username);

final signupUsernameAvailabilityProvider =
    Provider<SignupUsernameAvailabilityCheck>((ref) {
      final repository = ref.read(authRepositoryProvider);
      return (username) =>
          repository.checkUsernameAvailability(username: username);
    });

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  static const roles = <String>[
    'Customer',
    'Consultant',
    'Business Partner',
    'Tax Associate',
  ];

  static const acquisitionSources = <String>[
    'Referral',
    'Website',
    'Social Media',
    'Advertisement',
    'Existing Customer',
    'Event',
    'Other',
  ];

  final _roleFormKey = GlobalKey<FormState>();
  final _detailsFormKey = GlobalKey<FormState>();
  final _preferencesFormKey = GlobalKey<FormState>();
  final _securityFormKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _cnicController = TextEditingController();
  final _addressController = TextEditingController();
  final _educationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _remarksController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _acquisitionSourceDetailController = TextEditingController();

  bool _isSubmitting = false;
  bool _acceptedTerms = false;
  bool _submittedSuccessfully = false;
  bool _whatsappSameAsMobile = true;
  bool _referralExpanded = false;
  bool _referralAssistanceConsent = false;
  bool _isValidatingReferral = false;
  bool _isCheckingUsername = false;
  bool _usernameEdited = false;
  bool? _usernameAvailable;
  String? _usernameMessage;
  int _step = 0;
  String _selectedRole = roles.first;
  String? _selectedAcquisitionSource;
  String? _referralValidationMessage;
  bool? _referralCodeValid;
  String? _submitError;
  String _submittedEmail = '';
  int _submittedCooldownSeconds = 60;
  final _dirtyForm = DirtyFormController();

  bool get _isCustomer => _selectedRole == 'Customer';

  @override
  void initState() {
    super.initState();
    for (final controller in <TextEditingController>[
      _fullNameController,
      _emailController,
      _usernameController,
      _mobileController,
      _whatsappController,
      _cnicController,
      _addressController,
      _educationController,
      _experienceController,
      _remarksController,
      _referralCodeController,
      _acquisitionSourceDetailController,
    ]) {
      controller.addListener(_dirtyForm.markDirty);
    }
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _fullNameController,
      _emailController,
      _usernameController,
      _mobileController,
      _whatsappController,
      _cnicController,
      _addressController,
      _educationController,
      _experienceController,
      _remarksController,
      _referralCodeController,
      _acquisitionSourceDetailController,
    ]) {
      controller.dispose();
    }
    _dirtyForm.dispose();
    super.dispose();
  }

  String _normalizeUsername(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9._]+'), '.');
    normalized = normalized.replaceAll(RegExp(r'[._]{2,}'), '.');
    normalized = normalized.replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    return normalized;
  }

  String? _usernameValidator(String? value) {
    final username = _normalizeUsername(value ?? '');
    if (username.isEmpty) {
      return 'Username is required.';
    }
    if (username.length < 4 || username.length > 30) {
      return 'Use 4–30 characters.';
    }
    if (!RegExp(r'^[a-z0-9][a-z0-9._]*[a-z0-9]$').hasMatch(username)) {
      return 'Use lowercase letters, numbers, dots or underscores.';
    }
    if (_usernameAvailable == false) {
      return 'Choose another username.';
    }
    return null;
  }

  Future<void> _suggestUsername() async {
    if (_usernameEdited || _fullNameController.text.trim().isEmpty) {
      return;
    }
    try {
      final response = await ref
          .read(authRepositoryProvider)
          .suggestUsername(
            fullName: _fullNameController.text.trim(),
            email: _emailController.text.trim(),
          );
      final message = response['message'];
      final data = message is Map<String, dynamic> ? message : response;
      final suggestion = data['username']?.toString().trim() ?? '';
      if (!mounted || suggestion.isEmpty || _usernameEdited) {
        return;
      }
      setState(() {
        _usernameController.text = suggestion;
        _usernameAvailable = data['available'] == true;
        _usernameMessage = 'Username available.';
      });
    } catch (_) {}
  }

  Future<bool> _checkUsernameAvailability() async {
    final username = _normalizeUsername(_usernameController.text);
    _usernameController.text = username;
    if (_usernameValidator(username) != null && username.length < 4) {
      return false;
    }
    setState(() {
      _isCheckingUsername = true;
      _usernameMessage = null;
    });
    try {
      final response = await ref.read(signupUsernameAvailabilityProvider)(
        username,
      );
      final message = response['message'];
      final data = message is Map<String, dynamic> ? message : response;
      final available = data['available'] == true || data['available'] == 1;
      if (!mounted) {
        return false;
      }
      setState(() {
        _usernameAvailable = available;
        _usernameMessage = available
            ? 'Username available.'
            : 'Username already taken.';
      });
      return available;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Username not checked',
        fallbackMessage: 'Could not check username right now.',
      );
      setState(() => _usernameMessage = failure.message);
      return false;
    } finally {
      if (mounted) setState(() => _isCheckingUsername = false);
    }
  }

  Future<bool> _validateReferralBeforeSubmit() async {
    if (!_isCustomer || _selectedAcquisitionSource != 'Referral') {
      return true;
    }

    final code = _referralCodeController.text.trim().toUpperCase().replaceAll(
      ' ',
      '',
    );
    if (code.isEmpty) {
      setState(() {
        _referralCodeValid = false;
        _referralValidationMessage = 'Referral code is required.';
      });
      return false;
    }
    if (!_referralAssistanceConsent) {
      setState(() {
        _referralCodeValid = false;
        _referralValidationMessage = 'Referral assistance consent is required.';
      });
      return false;
    }

    setState(() {
      _isValidatingReferral = true;
      _referralValidationMessage = null;
    });
    try {
      final response = await ref
          .read(authRepositoryProvider)
          .validateReferralCode(referralCode: code);
      final message = response['message'];
      final data = message is Map<String, dynamic> ? message : response;
      final valid =
          data['valid'] == true ||
          data['valid'] == 1 ||
          data['valid']?.toString().toLowerCase() == 'true';
      if (!mounted) {
        return false;
      }
      setState(() {
        _referralCodeValid = valid;
        _referralValidationMessage = valid
            ? 'Referral code verified.'
            : 'Referral code is invalid or inactive.';
        final normalized = data['referral_code']?.toString().trim() ?? '';
        if (valid && normalized.isNotEmpty) {
          _referralCodeController.text = normalized;
        }
      });
      return valid;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Referral not verified',
        fallbackMessage:
            'Referral code could not be verified right now. Please try again.',
      );
      setState(() {
        _referralCodeValid = false;
        _referralValidationMessage = failure.message;
      });
      return false;
    } finally {
      if (mounted) setState(() => _isValidatingReferral = false);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || _submittedSuccessfully) {
      return;
    }
    if (!(_securityFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_acceptedTerms) {
      setState(() {
        _submitError =
            'Please accept the terms and review process before creating an account.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    if (!await _validateReferralBeforeSubmit()) {
      if (mounted) {
        setState(() {
          _step = 2;
          _referralExpanded = true;
          _submitError =
              _referralValidationMessage ?? 'Referral validation failed.';
        });
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    _dirtyForm.beginSubmitting();
    try {
      final response = await ref.read(signupSubmitProvider)({
        'full_name': _fullNameController.text.trim(),
        'first_name': _firstNameFromFullName(_fullNameController.text),
        'last_name': _lastNameFromFullName(_fullNameController.text),
        'email': _emailController.text.trim(),
        'username': _normalizeUsername(_usernameController.text),
        'phone': _toPakistanPhoneNumber(_mobileController.text),
        'mobile': _toPakistanPhoneNumber(_mobileController.text),
        'whatsapp_no': _toPakistanPhoneNumber(
          _whatsappSameAsMobile
              ? _mobileController.text
              : _whatsappController.text,
        ),
        'cnic': _normalizeCnic(_cnicController.text),
        'customer_type': _selectedRole,
        'register_as': _selectedRole,
        'address': _addressController.text.trim(),
        'acquisition_source': _isCustomer
            ? (_selectedAcquisitionSource ?? '')
            : '',
        'acquisition_source_detail': _isCustomer
            ? _acquisitionSourceDetailController.text.trim()
            : '',
        if (_isCustomer && _selectedAcquisitionSource == 'Referral') ...{
          'referral_code': _referralCodeController.text
              .trim()
              .toUpperCase()
              .replaceAll(' ', ''),
          'referral_assistance_consent': _referralAssistanceConsent ? 1 : 0,
        },
        if (_selectedRole == 'Tax Associate') ...{
          'education': _educationController.text.trim(),
          'experience': _experienceController.text.trim(),
          'remarks': _remarksController.text.trim(),
        },
      });
      final raw = response['message'];
      final data = raw is Map<String, dynamic> ? raw : response;
      final cooldownSeconds =
          int.tryParse(data['cooldown_seconds']?.toString() ?? '') ?? 60;

      if (mounted) {
        setState(() {
          _submittedEmail = _emailController.text.trim();
          _submittedCooldownSeconds = cooldownSeconds.clamp(0, 3600);
          _submittedSuccessfully = true;
        });
        _dirtyForm.submissionSucceeded();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Registration not started',
        fallbackMessage:
            'Unable to start email verification right now. Your entered information was retained.',
      );
      setState(() => _submitError = failure.message);
      _dirtyForm.submissionFailed();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _nextStep() async {
    final key = <GlobalKey<FormState>>[
      _roleFormKey,
      _detailsFormKey,
      _preferencesFormKey,
      _securityFormKey,
    ][_step];
    if (!(key.currentState?.validate() ?? false)) {
      return;
    }
    _dirtyForm.markDirty();
    if (_step == 1 && !await _checkUsernameAvailability()) {
      return;
    }

    if (_step == 2 &&
        _isCustomer &&
        _selectedAcquisitionSource == 'Referral' &&
        !_referralAssistanceConsent) {
      setState(() {
        _referralValidationMessage =
            'Consent is required when using a referral code.';
        _referralCodeValid = false;
        _submitError = null;
      });
      return;
    }

    setState(() {
      _submitError = null;
      _step = (_step + 1).clamp(0, 3);
    });
  }

  void _previousStep() {
    setState(() {
      _submitError = null;
      _step = (_step - 1).clamp(0, 3);
    });
  }

  String _firstNameFromFullName(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? value.trim() : parts.first;
  }

  String _lastNameFromFullName(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    return parts.length <= 1 ? '' : parts.skip(1).join(' ');
  }

  String _normalizeCnic(String value) => value.replaceAll(RegExp(r'\D'), '');

  String _toPakistanPhoneNumber(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('92')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '+92$digits';
  }

  String? _required(String? value, String label) {
    return value == null || value.trim().isEmpty ? '$label is required.' : null;
  }

  String? _emailValidator(String? value) {
    final required = _required(value, 'Email');
    if (required != null) {
      return required;
    }
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())
        ? null
        : 'Invalid email address.';
  }

  String? _pakistanPhoneValidator(String? value, String label) {
    final required = _required(value, label);
    if (required != null) {
      return required;
    }
    var digits = value!.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('92')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return digits.length == 10 && digits.startsWith('3')
        ? null
        : 'Invalid number.';
  }

  String? _cnicValidator(String? value) {
    final required = _required(value, 'CNIC');
    if (required != null) {
      return required;
    }
    return value!.replaceAll(RegExp(r'\D'), '').length == 13
        ? null
        : 'CNIC must be exactly 13 digits.';
  }

  @override
  Widget build(BuildContext context) {
    if (_submittedSuccessfully) {
      return PendingRegistrationSuccessScreen(
        email: _submittedEmail,
        initialCooldownSeconds: _submittedCooldownSeconds,
      );
    }

    return UnsavedChangesGuard(
      controller: _dirtyForm,
      onDiscardConfirmed: () async {
        if (mounted) context.go('/login');
      },
      child: AuthEntryScaffold(
        title: 'Create your account',
        subtitle: 'A focused four-step setup for your OMC access.',
        leading: IconButton(
          tooltip: _step == 0 ? 'Back to login' : 'Previous step',
          onPressed: _isSubmitting
              ? null
              : _step == 0
              ? _requestExit
              : _previousStep,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        footer: SignupLoginFooter(isSubmitting: _isSubmitting),
        child: PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: SignupProgress(step: _step),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: switch (_step) {
                      0 => SignupRoleStep(
                        formKey: _roleFormKey,
                        roles: roles,
                        selectedRole: _selectedRole,
                        onRoleChanged: (role) {
                          setState(() {
                            _selectedRole = role;
                            _submitError = null;
                            if (role != 'Customer') {
                              _selectedAcquisitionSource = null;
                              _acquisitionSourceDetailController.clear();
                              _referralCodeController.clear();
                              _referralAssistanceConsent = false;
                              _referralExpanded = false;
                              _referralValidationMessage = null;
                              _referralCodeValid = null;
                            }
                          });
                        },
                      ),
                      1 => SignupDetailsStep(
                        formKey: _detailsFormKey,
                        selectedRole: _selectedRole,
                        fullNameController: _fullNameController,
                        emailController: _emailController,
                        usernameController: _usernameController,
                        usernameAvailable: _usernameAvailable,
                        usernameMessage: _usernameMessage,
                        isCheckingUsername: _isCheckingUsername,
                        onUsernameChanged: (value) {
                          _usernameEdited = true;
                          final normalized = _normalizeUsername(value);
                          if (normalized != value) {
                            _usernameController.value = TextEditingValue(
                              text: normalized,
                              selection: TextSelection.collapsed(
                                offset: normalized.length,
                              ),
                            );
                          }
                          setState(() {
                            _usernameAvailable = null;
                            _usernameMessage = null;
                          });
                        },
                        onSuggestUsername: _suggestUsername,
                        onCheckUsername: _checkUsernameAvailability,
                        usernameValidator: _usernameValidator,
                        mobileController: _mobileController,
                        whatsappController: _whatsappController,
                        cnicController: _cnicController,
                        addressController: _addressController,
                        educationController: _educationController,
                        experienceController: _experienceController,
                        remarksController: _remarksController,
                        whatsappSameAsMobile: _whatsappSameAsMobile,
                        onWhatsappSameAsMobileChanged: (value) {
                          setState(() {
                            _whatsappSameAsMobile = value;
                            if (value) {
                              _whatsappController.text = _mobileController.text;
                            }
                          });
                        },
                        onMobileChanged: (value) {
                          if (_whatsappSameAsMobile) {
                            _whatsappController.text = value;
                          }
                        },
                        requiredValidator: _required,
                        emailValidator: _emailValidator,
                        phoneValidator: _pakistanPhoneValidator,
                        cnicValidator: _cnicValidator,
                      ),
                      2 => SignupPreferencesStep(
                        formKey: _preferencesFormKey,
                        isCustomer: _isCustomer,
                        acquisitionSources: acquisitionSources,
                        selectedAcquisitionSource: _selectedAcquisitionSource,
                        onAcquisitionSourceChanged: (source) {
                          setState(() {
                            _selectedAcquisitionSource = source;
                            _referralExpanded = source == 'Referral';
                            _referralValidationMessage = null;
                            _referralCodeValid = null;
                            if (source != 'Referral') {
                              _referralAssistanceConsent = false;
                              _referralCodeController.clear();
                            }
                            if (source != 'Other') {
                              _acquisitionSourceDetailController.clear();
                            }
                          });
                        },
                        referralExpanded: _referralExpanded,
                        onReferralExpandedChanged: (expanded) {
                          setState(() {
                            _referralExpanded = expanded;
                            if (expanded) {
                              _selectedAcquisitionSource = 'Referral';
                            } else if (_selectedAcquisitionSource ==
                                'Referral') {
                              _selectedAcquisitionSource = null;
                              _referralCodeController.clear();
                              _referralAssistanceConsent = false;
                              _referralValidationMessage = null;
                              _referralCodeValid = null;
                            }
                          });
                        },
                        referralCodeController: _referralCodeController,
                        acquisitionSourceDetailController:
                            _acquisitionSourceDetailController,
                        referralAssistanceConsent: _referralAssistanceConsent,
                        onReferralConsentChanged: (value) {
                          setState(() {
                            _referralAssistanceConsent = value;
                            _referralValidationMessage = null;
                            _referralCodeValid = null;
                          });
                        },
                        referralCodeValid: _referralCodeValid,
                        referralValidationMessage: _referralValidationMessage,
                        isValidatingReferral: _isValidatingReferral,
                        onValidateReferral: _validateReferralBeforeSubmit,
                        requiredValidator: _required,
                      ),
                      _ => SignupSecurityStep(
                        formKey: _securityFormKey,
                        isCustomer: _isCustomer,
                        acceptedTerms: _acceptedTerms,
                        onTermsChanged: _isSubmitting
                            ? null
                            : (value) => setState(
                                () => _acceptedTerms = value ?? false,
                              ),
                      ),
                    },
                  ),
                ),
              ),
              if (_submitError != null && _submitError!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: AuthErrorBanner(message: _submitError!),
                ),
              SignupBottomActions(
                step: _step,
                isSubmitting: _isSubmitting,
                onBack: _previousStep,
                onContinue: _step == 3 ? _submit : _nextStep,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestExit() async {
    if (!await confirmDiscardActiveForm(context, ref) || !mounted) return;
    context.go('/login');
  }
}

class PendingRegistrationSuccessScreen extends ConsumerStatefulWidget {
  const PendingRegistrationSuccessScreen({
    required this.email,
    required this.initialCooldownSeconds,
    super.key,
  });

  final String email;
  final int initialCooldownSeconds;

  @override
  ConsumerState<PendingRegistrationSuccessScreen> createState() =>
      _PendingRegistrationSuccessScreenState();
}

class _PendingRegistrationSuccessScreenState
    extends ConsumerState<PendingRegistrationSuccessScreen> {
  bool _resending = false;
  String? _message;
  Timer? _cooldownTimer;
  late int _cooldownSeconds;

  @override
  void initState() {
    super.initState();
    _startCooldown(widget.initialCooldownSeconds);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    _cooldownSeconds = seconds.clamp(0, 3600);
    if (_cooldownSeconds == 0) return;

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
        return;
      }
      setState(() => _cooldownSeconds -= 1);
    });
  }

  String get _cooldownLabel {
    final minutes = (_cooldownSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_cooldownSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _resend() async {
    if (_resending || _cooldownSeconds > 0) return;

    setState(() {
      _resending = true;
      _message = null;
    });

    try {
      final response = await ref
          .read(authRepositoryProvider)
          .resendVerification(email: widget.email);
      final raw = response['message'];
      final data = raw is Map<String, dynamic> ? raw : response;

      if (!mounted) return;

      final cooldownSeconds =
          int.tryParse(data['cooldown_seconds']?.toString() ?? '') ?? 60;

      setState(() {
        _message = data['message']?.toString().trim().isNotEmpty == true
            ? data['message'].toString().trim()
            : 'If eligible, another verification email will be sent shortly.';
      });
      _startCooldown(cooldownSeconds);
    } catch (error) {
      if (!mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Email not resent',
        fallbackMessage:
            'The verification email could not be resent right now.',
      );

      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _resending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthEntryScaffold(
      title: 'Check your email',
      subtitle:
          'Your account will be created after you verify your email address.',
      child: PremiumCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.outgoing_mail, color: Color(0xFF2563EB), size: 44),
            const SizedBox(height: 18),
            Text(
              'Open the verification link sent to ${widget.email}. The link expires in 30 minutes.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 22),
            AppButton(
              label: 'Go to Login',
              icon: Icons.login_rounded,
              onPressed: () => context.go('/login'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _resending || _cooldownSeconds > 0 ? null : _resend,
              icon: _resending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(
                _resending
                    ? 'Sending...'
                    : _cooldownSeconds > 0
                    ? 'Resend available in $_cooldownLabel'
                    : 'Resend verification email',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
