from pathlib import Path


def replace(path: str, old: str, new: str, expected: int = 1) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{path}: expected {expected} match(es), found {count}")
    file.write_text(text.replace(old, new, expected), encoding="utf-8")


def replace_between(path: str, start: str, end: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    a = text.find(start)
    if a < 0:
        raise SystemExit(f"{path}: start marker not found: {start!r}")
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f"{path}: end marker not found: {end!r}")
    file.write_text(text[:a] + new + text[b:], encoding="utf-8")


# Catalogue reconciliation preserves the service's configured activation authority.
path = "backend_omc_app/frappe-bench/apps/omc_app/omc_app/setup/service_catalogue/provisioner.py"
replace(
    path,
    '''    current_tax_rate = _number(
        current.get("tax_rate")
    )

    pending_expiry = int(''',
    '''    current_tax_rate = _number(
        current.get("tax_rate")
    )
    current_activation_policy = (
        _text(current.get("activation_policy"))
        or ACTIVATION_POLICY
    )

    pending_expiry = int(''',
)
replace(
    path,
    '''        "activation_policy": ACTIVATION_POLICY,''',
    '''        # Existing payment/activation authority is deliberately preserved.
        "activation_policy": current_activation_policy,''',
)

# Verified Payment changes when work may start, not whether the receivable is settled.
path = "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/workflow_automation.py"
replace(
    path,
    '''    allowed_statuses = {"Paid"}
    if policy == "Verified Payment":
        allowed_statuses.add("Partially Paid")

    return not active_payments or all(
        str(getattr(payment, "status", None) or "").strip()
        in allowed_statuses
        for payment in active_payments
    )''',
    '''    # Verified Payment changes the activation threshold only. A charged
    # service is not financially complete until ERP reconciliation projects Paid.
    return not active_payments or all(
        str(getattr(payment, "status", None) or "").strip() == "Paid"
        for payment in active_payments
    )''',
)

path = "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/test_payment_policy_completion.py"
replace(
    path,
    '''    def test_verified_payment_allows_completion_after_partial_settlement_projection(self):
        blockers = self._blockers(
            self._case("Verified Payment"),
            "Partially Paid",
        )

        self.assertNotIn(
            "Required payment has not been confirmed.",
            blockers,
        )''',
    '''    def test_verified_payment_still_requires_full_settlement_for_completion(self):
        blockers = self._blockers(
            self._case("Verified Payment"),
            "Partially Paid",
        )

        self.assertIn(
            "Required payment has not been confirmed.",
            blockers,
        )

    def test_verified_payment_allows_completion_after_paid_projection(self):
        blockers = self._blockers(
            self._case("Verified Payment"),
            "Paid",
        )

        self.assertNotIn(
            "Required payment has not been confirmed.",
            blockers,
        )''',
)

# Customer lifecycle keeps activated work in processing while showing outstanding balance.
path = "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/customer_lifecycle.py"
replace(
    path,
    '''    payment_complete = (
        payment_not_required
        or request_state in _PAYMENT_COMPLETE_STATES
        or settlement_state in _SETTLED_STATES
    )''',
    '''    partial_payment = (
        payment_state == "partially paid"
        or settlement_state == "partially settled"
    )
    payment_complete = (
        payment_not_required
        or settlement_state in _SETTLED_STATES
        or (request_state in _PAYMENT_COMPLETE_STATES and not partial_payment)
    )''',
)
replace(
    path,
    '''    elif payment_complete:
        payment_milestone = _milestone(
            "payment",
            "Payment",
            "complete",
            "Payment requirements are complete.",
        )
    elif request_state == "pending payment" and receipt_rejected:''',
    '''    elif payment_complete:
        payment_milestone = _milestone(
            "payment",
            "Payment",
            "complete",
            "Payment requirements are complete.",
        )
    elif partial_payment:
        payment_milestone = _milestone(
            "payment",
            "Payment",
            "current",
            "Partial payment is verified. The remaining balance is still due.",
        )
    elif request_state == "pending payment" and receipt_rejected:''',
)

