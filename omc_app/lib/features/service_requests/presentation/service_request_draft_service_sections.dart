part of 'service_request_draft_screen.dart';

class _InternalDiscountCard extends StatelessWidget {
  const _InternalDiscountCard({
    required this.service,
    required this.discountType,
    required this.discountValueController,
    required this.discountReasonController,
    required this.discountValueFocusNode,
    required this.discountReasonFocusNode,
    required this.onDiscountTypeChanged,
  });

  final ServiceItem service;
  final String discountType;
  final TextEditingController discountValueController;
  final TextEditingController discountReasonController;
  final FocusNode discountValueFocusNode;
  final FocusNode discountReasonFocusNode;
  final ValueChanged<String?> onDiscountTypeChanged;

  @override
  Widget build(BuildContext context) {
    final originalPrice = service.basePrice;
    final value =
        double.tryParse(discountValueController.text.replaceAll(',', '')) ?? 0;
    final discountAmount = originalPrice == null || originalPrice <= 0
        ? 0.0
        : discountType == 'Percentage'
        ? originalPrice * (value.clamp(0, 100) / 100)
        : value.clamp(0, originalPrice).toDouble();
    final finalPrice = originalPrice == null
        ? null
        : (originalPrice - discountAmount).clamp(0, double.infinity).toDouble();
    final currency = (service.currency ?? '').trim();
    final theme = Theme.of(context);

    String money(double amount) {
      final formatted = amount % 1 == 0
          ? amount.toInt().toString()
          : amount.toStringAsFixed(2);
      return currency.isEmpty ? formatted : '$currency $formatted';
    }

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            title: 'Customer discount',
            subtitle:
                'Optional. Available only for internal assisted requests.',
            icon: Icons.sell_outlined,
          ),
          const SizedBox(height: 18),
          Text('Discount type', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: discountType,
            isExpanded: true,
            decoration: const InputDecoration(hintText: 'Choose discount type'),
            items: const [
              DropdownMenuItem(value: 'Percentage', child: Text('Percentage')),
              DropdownMenuItem(
                value: 'Fixed Amount',
                child: Text('Fixed amount'),
              ),
            ],
            onChanged: onDiscountTypeChanged,
          ),
          const SizedBox(height: 16),
          Text(
            discountType == 'Percentage'
                ? 'Discount percentage'
                : 'Discount amount',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: discountValueController,
            focusNode: discountValueFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              hintText: discountType == 'Percentage'
                  ? 'Enter percentage'
                  : 'Enter amount',
              suffixText: discountType == 'Percentage' ? '%' : currency,
            ),
            validator: (value) {
              final clean = (value ?? '').trim().replaceAll(',', '');
              if (clean.isEmpty) return null;
              final parsed = double.tryParse(clean);
              if (parsed == null || parsed < 0) {
                return 'Enter a valid non-negative discount.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text('Discount reason', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: discountReasonController,
            focusNode: discountReasonFocusNode,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Required when a discount is applied',
            ),
          ),
          if (originalPrice != null) ...[
            const SizedBox(height: 18),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 14),
            _DiscountSummaryRow(
              label: 'Original price',
              value: money(originalPrice),
            ),
            const SizedBox(height: 8),
            _DiscountSummaryRow(
              label: 'Discount',
              value: '- ${money(discountAmount)}',
            ),
            const SizedBox(height: 8),
            _DiscountSummaryRow(
              label: 'Final price',
              value: money(finalPrice ?? originalPrice),
              emphasized: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscountSummaryRow extends StatelessWidget {
  const _DiscountSummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: AppTheme.textSecondary,
      fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
    );
    final valueStyle =
        (emphasized ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
            ?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
            );
    final stack = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 3),
          Text(value, style: valueStyle),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(value, textAlign: TextAlign.end, style: valueStyle),
        ),
      ],
    );
  }
}

class _SelectedServiceCard extends StatelessWidget {
  const _SelectedServiceCard({required this.service, required this.onChange});

  final ServiceItem service;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final timeline = service.completionTime.trim().isEmpty
        ? 'Timeline to be confirmed'
        : service.completionTime.trim();
    final price = service.priceLabel.trim().isEmpty
        ? 'Fee to be confirmed'
        : service.priceLabel.trim();
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    Widget serviceInfo() => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          alignment: Alignment.center,
          child: Icon(
            _serviceIcon(service.iconKey),
            color: accent,
            size: 23,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected service',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                service.title,
                softWrap: true,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RequestMetaChip(icon: Icons.payments_outlined, label: price),
                  _RequestMetaChip(
                    icon: Icons.schedule_outlined,
                    label: timeline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 350 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.4;

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                serviceInfo(),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: onChange,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Change service'),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: serviceInfo()),
              const SizedBox(width: 12),
              TextButton(onPressed: onChange, child: const Text('Change')),
            ],
          );
        },
      ),
    );
  }
}

class _RequestMetaChip extends StatelessWidget {
  const _RequestMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactDetailsCard extends StatelessWidget {
  const _ContactDetailsCard({
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.taxIdController,
    required this.nameFocusNode,
    required this.phoneFocusNode,
    required this.emailFocusNode,
    required this.taxIdFocusNode,
    required this.requiredValidator,
    required this.emailValidator,
    required this.taxIdValidator,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController taxIdController;
  final FocusNode nameFocusNode;
  final FocusNode phoneFocusNode;
  final FocusNode emailFocusNode;
  final FocusNode taxIdFocusNode;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?) taxIdValidator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            title: 'Contact details',
            subtitle:
                'Confirm the person or business contact OMC should use for this request.',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 18),
          Text('Full name', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: nameController,
            focusNode: nameFocusNode,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              hintText: 'Enter full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) => requiredValidator(value, 'Full name'),
          ),
          const SizedBox(height: 16),
          Text('Phone or WhatsApp number', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: phoneController,
            focusNode: phoneFocusNode,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              hintText: 'Enter phone or WhatsApp number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) => requiredValidator(value, 'Phone number'),
          ),
          const SizedBox(height: 16),
          Text('Email', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: emailController,
            focusNode: emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              hintText: 'Enter email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: emailValidator,
          ),
          const SizedBox(height: 16),
          Text('CNIC / NTN (optional)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: taxIdController,
            focusNode: taxIdFocusNode,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Enter CNIC or NTN',
              helperText:
                  'CNIC must be 13 digits. NTN should be 7–9 digits if provided.',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: taxIdValidator,
          ),
        ],
      ),
    );
  }
}
