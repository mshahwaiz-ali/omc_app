part of 'service_request_draft_screen.dart';

class _DynamicFormCard extends StatelessWidget {
  const _DynamicFormCard({
    required this.fields,
    required this.remarksController,
    required this.controllerFor,
    required this.selectValueFor,
    required this.checkedValueFor,
    required this.onSelectChanged,
    required this.onCheckChanged,
    required this.requiredValidator,
  });

  final List<ServiceTemplateField> fields;
  final TextEditingController remarksController;
  final TextEditingController Function(ServiceTemplateField field)
  controllerFor;
  final String? Function(ServiceTemplateField field) selectValueFor;
  final bool Function(ServiceTemplateField field) checkedValueFor;
  final void Function(ServiceTemplateField field, String? value)
  onSelectChanged;
  final void Function(ServiceTemplateField field, bool? value) onCheckChanged;
  final String? Function(String?, String) requiredValidator;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            title: 'Service information',
            subtitle: 'Add the information needed to prepare your case.',
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: 16),
          for (final field in fields) ...[
            _DynamicField(
              field: field,
              controller: controllerFor(field),
              selectValue: selectValueFor(field),
              checkedValue: checkedValueFor(field),
              onSelectChanged: (value) => onSelectChanged(field, value),
              onCheckChanged: (value) => onCheckChanged(field, value),
              requiredValidator: requiredValidator,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: remarksController,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Additional notes (optional)',
              hintText: 'Add anything else OMC should know.',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicField extends StatelessWidget {
  const _DynamicField({
    required this.field,
    required this.controller,
    required this.selectValue,
    required this.checkedValue,
    required this.onSelectChanged,
    required this.onCheckChanged,
    required this.requiredValidator,
  });

  final ServiceTemplateField field;
  final TextEditingController controller;
  final String? selectValue;
  final bool checkedValue;
  final ValueChanged<String?> onSelectChanged;
  final ValueChanged<bool?> onCheckChanged;
  final String? Function(String?, String) requiredValidator;

  @override
  Widget build(BuildContext context) {
    final label = field.label.trim().isEmpty
        ? field.fieldname
        : field.label.trim();
    final helperText = field.description.trim().isEmpty
        ? null
        : field.description.trim();

    if (_isCheckField(field)) {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: checkedValue,
        onChanged: onCheckChanged,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: helperText == null ? null : Text(helperText),
        controlAffinity: ListTileControlAffinity.leading,
      );
    }

    if (_isSelectField(field) && field.options.isNotEmpty) {
      final selected = field.options.contains(selectValue) ? selectValue : null;
      return DropdownButtonFormField<String>(
        initialValue: selected,
        items: field.options
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(growable: false),
        onChanged: onSelectChanged,
        decoration: InputDecoration(
          labelText: field.isRequired ? '$label *' : label,
          helperText: helperText,
          prefixIcon: const Icon(Icons.list_alt_outlined),
        ),
        validator: field.isRequired
            ? (value) => requiredValidator(value, label)
            : null,
      );
    }

    return TextFormField(
      controller: controller,
      minLines: _isLongTextField(field) ? 3 : 1,
      maxLines: _isLongTextField(field) ? 5 : 1,
      keyboardType: _keyboardTypeFor(field),
      inputFormatters: _inputFormattersFor(field),
      textInputAction: _isLongTextField(field)
          ? TextInputAction.newline
          : TextInputAction.next,
      decoration: InputDecoration(
        labelText: field.isRequired ? '$label *' : label,
        hintText: field.placeholder.trim().isEmpty
            ? null
            : field.placeholder.trim(),
        helperText: helperText,
        alignLabelWithHint: _isLongTextField(field),
        prefixIcon: Icon(_iconFor(field)),
      ),
      validator: field.isRequired
          ? (value) => requiredValidator(value, label)
          : null,
    );
  }
}

class _StagesCard extends StatelessWidget {
  const _StagesCard({required this.stages});

  final List<ServiceStageTemplate> stages;

  @override
  Widget build(BuildContext context) {
    final visibleStages =
        stages.where((stage) => stage.isCustomerVisible).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (visibleStages.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.route_outlined,
            color: Color(0xFF7C3AED),
            size: 19,
          ),
        ),
        title: const Text(
          'What happens next',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          '${visibleStages.length} service stage${visibleStages.length == 1 ? '' : 's'}',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          for (var index = 0; index < visibleStages.length; index++)
            _CompactStageRow(
              number: index + 1,
              stage: visibleStages[index],
              isLast: index == visibleStages.length - 1,
            ),
        ],
      ),
    );
  }
}

