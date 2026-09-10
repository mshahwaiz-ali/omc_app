from pathlib import Path


def add_import(path):
    p = Path(path)
    text = p.read_text()
    imp = "import '../../../core/widgets/app_labeled_field.dart';\n"
    anchor = "import '../../../app/theme.dart';\n"
    if imp in text:
        raise SystemExit(f'{path}: AppLabeledField import already present')
    if text.count(anchor) != 1:
        raise SystemExit(
            f'{path}: expected one theme import anchor, found {text.count(anchor)}'
        )
    p.write_text(text.replace(anchor, anchor + imp, 1))


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: {label}: expected one anchor, found {count}')
    p.write_text(text.replace(old, new, 1))
    print(f'{path}: {label}')


document = (
    'omc_app/lib/features/documents/presentation/'
    'internal_document_review_screen.dart'
)
admin = 'omc_app/lib/features/admin_control/presentation/admin_control_screen.dart'
add_import(document)
add_import(admin)

replace_once(
    document,
    """            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              onChanged: (_) => setDialogState(() {}),
              decoration: const InputDecoration(
                labelText: 'Reason / reupload instruction',
                hintText:
                    'Example: CNIC image is unclear. Please upload again.',
              ),
            ),
""",
    """            content: AppLabeledField(
              label: 'Reason / reupload instruction',
              isRequired: true,
              child: TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  hintText:
                      'Example: CNIC image is unclear. Please upload again.',
                ),
              ),
            ),
""",
    'document rejection reason',
)

replace_once(
    document,
    """          DropdownButtonFormField<String>(
            initialValue: selectedCustomerProfile ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Customer',
              prefixIcon: Icon(Icons.person_search_rounded),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All customers'),
              ),
              for (final option in customerOptions)
                DropdownMenuItem<String>(
                  value: option.profile,
                  child: Text(
                    [
                      option.label,
                      if (option.email?.trim().isNotEmpty == true)
                        option.email!.trim(),
                    ].join(' · '),
                  ),
                ),
            ],
            onChanged: (value) => onCustomerSelected(
              value == null || value.isEmpty ? null : value,
            ),
          ),
""",
    """          AppLabeledField(
            label: 'Customer',
            child: DropdownButtonFormField<String>(
              initialValue: selectedCustomerProfile ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_search_rounded),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('All customers'),
                ),
                for (final option in customerOptions)
                  DropdownMenuItem<String>(
                    value: option.profile,
                    child: Text(
                      [
                        option.label,
                        if (option.email?.trim().isNotEmpty == true)
                          option.email!.trim(),
                      ].join(' · '),
                    ),
                  ),
              ],
              onChanged: (value) => onCustomerSelected(
                value == null || value.isEmpty ? null : value,
              ),
            ),
          ),
""",
    'customer filter',
)

replace_once(
    document,
    """          DropdownButtonFormField<String>(
            initialValue: selectedDocumentType ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Document type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All document types'),
              ),
              for (final option in documentTypeOptions)
                DropdownMenuItem<String>(value: option, child: Text(option)),
            ],
            onChanged: (value) => onDocumentTypeSelected(
              value == null || value.isEmpty ? null : value,
            ),
          ),
""",
    """          AppLabeledField(
            label: 'Document type',
            child: DropdownButtonFormField<String>(
              initialValue: selectedDocumentType ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('All document types'),
                ),
                for (final option in documentTypeOptions)
                  DropdownMenuItem<String>(value: option, child: Text(option)),
              ],
              onChanged: (value) => onDocumentTypeSelected(
                value == null || value.isEmpty ? null : value,
              ),
            ),
          ),
""",
    'document type filter',
)

replace_once(
    document,
    """          DropdownButtonFormField<String>(
            initialValue: selectedGroup.reference,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Service request',
              prefixIcon: Icon(Icons.folder_open_rounded),
            ),
            items: groups
                .map(
                  (group) => DropdownMenuItem<String>(
                    value: group.reference,
                    child: Text('${group.customerName} · ${group.reference}'),
                  ),
                )
                .toList(),
            onChanged: onSelected,
          ),
""",
    """          AppLabeledField(
            label: 'Service request',
            child: DropdownButtonFormField<String>(
              initialValue: selectedGroup.reference,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.folder_open_rounded),
              ),
              items: groups
                  .map(
                    (group) => DropdownMenuItem<String>(
                      value: group.reference,
                      child: Text('${group.customerName} · ${group.reference}'),
                    ),
                  )
                  .toList(),
              onChanged: onSelected,
            ),
          ),
""",
    'service request selector',
)

replace_once(
    admin,
    """                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Existing staff full name',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Existing staff login email',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
""",
    """                  AppLabeledField(
                    label: 'Existing staff full name',
                    isRequired: true,
                    child: TextField(
                      controller: name,
                      decoration: const InputDecoration(),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppLabeledField(
                    label: 'Existing staff login email',
                    isRequired: true,
                    child: TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),
""",
    'staff identity fields',
)

replace_once(
    admin,
    """                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Value',
                      prefixText: unit == '%' ? null : '$unit ',
                      suffixText: unit == '%' ? '%' : null,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
""",
    """                  AppLabeledField(
                    label: 'Value',
                    isRequired: true,
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        prefixText: unit == '%' ? null : '$unit ',
                        suffixText: unit == '%' ? '%' : null,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),
""",
    'business setting value',
)