# Older internal projection recognizes partial financial state but does not regress Activated work.
path = "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/workflow_contract.py"
replace(
    path,
    'PAYMENT_STATUSES = ("Pending", "Receipt Submitted", "Under Review", "Paid", "Rejected", "Cancelled")',
    'PAYMENT_STATUSES = ("Pending", "Receipt Submitted", "Under Review", "Partially Paid", "Paid", "Rejected", "Cancelled")',
)
replace(
    path,
    '''    status = normalize_service_status(case.get("status"))
    required = _number(case.get("required_documents_count"))''',
    '''    status = normalize_service_status(case.get("status"))
    request_state = _text(case.get("request_state")).lower()
    required = _number(case.get("required_documents_count"))''',
)
replace(
    path,
    '''    elif not payment_complete or status == "Waiting for Payment":
        stage = "payment"
        progress = 50 + round((paid_payments / active_payments if active_payments else 0) * 20)
    else:
        stage, progress = "processing", (85 if status == "In Progress" else 75)''',
    '''    elif request_state == "activated":
        stage, progress, next_action = "processing", 85, None
        customer_action = False
    elif not payment_complete or status == "Waiting for Payment":
        stage = "payment"
        progress = 50 + round((paid_payments / active_payments if active_payments else 0) * 20)
    else:
        stage, progress = "processing", (85 if status == "In Progress" else 75)''',
)

path = "backend_omc_app/frappe-bench/apps/omc_app/omc_app/api/internal_workspace.py"
replace(
    path,
    '''            "status": operational_status,
            "required_documents_count": doc_summary["required"],''',
    '''            "status": operational_status,
            "request_state": request_state,
            "required_documents_count": doc_summary["required"],''',
)

# Flutter payment status and mapping.
path = "omc_app/lib/features/payments/data/payment_item.dart"
replace(path, "  underReview,\n  paid,", "  underReview,\n  partiallyPaid,\n  paid,")
replace(
    path,
    '''  bool get requiresAction =>
      status == PaymentStatus.pending ||
      status == PaymentStatus.rejected ||
      status == PaymentStatus.overdue;''',
    '''  bool get requiresAction =>
      status == PaymentStatus.pending ||
      status == PaymentStatus.partiallyPaid ||
      status == PaymentStatus.rejected ||
      status == PaymentStatus.overdue;''',
)
replace(
    path,
    '''      case PaymentStatus.underReview:
        return 'Under Review';
      case PaymentStatus.paid:''',
    '''      case PaymentStatus.underReview:
        return 'Under Review';
      case PaymentStatus.partiallyPaid:
        return 'Partially Paid';
      case PaymentStatus.paid:''',
)

path = "omc_app/lib/core/config/api_config.dart"
replace(
    path,
    '''  static const String reviewPaymentReceiptMethod =
      'omc_app.api.payments.review_payment_receipt';''',
    '''  static const String reviewPaymentReceiptMethod =
      'omc_app.api.payments.review_payment_receipt';
  static const String paymentReviewContextMethod =
      'omc_app.api.payment_accounting.get_review_context';''',
)

