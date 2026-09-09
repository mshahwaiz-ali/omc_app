import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import 'auth_entry_widgets.dart';

class SignupProgress extends StatelessWidget {
  const SignupProgress({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Access type',
      'Basic details',
      'Preferences',
      'Verification',
    ];
    final active = labels[step];

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Step ${step + 1} of ${labels.length}: $active',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Step ${step + 1} of ${labels.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  active,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (step + 1) / labels.length,
                minHeight: 7,
                backgroundColor: AppTheme.processingSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignupRoleStep extends StatelessWidget {
  const SignupRoleStep({
    super.key,
    required this.formKey,
    required this.roles,
    required this.selectedRole,
    required this.selectedOnboardingMode,
    required this.onOnboardingModeChanged,
    required this.onRoleChanged,
  });

  final GlobalKey<FormState> formKey;
  final List<String> roles;
  final String selectedRole;
  final String selectedOnboardingMode;
  final ValueChanged<String> onOnboardingModeChanged;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SignupStepTitle(
            title: 'Choose account access',
            subtitle:
                'Select the account type that matches how you will use OMC.',
          ),
          const SizedBox(height: 18),
          for (final role in roles) ...[
            SignupRoleCard(
              role: role,
              selected: selectedRole == role,
              onTap: () => onRoleChanged(role),
            ),
            if (role == 'Customer' && selectedRole == 'Customer') ...[
              const SizedBox(height: 12),
              Text(
                'Customer relationship',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 'New Customer',
                    label: Text('New to OMC'),
                  ),
                  ButtonSegment(
                    value: 'Existing Customer Claim',
                    label: Text('Existing customer'),
                  ),
                ],
                selected: {selectedOnboardingMode},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    onOnboardingModeChanged(selection.first);
                  }
                },
              ),
            ],
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
    required this.selectedOnboardingMode,
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
    required this.ntnController,
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
    required this.ntnValidator,
  });

  final GlobalKey<FormState> formKey;
  final String selectedRole;
  final String selectedOnboardingMode;
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
  final TextEditingController ntnController;
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
  final String? Function(String?) ntnValidator;

  @override
  Widget build(BuildContext context) {
    final isTaxAssociate = selectedRole == 'Tax Associate';
    final isExistingCustomerClaim =
        selectedOnboardingMode == 'Existing Customer Claim';

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SignupStepTitle(
            title: 'Basic information',
            subtitle: 'Enter the details OMC needs to identify your account.',
          ),
          const SizedBox(height: 18),
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
            const SizedBox(height: 8),
            _InlineValidationMessage(
              message: usernameMessage!,
              success: usernameAvailable == true,
              error: usernameAvailable == false,
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
          const SizedBox(height: 6),
          CheckboxListTile(
            value: whatsappSameAsMobile,
            onChanged: (value) => onWhatsappSameAsMobileChanged(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Use this number for WhatsApp'),
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
          if (isExistingCustomerClaim) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: ntnController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(7),
              ],
              maxLength: 7,
              decoration: const InputDecoration(
                labelText: 'NTN',
                hintText: '1234567',
                counterText: '',
                prefixIcon: Icon(Icons.business_outlined),
                helperText:
                    'Existing customers may use either CNIC or 7-digit NTN.',
              ),
              validator: ntnValidator,
            ),
          ],
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
            const SizedBox(height: 24),
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
            title: isCustomer
                ? 'Referral and preferences'
                : 'Staff access review',
            subtitle: isCustomer
                ? 'Referral information is optional unless you choose Referral as your source.'
                : 'This is an application. Email verification does not approve or grant staff access.',
          ),
          const SizedBox(height: 18),
          if (!isCustomer)
            const SignupReviewNotice()
          else ...[
            DropdownButtonFormField<String>(
              initialValue: selectedAcquisitionSource,
              isExpanded: true,
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
            const SizedBox(height: 16),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: referralExpanded,
                onExpansionChanged: onReferralExpandedChanged,
                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  side: const BorderSide(color: AppTheme.border),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  side: const BorderSide(color: AppTheme.border),
                ),
                title: Text(
                  'Have a referral code?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: const Text('Add and verify it here.'),
                children: [
                  TextFormField(
                    controller: referralCodeController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9 -]'),
                      ),
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
                      prefixIcon: const Icon(
                        Icons.confirmation_number_outlined,
                      ),
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
                    _InlineValidationMessage(
                      message: referralValidationMessage!,
                      success: referralCodeValid == true,
                      error: referralCodeValid != true,
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
                    ),
                  ),
                ],
              ),
            ),
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
    required this.acceptedTerms,
    required this.onTermsChanged,
  });

  final GlobalKey<FormState> formKey;
  final bool isCustomer;
  final bool acceptedTerms;
  final ValueChanged<bool?>? onTermsChanged;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SignupStepTitle(
            title: isCustomer
                ? 'Review and verify your email'
                : 'Verify and submit your application',
            subtitle: isCustomer
                ? 'OMC will email a single-use verification link. You will create your password only after opening that verified link.'
                : 'OMC will email a single-use verification link. After verification, your staff access application is submitted for separate OMC review.',
          ),
          const SizedBox(height: 18),
          const _SecurityNotice(),
          const SizedBox(height: 14),
          Material(
            color: AppTheme.cardSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: CheckboxListTile(
              value: acceptedTerms,
              onChanged: onTermsChanged,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                isCustomer
                    ? 'I confirm my details are correct and agree to verify my email before my OMC customer account is created.'
                    : 'I confirm my details are correct and understand that email verification submits my staff access application for OMC review; it does not grant staff permissions.',
                style: Theme.of(context).textTheme.bodyMedium,
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
    final stack =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final primary = AppButton(
      label: isLast ? 'Send verification email' : 'Continue',
      icon: isLast
          ? Icons.mark_email_unread_outlined
          : Icons.arrow_forward_rounded,
      isLoading: isSubmitting,
      onPressed: isSubmitting ? null : onContinue,
    );

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: step == 0
            ? primary
            : stack
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  primary,
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isSubmitting ? null : onBack,
                    child: const Text('Back'),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : onBack,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: primary),
                ],
              ),
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
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
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
        'Apply for consultant staff access.',
      ),
      'Business Partner' => (
        Icons.handshake_outlined,
        'Apply for business partner staff access.',
      ),
      'Tax Associate' => (
        Icons.calculate_outlined,
        'Apply for tax associate staff access.',
      ),
      _ => (
        Icons.person_outline_rounded,
        'Create an account to request and track OMC services.',
      ),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: '$role. ${data.$2}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: AnimatedContainer(
          duration: AppMotion.reducedMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.infoSoft : AppTheme.cardSoft,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? AppTheme.info : AppTheme.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                data.$1,
                color: selected ? AppTheme.info : AppTheme.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(data.$2, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppTheme.info : AppTheme.textSecondary,
              ),
            ],
          ),
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
        color: AppTheme.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: AppTheme.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is a staff access application. OMC reviews it separately after email verification, and protected staff permissions are never enabled automatically.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.warning,
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
        Text('Already registered?', style: Theme.of(context).textTheme.bodyMedium),
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
          : 'Staff access application submitted',
      subtitle: isCustomer
          ? 'Your customer account is active. You can sign in now.'
          : 'OMC will review your application before protected staff access is enabled.',
      child: PremiumCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppTheme.success,
              size: 42,
            ),
            const SizedBox(height: 18),
            Text(
              isCustomer
                  ? 'Your account is ready.'
                  : 'We received your application.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              isCustomer
                  ? 'Sign in to request services, upload documents and track your cases.'
                  : 'Staff permissions remain disabled until OMC completes its access review.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Go to login',
              icon: Icons.login_rounded,
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineValidationMessage extends StatelessWidget {
  const _InlineValidationMessage({
    required this.message,
    required this.success,
    required this.error,
  });

  final String message;
  final bool success;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = success
        ? AppTheme.success
        : error
        ? AppTheme.danger
        : AppTheme.textSecondary;
    final icon = success
        ? Icons.check_circle_outline_rounded
        : error
        ? Icons.error_outline_rounded
        : Icons.info_outline_rounded;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.successSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppTheme.success,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No password is collected or stored before email verification. After verification, the secure link asks you to set and confirm a new password.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