class _CompactStageRow extends StatelessWidget {
  const _CompactStageRow({
    required this.number,
    required this.stage,
    required this.isLast,
  });

  final int number;
  final ServiceStageTemplate stage;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0ECFF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: const Color(0xFFE2E6ED),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 2 : 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (stage.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      stage.description.trim(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredDocumentsCard extends StatelessWidget {
  const _RequiredDocumentsCard({required this.documents});

  final List<String> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            title: 'Documents you may need',
            subtitle:
                'Submit the request now. OMC will ask for documents from the case screen when they are required.',
            icon: Icons.folder_copy_outlined,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7EAF0)),
            ),
            child: Column(
              children: [
                for (var index = 0; index < documents.length; index++) ...[
                  Row(
                    children: [
                      Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF16A34A,
                          ).withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF16A34A),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          documents[index],
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (index != documents.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xFFE5E9EF)),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitRequestBar extends StatelessWidget {
  const _SubmitRequestBar({
    required this.service,
    required this.completedFields,
    required this.totalFields,
    required this.attachmentCount,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final ServiceItem service;
  final int completedFields;
  final int totalFields;
  final int attachmentCount;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final _ = service;
    final remaining = (totalFields - completedFields).clamp(0, totalFields);
    final statusText = remaining == 0
        ? attachmentCount == 0
              ? 'Ready to submit'
              : '$attachmentCount file${attachmentCount == 1 ? '' : 's'} attached'
        : '$remaining detail${remaining == 1 ? '' : 's'} remaining';

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useStackedLayout =
                  constraints.maxWidth < 390 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4;
              final status = Text(
                statusText,
                maxLines: useStackedLayout ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              );
              final button = AppButton(
                label: 'Submit',
                icon: Icons.arrow_forward_rounded,
                isLoading: isSubmitting,
                onPressed: isSubmitting ? null : onSubmit,
              );

              if (useStackedLayout) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [status, const SizedBox(height: 8), button],
                );
              }

              return Row(
                children: [
                  Expanded(child: status),
                  const SizedBox(width: 12),
                  SizedBox(width: 174, child: button),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: AppTheme.textSecondary, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

IconData _serviceIcon(String? key) {
  return switch ((key ?? '').trim().toLowerCase()) {
    'business_setup' => Icons.domain_add_outlined,
    'company_registration' => Icons.apartment_outlined,
    'tax_filing' => Icons.receipt_long_outlined,
    'tax_registration' => Icons.how_to_reg_outlined,
    'gst' => Icons.request_quote_outlined,
    'accounting' => Icons.calculate_outlined,
    'audit' => Icons.fact_check_outlined,
    'payroll' => Icons.groups_outlined,
    'legal' => Icons.gavel_outlined,
    _ => Icons.work_outline_rounded,
  };
}

bool _isSelectField(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  return type == 'select' || type == 'autocomplete' || type == 'link';
}

bool _isCheckField(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  return type == 'check' || type == 'checkbox' || type == 'boolean';
}

bool _isLongTextField(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  return type.contains('text') ||
      type == 'textarea' ||
      type == 'long text' ||
      type == 'small text';
}

TextInputType _keyboardTypeFor(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  final name = field.fieldname.trim().toLowerCase();
  if (type.contains('email') || name.contains('email')) {
    return TextInputType.emailAddress;
  }
  if (type.contains('phone') ||
      name.contains('phone') ||
      name.contains('mobile')) {
    return TextInputType.phone;
  }
  if (type.contains('int') ||
      type.contains('currency') ||
      type.contains('float') ||
      type.contains('number')) {
    return TextInputType.number;
  }
  if (_isLongTextField(field)) return TextInputType.multiline;
  return TextInputType.text;
}

List<TextInputFormatter> _inputFormattersFor(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  if (type.contains('int') || type == 'number') {
    return [FilteringTextInputFormatter.digitsOnly];
  }
  return const [];
}

IconData _iconFor(ServiceTemplateField field) {
  final type = field.fieldtype.trim().toLowerCase();
  final name = field.fieldname.trim().toLowerCase();
  if (type.contains('date') || name.contains('date')) {
    return Icons.event_outlined;
  }
  if (type.contains('email') || name.contains('email')) {
    return Icons.email_outlined;
  }
  if (type.contains('phone') || name.contains('phone')) {
    return Icons.phone_outlined;
  }
  if (type.contains('currency') ||
      name.contains('amount') ||
      name.contains('fee')) {
    return Icons.payments_outlined;
  }
  if (type.contains('int') || type.contains('number')) {
    return Icons.numbers_outlined;
  }
  if (_isLongTextField(field)) return Icons.notes_outlined;
  return Icons.edit_outlined;
}
