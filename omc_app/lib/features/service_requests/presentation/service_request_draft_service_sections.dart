part of 'service_request_draft_screen.dart';

class _InternalDiscountCard extends StatelessWidget {
  const _InternalDiscountCard({
    required this.service,
    required this.discountType,
    required this.discountValueController,
    required this.discountReasonController,
    required this.onDiscountTypeChanged,
  });

  final ServiceItem service;
  final String discountType;
  final TextEditingController discountValueController;
  final TextEditingController discountReasonController;
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

    String money(double amount) {
      final formatted = amount % 1 == 0
          ? amount.toInt().toString()
          : amount.toStringAsFixed(2);
      return currency.isEmpty ? formatted : '$currency $formatted';
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer discount',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Optional. Available only for internal assisted requests.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: discountType,
            decoration: const InputDecoration(labelText: 'Discount type'),
            items: const [
              DropdownMenuItem(value: 'Percentage', child: Text('Percentage')),
              DropdownMenuItem(
                value: 'Fixed Amount',
                child: Text('Fixed amount'),
              ),
            ],
            onChanged: onDiscountTypeChanged,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: discountValueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: discountType == 'Percentage'
                  ? 'Discount percentage'
                  : 'Discount amount',
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
          const SizedBox(height: 12),
          TextFormField(
            controller: discountReasonController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Discount reason',
              hintText: 'Required when a discount is applied',
            ),
          ),
          if (originalPrice != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _DiscountSummaryRow(
              label: 'Original price',
              value: money(originalPrice),
            ),
            const SizedBox(height: 6),
            _DiscountSummaryRow(
              label: 'Discount',
              value: '- ${money(discountAmount)}',
            ),
            const SizedBox(height: 6),
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
    final style = emphasized
        ? const TextStyle(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _serviceIcon(service.iconKey),
              color: AppTheme.textPrimary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$price  •  $timeline',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 9),
            ),
            child: const Text('Change'),
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
    required this.requiredValidator,
    required this.emailValidator,
    required this.taxIdValidator,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController taxIdController;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?) taxIdValidator;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            title: 'Client details',
            subtitle:
                'Enter the details of the person or business receiving this service.',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) => requiredValidator(value, 'Full name'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Phone or WhatsApp number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) => requiredValidator(value, 'Phone number'),
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          TextFormField(
            controller: taxIdController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'CNIC / NTN (optional)',
              helperText:
                  'CNIC must be 13 digits. NTN should be 7-9 digits if provided.',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: taxIdValidator,
          ),
        ],
      ),
    );
  }
}
