from pathlib import Path

ROOT = Path('omc_app')


def read(rel):
    return (ROOT / rel).read_text()


def write(rel, text):
    (ROOT / rel).write_text(text)


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 anchor, found {count}')
    return text.replace(old, new, 1)


# Home quick actions: C5 requires the visible action label at 16/600.
rel = 'lib/features/home/presentation/approved_customer_home_actions.dart'
text = read(rel)
text = replace_once(
    text,
    """                                style: const TextStyle(\n                                  color: AppTheme.textPrimary,\n                                  fontSize: 15,\n                                  height: 1.25,\n                                  fontWeight: FontWeight.w600,\n                                ),\n""",
    """                                style: const TextStyle(\n                                  color: AppTheme.textPrimary,\n                                  fontSize: 16,\n                                  height: 1.25,\n                                  fontWeight: FontWeight.w600,\n                                ),\n""",
    'approved home quick action label',
)
write(rel, text)

rel = 'lib/features/home/presentation/customer_guest_home_view.dart'
text = read(rel)
text = replace_once(
    text,
    """                                        style: const TextStyle(\n                                          color: AppTheme.textPrimary,\n                                          fontSize: 15,\n                                          height: 1.25,\n                                          fontWeight: FontWeight.w600,\n                                        ),\n""",
    """                                        style: const TextStyle(\n                                          color: AppTheme.textPrimary,\n                                          fontSize: 16,\n                                          height: 1.25,\n                                          fontWeight: FontWeight.w600,\n                                        ),\n""",
    'guest home quick action label',
)
text = replace_once(
    text,
    """                                          style: const TextStyle(\n                                            color: AppTheme.textSecondary,\n                                            fontSize: 13,\n                                            height: 1.35,\n                                            fontWeight: FontWeight.w500,\n                                          ),\n""",
    """                                          style: const TextStyle(\n                                            color: AppTheme.textSecondary,\n                                            fontSize: 15,\n                                            height: 1.4,\n                                            fontWeight: FontWeight.w400,\n                                          ),\n""",
    'guest home quick action supporting text',
)
write(rel, text)

rel = 'lib/features/home/presentation/internal_home_view.dart'
text = read(rel)
text = replace_once(
    text,
    """                                      style: const TextStyle(\n                                        color: AppTheme.textPrimary,\n                                        fontSize: 15,\n                                        height: 1.25,\n                                        fontWeight: FontWeight.w600,\n                                      ),\n""",
    """                                      style: const TextStyle(\n                                        color: AppTheme.textPrimary,\n                                        fontSize: 16,\n                                        height: 1.25,\n                                        fontWeight: FontWeight.w600,\n                                      ),\n""",
    'internal home quick action label',
)
write(rel, text)

# Dashboard: state labels use status role; timestamp remains caption.
rel = 'lib/features/dashboard/presentation/dashboard_screen.dart'
text = read(rel)
text = replace_once(
    text,
    """                    Text(\n                      serviceCase.documentSummaryLabel.trim(),\n                      style: const TextStyle(\n                        color: AppTheme.textSecondary,\n                        fontSize: 13,\n                        height: 1.35,\n                      ),\n                    ),\n""",
    """                    Text(\n                      serviceCase.documentSummaryLabel.trim(),\n                      style: Theme.of(context).textTheme.labelMedium?.copyWith(\n                        color: AppTheme.textSecondary,\n                      ),\n                    ),\n""",
    'dashboard document state label',
)
text = replace_once(
    text,
    """                      if (status.isNotEmpty)\n                        Text(\n                          status,\n                          style: const TextStyle(\n                            color: AppTheme.textSecondary,\n                            fontSize: 13,\n                            fontWeight: FontWeight.w500,\n                          ),\n                        ),\n""",
    """                      if (status.isNotEmpty)\n                        Text(\n                          status,\n                          style: Theme.of(context).textTheme.labelMedium\n                              ?.copyWith(color: AppTheme.textSecondary),\n                        ),\n""",
    'dashboard recent activity status',
)
write(rel, text)

# Alerts feed: compact action, primary title and supporting message use canonical roles.
rel = 'lib/features/notifications/presentation/notifications_screen.dart'
text = read(rel)
text = replace_once(
    text,
    """                    style: TextStyle(\n                      color: Colors.white,\n                      fontSize: 13,\n                      fontWeight: FontWeight.w700,\n                    ),\n""",
    """                    style: TextStyle(\n                      color: Colors.white,\n                      fontSize: 14,\n                      fontWeight: FontWeight.w500,\n                    ),\n""",
    'notification swipe clear action',
)
text = replace_once(
    text,
    """                              style: TextStyle(\n                                color: AppTheme.textPrimary,\n                                fontSize: 16,\n                                height: 1.3,\n                                fontWeight: item.isRead\n                                    ? FontWeight.w600\n                                    : FontWeight.w700,\n                              ),\n""",
    """                              style: Theme.of(context)\n                                  .textTheme\n                                  .titleMedium\n                                  ?.copyWith(color: AppTheme.textPrimary),\n""",
    'notification primary title',
)
text = replace_once(
    text,
    """                      Text(\n                        item.message,\n                        style: const TextStyle(\n                          color: AppTheme.textSecondary,\n                          fontSize: 14,\n                          height: 1.45,\n                          fontWeight: FontWeight.w500,\n                        ),\n                      ),\n""",
    """                      Text(\n                        item.message,\n                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(\n                          color: AppTheme.textSecondary,\n                        ),\n                      ),\n""",
    'notification supporting message',
)
write(rel, text)