path = "omc_app/lib/features/payments/data/payments_repository.dart"
replace(
    path,
    '''import 'payment_item.dart';''',
    '''import 'payment_item.dart';
import 'payment_review_context.dart';''',
)
replace(
    path,
    '''    return _mapPaymentDetailResponse(response);
  }

  Future<PaymentItem?> reviewPaymentReceipt({''',
    '''    return _mapPaymentDetailResponse(response);
  }

  Future<PaymentReviewContext> fetchPaymentReviewContext(String paymentId) async {
    final cleanPaymentId = paymentId.trim();
    if (cleanPaymentId.isEmpty) {
      throw const ApiError(message: 'Missing payment reference for review.');
    }

    final response = await _frappeClient.getMethod(
      ApiConfig.paymentReviewContextMethod,
      queryParameters: {'payment_id': cleanPaymentId, 'name': cleanPaymentId},
    );
    final payload = response['message'] is Map<String, dynamic>
        ? response['message'] as Map<String, dynamic>
        : response;
    final rawAccounts = payload['payment_accounts'];
    final accounts = rawAccounts is List
        ? rawAccounts
              .whereType<Map<String, dynamic>>()
              .map(PaymentReviewAccount.fromJson)
              .toList(growable: false)
        : const <PaymentReviewAccount>[];

    return PaymentReviewContext(
      currency: _stringValue(payload['currency']),
      remainingAmount: _doubleValue(payload['remaining_amount']),
      accounts: accounts,
    );
  }

  Future<PaymentItem?> reviewPaymentReceipt({''',
)
replace(
    path,
    '''    String? remarks,
    String? paymentReference,
  }) async {''',
    '''    String? remarks,
    String? paymentReference,
    double? verifiedAmount,
    String? paymentAccount,
  }) async {''',
)
replace(
    path,
    '''    if (paymentReference != null) {
      data['payment_reference'] = paymentReference;
    }

    final response = await _frappeClient.postMethod(''',
    '''    if (paymentReference != null) {
      data['payment_reference'] = paymentReference;
    }
    if (verifiedAmount != null) {
      data['verified_amount'] = verifiedAmount;
    }
    if (paymentAccount != null && paymentAccount.trim().isNotEmpty) {
      data['payment_account'] = paymentAccount.trim();
    }

    final response = await _frappeClient.postMethod(''',
)
replace(
    path,
    '''  int _intValue(dynamic value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }''',
    '''  int _intValue(dynamic value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }''',
)
replace(
    path,
    '''    if (status.contains('under review') || status.contains('review')) {
      return PaymentStatus.underReview;
    }''',
    '''    if (status.contains('under review') || status.contains('review')) {
      return PaymentStatus.underReview;
    }
    if (status.contains('partially paid') ||
        status.contains('partial paid') ||
        status.contains('partially_paid')) {
      return PaymentStatus.partiallyPaid;
    }''',
)

path = "omc_app/lib/features/payments/presentation/widgets/payment_action_card.dart"
replace(
    path,
    '''      case PaymentStatus.receiptSubmitted:
      case PaymentStatus.underReview:
        return 'Payment proof has been submitted and is awaiting OMC verification. No paid status is implied yet.';
      case PaymentStatus.paid:''',
    '''      case PaymentStatus.receiptSubmitted:
      case PaymentStatus.underReview:
        return 'Payment proof has been submitted and is awaiting OMC verification. No paid status is implied yet.';
      case PaymentStatus.partiallyPaid:
        return 'A verified partial payment has been reconciled. The remaining balance is still due.';
      case PaymentStatus.paid:''',
)

path = "omc_app/lib/features/payments/presentation/payments_screen.dart"
replace(
    path,
    '''      case PaymentStatus.pending:
        return 2;
      case PaymentStatus.receiptSubmitted:
        return 3;
      case PaymentStatus.underReview:
        return 4;
      case PaymentStatus.paid:
        return 5;
      case PaymentStatus.cancelled:
        return 6;''',
    '''      case PaymentStatus.partiallyPaid:
        return 2;
      case PaymentStatus.pending:
        return 3;
      case PaymentStatus.receiptSubmitted:
        return 4;
      case PaymentStatus.underReview:
        return 5;
      case PaymentStatus.paid:
        return 6;
      case PaymentStatus.cancelled:
        return 7;''',
)
replace(
    path,
    '''    case PaymentStatus.receiptSubmitted:
    case PaymentStatus.underReview:
      return (color: AppTheme.info, icon: Icons.hourglass_top_rounded);
    case PaymentStatus.paid:''',
    '''    case PaymentStatus.receiptSubmitted:
    case PaymentStatus.underReview:
      return (color: AppTheme.info, icon: Icons.hourglass_top_rounded);
    case PaymentStatus.partiallyPaid:
      return (
        color: AppTheme.warning,
        icon: Icons.account_balance_wallet_outlined,
      );
    case PaymentStatus.paid:''',
)
replace(
    path,
    '''    case PaymentStatus.receiptSubmitted:
    case PaymentStatus.underReview:
      return (
        label: 'View status',
        message: 'Your receipt is with OMC for verification.',
        icon: Icons.manage_search_rounded,
      );
    case PaymentStatus.paid:''',
    '''    case PaymentStatus.receiptSubmitted:
    case PaymentStatus.underReview:
      return (
        label: 'View status',
        message: 'Your receipt is with OMC for verification.',
        icon: Icons.manage_search_rounded,
      );
    case PaymentStatus.partiallyPaid:
      return (
        label: 'Pay balance',
        message: 'A partial payment is verified; the remaining balance is still due.',
        icon: Icons.account_balance_wallet_outlined,
      );
    case PaymentStatus.paid:''',
)

