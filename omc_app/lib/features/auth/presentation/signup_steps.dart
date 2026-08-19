import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import 'auth_entry_widgets.dart';

class SignupProgress extends StatelessWidget {
  const SignupProgress({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Account type', 'Basic details', 'Preferences', 'Verification'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Step ${step + 1} of ${labels.length}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              labels[step],
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (step + 1) / labels.length,
            minHeight: 6,
            backgroundColor: const Color(0xFFE9EEF5),
          ),
        ),
      ],
    );
  }
}

class SignupRoleStep extends StatelessWidget {
  const SignupRoleStep({
    super.key,
    required this.formKey,
    required this.roles,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  final GlobalKey<FormState> formKey;
  final List<String> roles;
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SignupStepTitle(
            title: 'How will you use OMC?',
            subtitle: 'Choose the account type that matches your work.',
          ),
          const SizedBox(height: 16),
          for (final role in roles) ...[
            SignupRoleCard(
              role: role,
              selected: selectedRole == role,
              onTap: () => onRoleChanged(role),
            ),
            if (role != roles.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class SignupDetailsStep extends StatelessWidget {
  const SignupDetailsStep({
    super.key,
    required this.formKey,
    required this.selectedRole,
    required this.fullNameController,
    required this.emailController,
    required this.usernameController,
    required this.onUsernameChanged,
    required this.onSuggestUsername,
    required this.onCheckUsername,
    required this.usernameValidator,
    required this.usernameAvailable,
    required this.usernameMessage,
    required this.isCheckingUsername,
    required this.mobileController,
    required this.whatsappController,
    required this.cnicController,
    required this.addressController,
    required this.educationController,
    required this.experienceController,
    required this.remarksController,
    required this.whatsappSameAsMobile,
    required this.onWhatsappSameAsMobileChanged,
    required this.onMobileChanged,
    required this.requiredValidator,
    required this.emailValidator,
    required this.phoneValidator,
    required this.cnicValidator,
  });

  final GlobalKey<FormState> formKey;
  final String selectedRole;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController usernameController;
  final ValueChanged<String> onUsernameChanged;
  final VoidCallback onSuggestUsername;
  final Future<bool> Function() onCheckUsername;
  final String? Function(String?) usernameValidator;
  final bool? usernameAvailable;
  final String? usernameMessage;
  final bool isCheckingUsername;
  final TextEditingController mobileController;
  final TextEditingController whatsappController;
  final TextEditingController cnicController;
  final TextEditingController addressController;
  final TextEditingController educationController;
  final TextEditingController experienceController;
  final TextEditingController remarksController;
  final bool whatsappSameAsMobile;
  final ValueChanged<bool> onWhatsappSameAsMobileChanged;
  final ValueChanged<String> onMobileChanged;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?, String) phoneValidator;
  final String? Function(String?) cnicValidator;

  @override
  Widget build(BuildContext context) {
    final isTaxAssociate = selectedRole == 'Tax Associate';
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SignupStepTitle(
            title: 'Basic information',
            subtitle: 'Enter the details OMC needs to identify your account.',
          ),
          const SizedBox(height: 16),
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
            controller: usernameController,
            onChanged: onUsernameChanged,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: 'ali.khan',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              suffixIcon: isCheckingUsername
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: usernameController.text.trim().isEmpty
                          ? 'Suggest username'
                          : 'Check username',
                      onPressed: usernameController.text.trim().isEmpty
                          ? onSuggestUsername
                          : () => onCheckUsername(),
                      icon: Icon(
                        usernameAvailable == true
                            ? Icons.check_circle_rounded
                            : Icons.verified_outlined,
                      ),
                    ),
            ),
            validator: usernameValidator,
          ),
          if (usernameMessage != null) ...[
            const SizedBox(height: 7),
            Text(
              usernameMessage!,
              style: TextStyle(
                color: usernameAvailable == true
                    ? const Color(0xFF067647)
                    : usernameAvailable == false
                    ? const Color(0xFFB42318)
                    : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: mobileController,
            keyboardType: TextInputType.phone,
            onChanged: onMobileChanged,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              hintText: '300 1234567',
              counterText: '',
              prefixIcon: Icon(Icons.phone_outlined),
              prefixText: '+92 ',
            ),
            validator: (value) => phoneValidator(value, 'Mobile number'),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: whatsappSameAsMobile,
            onChanged: (value) => onWhatsappSameAsMobileChanged(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: const Text(
              'Use this number for WhatsApp',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          if (!whatsappSameAsMobile) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: whatsappController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'WhatsApp number',
                hintText: '300 1234567',
                counterText: '',
                prefixIcon: Icon(Icons.chat_outlined),
                prefixText: '+92 ',
              ),
              validator: (value) => phoneValidator(value, 'WhatsApp number'),
            ),
          ],
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
              hintText: '35202-1234567-1',
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
            const SizedBox(height: 20),
            const SignupStepTitle(
              title: 'Professional details',
              subtitle: 'These details support OMC’s access review.',
            ),
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

class SignupPreferencesStep extends StatelessWidget {
  const SignupPreferencesStep({
    super.key,
    required this.formKey,
    required this.isCustomer,
    required this.acquisitionSources,
    required this.selectedAcquisitionSource,
    required this.onAcquisitionSourceChanged,
    required this.referralExpanded,
    required this.onReferralExpandedChanged,
    required this.referralCodeController,
    required this.acquisitionSourceDetailController,
    required this.referralAssistanceConsent,
    required this.onReferralConsentChanged,
    required this.referralCodeValid,
    required this.referralValidationMessage,
    required this.isValidatingReferral,
    required this.onValidateReferral,
    required this.requiredValidator,
  });

  final GlobalKey<FormState> formKey;
  final bool isCustomer;
  final List<String> acquisitionSources;
  final String? selectedAcquisitionSource;
  final ValueChanged<String?> onAcquisitionSourceChanged;
  final bool referralExpanded;
  final ValueChanged<bool> onReferralExpandedChanged;
  final TextEditingController referralCodeController;
  final TextEditingController acquisitionSourceDetailController;
  final bool referralAssistanceConsent;
  final ValueChanged<bool> onReferralConsentChanged;
  final bool? referralCodeValid;
  final String? referralValidationMessage;
  final bool isValidatingReferral;
  final Future<bool> Function() onValidateReferral;
  final String? Function(String?, String) requiredValidator;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SignupStepTitle(
            title: isCustomer ? 'Referral and preferences' : 'Review pathway',
            subtitle: isCustomer
                ? 'Referral information is optional unless you choose Referral as your source.'
                : 'OMC will review this account type before protected access is enabled.',
          ),
          const SizedBox(height: 16),
          if (!isCustomer)
            const SignupReviewNotice()
          else ...[
            ExpansionTile(
              initiallyExpanded: referralExpanded,
              onExpansionChanged: onReferralExpandedChanged,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE5EAF2)),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE5EAF2)),
              ),
              title: const Text(
                'Have a referral code?',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text('Add and verify it here.'),
              children: [
                TextFormField(
                  controller: referralCodeController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
                    LengthLimitingTextInputFormatter(12),
                  ],
                  onChanged: (value) {
                    final compact = value.toUpperCase().replaceAll(
                      RegExp(r'[^A-Z0-9]'),
                      '',
                    );

                    final normalized = compact.length <= 3
                        ? compact
                        : '${compact.substring(0, 3)}-${compact.substring(3)}';

                    if (normalized != value) {
                      referralCodeController.value = TextEditingValue(
                        text: normalized,
                        selection: TextSelection.collapsed(
                          offset: normalized.length,
                        ),
                      );
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Referral code',
                    hintText: 'OMC-XXXXXX',
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    suffixIcon: isValidatingReferral
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Verify referral code',
                            onPressed: () => onValidateReferral(),
                            icon: const Icon(Icons.verified_outlined),
                          ),
                  ),
                  validator: referralExpanded
                      ? (value) => requiredValidator(value, 'Referral code')
                      : null,
                ),
                if (referralValidationMessage != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      referralValidationMessage!,
                      style: TextStyle(
                        color: referralCodeValid == true
                            ? const Color(0xFF067647)
                            : const Color(0xFFB42318),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: referralAssistanceConsent,
                  onChanged: (value) =>
                      onReferralConsentChanged(value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Allow the referring OMC staff member to assist with my service requests.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedAcquisitionSource,
              decoration: const InputDecoration(
                labelText: 'How did you hear about OMC?',
                prefixIcon: Icon(Icons.campaign_outlined),
              ),
              items: acquisitionSources
                  .map(
                    (source) => DropdownMenuItem<String>(
                      value: source,
                      child: Text(source),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onAcquisitionSourceChanged,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Please select a source.'
                  : null,
            ),
            if (selectedAcquisitionSource == 'Other') ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: acquisitionSourceDetailController,
                decoration: const InputDecoration(
                  labelText: 'Please specify',
                  prefixIcon: Icon(Icons.edit_note_outlined),
                ),
                validator: (value) =>
                    requiredValidator(value, 'Source details'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class SignupSecurityStep extends StatelessWidget {
  const SignupSecurityStep({
    super.key,
    required this.formKey,
    required this.isCustomer,
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
  final bool isCustomer;
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
          const SignupStepTitle(
            title: 'Review and verify your email',
            subtitle:
                'OMC will email a single-use verification link. You will create your password only after opening that verified link.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: Color(0xFF15803D)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No password is collected or stored before email verification. After verification, the secure link asks you to set and confirm a new password.',
                    style: TextStyle(
                      color: Color(0xFF166534),
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE5EAF2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: CheckboxListTile(
              value: acceptedTerms,
              onChanged: onTermsChanged,
              contentPadding: const EdgeInsets.only(left: 4, right: 10),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                isCustomer
                    ? 'I confirm my details are correct and agree to verify my email before my OMC customer account is created.'
                    : 'I confirm my details are correct and understand that email verification and OMC review are required before protected access is enabled.',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (!isCustomer) ...[
            const SizedBox(height: 12),
            const SignupReviewNotice(),
          ],
        ],
      ),
    );
  }
}

class SignupBottomActions extends StatelessWidget {
  const SignupBottomActions({
    super.key,
    required this.step,
    required this.isSubmitting,
    required this.onBack,
    required this.onContinue,
  });

  final int step;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final isLast = step == 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9EEF5))),
      ),
      child: Row(
        children: [
          if (step > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: isSubmitting ? null : onBack,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: AppButton(
              label: isLast ? 'Send verification email' : 'Continue',
              icon: isLast
                  ? Icons.mark_email_unread_outlined
                  : Icons.arrow_forward_rounded,
              isLoading: isSubmitting,
              onPressed: isSubmitting ? null : onContinue,
            ),
          ),
        ],
      ),
    );
  }
}

class SignupStepTitle extends StatelessWidget {
  const SignupStepTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

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

class SignupRoleCard extends StatelessWidget {
  const SignupRoleCard({
    super.key,
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
        'Manage assigned customer work.',
      ),
      'Business Partner' => (Icons.handshake_outlined, 'Collaborate with OMC.'),
      'Tax Associate' => (
        Icons.calculate_outlined,
        'Apply for professional access.',
      ),
      _ => (Icons.person_outline_rounded, 'Request and track OMC services.'),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.07)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : const Color(0xFFE5EAF2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              data.$1,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
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
              color: selected ? AppTheme.primary : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

class SignupReviewNotice extends StatelessWidget {
  const SignupReviewNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_rounded, color: Color(0xFFEA580C), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'OMC will verify this profile before protected services are enabled.',
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

class SignupLoginFooter extends StatelessWidget {
  const SignupLoginFooter({super.key, required this.isSubmitting});

  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
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
          child: const Text('Sign in'),
        ),
      ],
    );
  }
}

class SignupSuccessScreen extends StatelessWidget {
  const SignupSuccessScreen({super.key, required this.isCustomer});

  final bool isCustomer;

  @override
  Widget build(BuildContext context) {
    return AuthEntryScaffold(
      title: isCustomer
          ? 'Customer account created'
          : 'Account submitted for review',
      subtitle: isCustomer
          ? 'Your customer account is active. You can sign in now.'
          : 'OMC will review your profile before protected access is enabled.',
      child: PremiumCard(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF16A34A),
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isCustomer
                  ? 'Your account is ready.'
                  : 'We received your details.',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCustomer
                  ? 'Sign in to request services, upload documents and track your cases.'
                  : 'Sign in after approval to access protected services and workflows.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
            AppButton(
              label: 'Go to sign in',
              icon: Icons.login_rounded,
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}
