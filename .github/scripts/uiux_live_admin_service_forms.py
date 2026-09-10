from pathlib import Path

admin = Path("omc_app/lib/features/admin_control/presentation/admin_operations_screen.dart")
service = Path("omc_app/lib/features/service_requests/presentation/operational_service_case_detail_screen.dart")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one anchor, found {count}")
    return text.replace(old, new, 1)


def add_import(text, anchor, new_import, label):
    if new_import in text:
        return text
    return replace_once(text, anchor, anchor + new_import, label)


# Admin operations: preserve search field labels; convert only decision-form fields.
a = admin.read_text()
a = add_import(
    a,
    "import '../../../core/widgets/app_back_header.dart';\n",
    "import '../../../core/widgets/app_labeled_field.dart';\n",
    "admin AppLabeledField import",
)

old = """                    DropdownButtonFormField<AdminAssignmentCandidate>(
                      initialValue: selected,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Eligible assignee',
                      ),
                      items: [
                        for (final candidate in candidates)
                          DropdownMenuItem(
                            value: candidate,
                            child: Text(
                              '${candidate.fullName} (${candidate.userId})',
                              softWrap: true,
                              maxLines: 2,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        dirtyFormController.markDirty();
                        setDialogState(() => selected = value);
                      },
                    ),"""
new = """                    AppLabeledField(
                      label: 'Eligible assignee',
                      isRequired: true,
                      child: DropdownButtonFormField<AdminAssignmentCandidate>(
                        initialValue: selected,
                        isExpanded: true,
                        decoration: const InputDecoration(),
                        items: [
                          for (final candidate in candidates)
                            DropdownMenuItem(
                              value: candidate,
                              child: Text(
                                '${candidate.fullName} (${candidate.userId})',
                                softWrap: true,
                                maxLines: 2,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          dirtyFormController.markDirty();
                          setDialogState(() => selected = value);
                        },
                      ),
                    ),"""
a = replace_once(a, old, new, "admin eligible assignee field")

old = """                    TextField(
                      controller: reason,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Reason (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),"""
new = """                    AppLabeledField(
                      label: 'Reason (optional)',
                      child: TextField(
                        controller: reason,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),"""
a = replace_once(a, old, new, "admin reassignment reason field")

old = """                  TextField(
                    controller: remarks,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: approve == false
                          ? 'Review remarks (required)'
                          : 'Review remarks (optional)',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),"""
new = """                  AppLabeledField(
                    label: 'Review remarks',
                    isRequired: approve == false,
                    child: TextField(
                      controller: remarks,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),"""
a = replace_once(a, old, new, "admin discount review remarks")

for forbidden in [
    "labelText: 'Eligible assignee'",
    "labelText: 'Reason (optional)'",
    "labelText: approve == false",
]:
    if forbidden in a:
        raise SystemExit(f"admin form floating label still present: {forbidden}")
if "labelText: 'Search eligible staff'" not in a:
    raise SystemExit("admin search field was unexpectedly changed")
admin.write_text(a)

# Live operational service-case detail: canonical operational presentation only.
s = service.read_text()
s = add_import(
    s,
    "import '../../../core/widgets/app_button.dart';\n",
    "import '../../../core/widgets/app_labeled_field.dart';\n",
    "service AppLabeledField import",
)

old = """    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,"""
new = """    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,"""
s = replace_once(s, old, new, "operational upload sheet safe area")

old = """                  DropdownButtonFormField<ServiceCaseDocument>(
                    initialValue: _selectedDocument,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Document type'),
                    items: widget.documents
                        .map(
                          (document) => DropdownMenuItem(
                            value: document,
                            child: Text(document.title),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isUploading
                        ? null
                        : (document) {
                            if (document == null) return;
                            setState(() {
                              _selectedDocument = document;
                              _errorMessage = null;
                            });
                          },
                  ),"""
new = """                  AppLabeledField(
                    label: 'Document type',
                    isRequired: true,
                    child: DropdownButtonFormField<ServiceCaseDocument>(
                      initialValue: _selectedDocument,
                      isExpanded: true,
                      decoration: const InputDecoration(),
                      items: widget.documents
                          .map(
                            (document) => DropdownMenuItem(
                              value: document,
                              child: Text(document.title),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isUploading
                          ? null
                          : (document) {
                              if (document == null) return;
                              setState(() {
                                _selectedDocument = document;
                                _errorMessage = null;
                              });
                            },
                    ),
                  ),"""
s = replace_once(s, old, new, "operational document type field")

old = """        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Review remarks',
            hintText: 'Explain why this discount cannot be approved.',
          ),
        ),"""
new = """        content: AppLabeledField(
          label: 'Review remarks',
          isRequired: true,
          child: TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Explain why this discount cannot be approved.',
            ),
          ),
        ),"""
s = replace_once(s, old, new, "operational discount review remarks")

if "labelText: 'Document type'" in s or "labelText: 'Review remarks'" in s:
    raise SystemExit("operational form floating label still present")
if "useSafeArea: true" not in s:
    raise SystemExit("operational upload sheet did not retain safe area")
service.write_text(s)