# Payment detail action card: helpers are 14/400, status 14/500, section title 17/600.
rel = 'lib/features/payments/presentation/widgets/payment_action_card.dart'
text = read(rel)
text = replace_once(
    text,
    """              style: const TextStyle(\n                color: AppTheme.textSecondary,\n                fontSize: 13,\n                height: 1.35,\n              ),\n""",
    """              style: const TextStyle(\n                color: AppTheme.textSecondary,\n                fontSize: 14,\n                height: 1.4,\n                fontWeight: FontWeight.w400,\n              ),\n""",
    'payment action helper',
)
text = replace_once(
    text,
    """                style: TextStyle(\n                  color: AppTheme.textSecondary,\n                  fontSize: 13,\n                  height: 1.4,\n                ),\n""",
    """                style: TextStyle(\n                  color: AppTheme.textSecondary,\n                  fontSize: 14,\n                  height: 1.4,\n                  fontWeight: FontWeight.w400,\n                ),\n""",
    'payment proof helper',
)
text = replace_once(
    text,
    """            child: Text(\n              'Payment evidence',\n              style: TextStyle(\n                color: AppTheme.textPrimary,\n                fontSize: 16,\n                fontWeight: FontWeight.w700,\n              ),\n            ),\n""",
    """            child: Text(\n              'Payment evidence',\n              style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                color: AppTheme.textPrimary,\n              ),\n            ),\n""",
    'payment evidence section title',
)
text = replace_once(
    text,
    """                    style: const TextStyle(\n                      color: AppTheme.textPrimary,\n                      fontSize: 14,\n                      fontWeight: FontWeight.w700,\n                    ),\n""",
    """                    style: Theme.of(context).textTheme.labelMedium?.copyWith(\n                      color: AppTheme.textPrimary,\n                    ),\n""",
    'payment upload status',
)
text = replace_once(
    text,
    """              style: TextStyle(\n                color: AppTheme.textSecondary,\n                fontSize: 13,\n                height: 1.4,\n              ),\n""",
    """              style: TextStyle(\n                color: AppTheme.textSecondary,\n                fontSize: 14,\n                height: 1.4,\n                fontWeight: FontWeight.w400,\n              ),\n""",
    'payment upload progress helper',
)
write(rel, text)

# Document preview interaction hint is helper/instructional copy, not caption metadata.
rel = 'lib/features/documents/presentation/document_preview_screen.dart'
text = read(rel)
text = replace_once(
    text,
    """                style: TextStyle(\n                  color: Colors.white70,\n                  fontSize: 13,\n                  height: 1.3,\n                  fontWeight: FontWeight.w600,\n                ),\n""",
    """                style: TextStyle(\n                  color: Colors.white70,\n                  fontSize: 14,\n                  height: 1.35,\n                  fontWeight: FontWeight.w400,\n                ),\n""",
    'document preview helper',
)
write(rel, text)

# Tax rules/deadline pills are meaningful status/instruction labels.
rel = 'lib/features/tax_calculator/presentation/tax_calculator_screen.dart'
text = read(rel)
text = replace_once(
    text,
    """              style: const TextStyle(\n                color: AppTheme.processing,\n                fontSize: 13,\n                height: 1.35,\n              ),\n""",
    """              style: Theme.of(context).textTheme.labelMedium?.copyWith(\n                color: AppTheme.processing,\n              ),\n""",
    'tax info pill status',
)
write(rel, text)

# Operational upload format guidance is helper text; metadata stays caption-sized.
rel = 'lib/features/service_requests/presentation/operational_service_case_detail_screen.dart'
text = read(rel)
text = replace_once(
    text,
    """                    style: TextStyle(\n                      color: AppTheme.textSecondary,\n                      fontSize: 13,\n                      height: 1.35,\n                    ),\n""",
    """                    style: TextStyle(\n                      color: AppTheme.textSecondary,\n                      fontSize: 14,\n                      height: 1.4,\n                      fontWeight: FontWeight.w400,\n                    ),\n""",
    'operational upload helper',
)
write(rel, text)