# Payment detail uses explicit Verify Receipt semantics and a state-owned dialog.
path = "omc_app/lib/features/payments/presentation/payment_detail_screen.dart"
replace(
    path,
    '''import '../data/payment_item.dart';
import '../data/payments_repository.dart';
import 'widgets/payment_action_card.dart';''',
    '''import '../data/payment_item.dart';
import '../data/payment_review_context.dart';
import '../data/payments_repository.dart';
import 'payment_review_dialog.dart';
import 'widgets/payment_action_card.dart';''',
)
replace(
    path,
    '''    case PaymentStatus.underReview:
      return (
        color: AppTheme.info,
        icon: Icons.manage_search_rounded,
        title: 'Payment under review',
        message:
            'OMC is reviewing the submitted proof. The payment is not presented as verified until its status changes to Paid.',
      );
    case PaymentStatus.paid:''',
    '''    case PaymentStatus.underReview:
      return (
        color: AppTheme.info,
        icon: Icons.manage_search_rounded,
        title: 'Payment under review',
        message:
            'OMC is reviewing the submitted proof. Payment remains unverified until ERP accounting reconciles it.',
      );
    case PaymentStatus.partiallyPaid:
      return (
        color: AppTheme.warning,
        icon: Icons.account_balance_wallet_outlined,
        title: 'Payment partially settled',
        message:
            'A verified payment has been reconciled. The remaining balance is still due.',
      );
    case PaymentStatus.paid:''',
)
replace_between(
    path,
    "class _PaymentAdminReviewCard extends StatelessWidget {",
    "class _PaymentDetailBody extends ConsumerStatefulWidget {",
    '''class _PaymentAdminReviewCard extends StatelessWidget {
  const _PaymentAdminReviewCard({
    required this.payment,
    required this.isReviewing,
    required this.onReview,
  });

  final PaymentItem payment;
  final bool isReviewing;
  final ValueChanged<String>? onReview;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Payment review',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Verify the amount actually received. ERPNext creates and reconciles the accounting records; this action never marks an unsettled balance as fully paid.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 350 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4;
              final reject = OutlinedButton.icon(
                onPressed: isReviewing || onReview == null
                    ? null
                    : () => onReview?.call('Rejected'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Reject proof'),
              );
              final verify = FilledButton.icon(
                onPressed: isReviewing || onReview == null
                    ? null
                    : () => onReview?.call('Verified'),
                icon: isReviewing
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_rounded),
                label: Text(isReviewing ? 'Preparing' : 'Verify receipt'),
              );

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [verify, const SizedBox(height: 8), reject],
                );
              }

              return Row(
                children: [
                  Expanded(child: reject),
                  const SizedBox(width: 10),
                  Expanded(child: verify),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

''',
)
replace_between(
    path,
    "  Future<void> _reviewPaymentReceipt(\n",
    "  Future<void> _openAuthenticatedInvoice(",
    '''  Future<void> _reviewPaymentReceipt(
    BuildContext context,
    String status,
  ) async {
    if (_isReviewingReceipt) return;
    final repository = ref.read(paymentsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    PaymentReviewContext? reviewContext;

    if (status == 'Verified') {
      setState(() => _isReviewingReceipt = true);
      try {
        reviewContext = await repository.fetchPaymentReviewContext(payment.id);
      } catch (error) {
        if (!context.mounted) return;
        final failure = AppFailureClassifier.classify(
          error,
          fallbackTitle: 'Payment review unavailable',
          fallbackMessage:
              'The remaining balance and receiving accounts could not be loaded.',
        );
        messenger.showSnackBar(SnackBar(content: Text(failure.message)));
        return;
      } finally {
        if (mounted) setState(() => _isReviewingReceipt = false);
      }
    }

    if (!context.mounted) return;
    final submission = await showDialog<PaymentReviewSubmission>(
      context: context,
      builder: (_) => PaymentReviewDialog(
        rejecting: status == 'Rejected',
        reviewContext: reviewContext,
      ),
    );
    if (submission == null || !mounted) return;

    setState(() => _isReviewingReceipt = true);
    try {
      await repository.reviewPaymentReceipt(
        paymentId: payment.id,
        status: status,
        remarks: submission.remarks,
        verifiedAmount: submission.verifiedAmount,
        paymentAccount: submission.paymentAccount,
      );

      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            status == 'Rejected'
                ? 'Payment proof rejected.'
                : 'Receipt verified. ERP accounting has been queued.',
          ),
        ),
      );
      _invalidatePaymentRelatedState();
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Payment review failed',
        fallbackMessage:
            'Payment review could not be completed right now. Please try again.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isReviewingReceipt = false);
    }
  }

''',
)