# Support conversation upload guidance is helper text; message body uses 16/400.
rel = 'lib/features/support/presentation/support_ticket_detail_legacy_screen.dart'
text = read(rel)
text = replace_once(
    text,
    """                    style: const TextStyle(\n                      color: AppTheme.textPrimary,\n                      fontSize: 16,\n                      height: 1.5,\n                      fontWeight: FontWeight.w500,\n                    ),\n""",
    """                    style: const TextStyle(\n                      color: AppTheme.textPrimary,\n                      fontSize: 16,\n                      height: 1.5,\n                      fontWeight: FontWeight.w400,\n                    ),\n""",
    'support message body',
)
text = replace_once(
    text,
    """                style: TextStyle(\n                  color: AppTheme.textSecondary,\n                  fontSize: 13,\n                  height: 1.35,\n                  fontWeight: FontWeight.w500,\n                ),\n""",
    """                style: TextStyle(\n                  color: AppTheme.textSecondary,\n                  fontSize: 14,\n                  height: 1.4,\n                  fontWeight: FontWeight.w400,\n                ),\n""",
    'support attachment helper',
)
write(rel, text)

# FAQ answers are supporting/body copy, not a medium-weight status role.
rel = 'lib/features/support/presentation/support_screen_legacy.dart'
text = read(rel)
text = replace_once(
    text,
    """            style: const TextStyle(\n              color: AppTheme.textSecondary,\n              fontSize: 15,\n              height: 1.5,\n              fontWeight: FontWeight.w500,\n            ),\n""",
    """            style: const TextStyle(\n              color: AppTheme.textSecondary,\n              fontSize: 15,\n              height: 1.5,\n              fontWeight: FontWeight.w400,\n            ),\n""",
    'support faq body',
)
write(rel, text)

# Permanent source contracts for the final semantic role sweep.
test_rel = 'test/app/uiux_final_semantic_roles_contract_test.dart'
test = r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('Home quick action labels use the C5 16px action role', () {
    final approved = source(
      'lib/features/home/presentation/approved_customer_home_actions.dart',
    );
    final guest = source(
      'lib/features/home/presentation/customer_guest_home_view.dart',
    );
    final internal = source(
      'lib/features/home/presentation/internal_home_view.dart',
    );

    expect(approved, contains('fontSize: 16'));
    expect(guest, contains('fontSize: 16'));
    expect(internal, contains('fontSize: 16'));
    expect(guest, contains('fontWeight: FontWeight.w400'));
  });

  test('Dashboard keeps timestamps caption-sized but promotes workflow state', () {
    final dashboard = source(
      'lib/features/dashboard/presentation/dashboard_screen.dart',
    );
    expect(dashboard, contains('textTheme.labelMedium'));
    expect(dashboard, contains('fontSize: 13'));
    expect(
      dashboard,
      isNot(contains("serviceCase.documentSummaryLabel.trim(),\n                      style: const TextStyle")),
    );
  });

  test('Alerts feed uses title, body, status and compact action roles', () {
    final alerts = source(
      'lib/features/notifications/presentation/notifications_screen.dart',
    );
    expect(alerts, contains('.titleMedium'));
    expect(alerts, contains('.bodyMedium'));
    expect(alerts, contains('.labelMedium'));
    expect(alerts, contains('fontSize: 14'));
    expect(alerts, isNot(contains("'Clear',\n                    style: TextStyle(\n                      color: Colors.white,\n                      fontSize: 13")));
  });

  test('Payment and upload guidance no longer use caption typography', () {
    final payment = source(
      'lib/features/payments/presentation/widgets/payment_action_card.dart',
    );
    final operational = source(
      'lib/features/service_requests/presentation/operational_service_case_detail_screen.dart',
    );
    final support = source(
      'lib/features/support/presentation/support_ticket_detail_legacy_screen.dart',
    );
    final preview = source(
      'lib/features/documents/presentation/document_preview_screen.dart',
    );

    expect(payment, contains('textTheme.titleMedium'));
    expect(payment, contains('textTheme.labelMedium'));
    expect(operational, contains("'PDF, JPG, JPEG, PNG, DOC or DOCX · maximum 10 MB'"));
    expect(support, contains("'PDF, JPG, PNG, DOC or DOCX · Maximum 10 MB'"));
    expect(preview, contains("'Pinch to zoom · drag to pan'"));

    for (final text in [operational, support, preview]) {
      expect(text, contains('fontSize: 14'));
    }
  });

  test('Tax rules and deadlines use the 14px status label role', () {
    final tax = source(
      'lib/features/tax_calculator/presentation/tax_calculator_screen.dart',
    );
    expect(tax, contains('textTheme.labelMedium'));
    expect(
      tax,
      isNot(contains("color: AppTheme.processing,\n                fontSize: 13")),
    );
  });

  test('Support conversation body stays at standard body weight', () {
    final detail = source(
      'lib/features/support/presentation/support_ticket_detail_legacy_screen.dart',
    );
    final hub = source(
      'lib/features/support/presentation/support_screen_legacy.dart',
    );
    expect(detail, contains('fontSize: 16'));
    expect(detail, contains('fontWeight: FontWeight.w400'));
    expect(hub, contains('fontSize: 15'));
    expect(hub, contains('fontWeight: FontWeight.w400'));
  });
}
'''
write(test_rel, test)

print('Applied final semantic UI/UX role closure.')