# Case evidence opens a scoped child page. Finance operations are capability-gated.
path = "omc_app/lib/features/internal_workspace/presentation/internal_operations_center_screen.dart"
replace(
    path,
    '''import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';''',
    '''import '../../../app/design_tokens.dart';
import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../app/theme.dart';''',
)
replace(
    path,
    '''import '../domain/internal_service_case.dart';
import 'internal_workspace_providers.dart';''',
    '''import '../domain/internal_service_case.dart';
import 'internal_case_documents_screen.dart';
import 'internal_workspace_providers.dart';''',
)
replace(
    path,
    '''              onPressed: () => context.go(
                '/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}',
              ),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Open case documents'),''',
    '''              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => InternalCaseDocumentsScreen(
                    serviceRequest: serviceCase.id,
                    customerName: serviceCase.displayCustomer,
                  ),
                ),
              ),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Open case documents'),''',
)
replace(
    path,
    '''    case PaymentStatus.receiptSubmitted:
    case PaymentStatus.underReview:
      return const _PaymentReviewVisual(
        color: AppTheme.info,
        background: AppTheme.infoSoft,
        icon: Icons.manage_search_rounded,
        message: 'Payment proof is awaiting review.',
      );
    case PaymentStatus.paid:''',
    '''    case PaymentStatus.receiptSubmitted:
    case PaymentStatus.underReview:
      return const _PaymentReviewVisual(
        color: AppTheme.info,
        background: AppTheme.infoSoft,
        icon: Icons.manage_search_rounded,
        message: 'Payment proof is awaiting review.',
      );
    case PaymentStatus.partiallyPaid:
      return const _PaymentReviewVisual(
        color: AppTheme.warning,
        background: AppTheme.warningSoft,
        icon: Icons.account_balance_wallet_outlined,
        message: 'Payment is partially settled; a remaining balance is still due.',
      );
    case PaymentStatus.paid:''',
)
file = Path(path)
text = file.read_text(encoding="utf-8")
start = text.find("class _CaseOperationsV2 extends StatelessWidget {")
if start < 0:
    raise SystemExit(f"{path}: _CaseOperationsV2 marker missing")
file.write_text(
    text[:start]
    + '''class _CaseOperationsV2 extends ConsumerWidget {
  const _CaseOperationsV2({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    if (!capabilities.canViewAnyPayment) return const SizedBox.shrink();

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Operations', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Review invoices, receipts and payment status in the existing scoped payment workspace. Payment records are not loaded into this case summary.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/internal-workspace/payments'),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Open payment operations'),
            ),
          ),
        ],
      ),
    );
  }
}
''',
    encoding="utf-8",
)

print("Exact closure patch applied.")
