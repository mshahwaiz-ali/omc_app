import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/dio_client.dart';
import 'package:omc_app/core/network/frappe_client.dart';
import 'package:omc_app/core/storage/secure_storage_service.dart';
import 'package:omc_app/features/payments/data/payment_accounting_summary.dart';
import 'package:omc_app/features/payments/data/payment_item.dart';
import 'package:omc_app/features/payments/data/payments_repository.dart';
import 'package:omc_app/features/payments/presentation/widgets/payment_action_card.dart';

void main() {
  test('Deferred backend payment maps to explicit Pay Later state', () async {
    final client = _PaymentDetailClient({
      'name': 'OMC-PAY-DEFERRED',
      'title': 'Deferred service payment',
      'amount': 5000,
      'currency': 'PKR',
      'status': 'Deferred',
      'payment_execution_mode': 'Pay Later',
      'pay_later_approved_at': '2026-09-19 02:07:00',
    });
    final repository = PaymentsRepository(frappeClient: client);

    final payment = await repository.fetchPaymentDetail('OMC-PAY-DEFERRED');

    expect(payment, isNotNull);
    expect(payment!.status, PaymentStatus.deferred);
    expect(payment.status.label, 'Pay Later');
    expect(payment.isPayLater, isTrue);
    expect(payment.executionModeLabel, 'Pay Later');
    expect(payment.payLaterApprovedAt, '2026-09-19 02:07:00');
    expect(payment.requiresAction, isFalse);
    expect(payment.isSettlementEvidenceLocked, isTrue);
    expect(payment.heroAmountTitle, 'Pay Later amount');
  });

  testWidgets(
    'Pay Later payment suppresses collection instructions and receipt action',
    (tester) async {
      const payment = PaymentItem(
        id: 'OMC-PAY-DEFERRED',
        title: 'Deferred service payment',
        amountLabel: 'PKR 5000',
        status: PaymentStatus.deferred,
        paymentExecutionMode: 'Pay Later',
        payLaterApprovedAt: '2026-09-19 02:07:00',
        paymentUrl: 'https://wa.me/923001234567',
        paymentActionLabel: 'Contact OMC on WhatsApp',
        paymentInstructions: 'Transfer now and upload proof.',
        bankAccount: PaymentBankAccount(
          title: 'Primary PKR Account',
          bankName: 'Meezan Bank',
          accountTitle: 'OMC House',
          accountNumber: '00123456789',
          iban: 'PK00MEZN001234567890',
          branch: 'Gulberg',
          currency: 'PKR',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PaymentActionCard(
                payment: payment,
                onInvoice: () {},
                onReceipt: () {},
                onUploadReceipt: () {},
                onPayNow: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Pay Later status'), findsOneWidget);
      expect(
        find.textContaining('No payment proof is required now'),
        findsOneWidget,
      );
      expect(find.text('Contact OMC on WhatsApp'), findsNothing);
      expect(find.textContaining('Meezan Bank'), findsNothing);
      expect(find.textContaining('Transfer now'), findsNothing);
      expect(find.text('Upload payment proof'), findsNothing);
    },
  );

  test('Pay Later accounting summary preserves execution-mode authority', () {
    final summary = PaymentAccountingSummary.fromJson({
      'request': 'OMC-SR-PAY-LATER',
      'canonical_invoice': '',
      'currency': 'PKR',
      'invoice_total': 5000,
      'paid_amount': 0,
      'outstanding_amount': 5000,
      'accounting_status': 'Unmatched',
      'activation_status': 'Awaiting Full Settlement',
      'request_state': 'Activated',
      'payment_execution_mode': 'Pay Later',
      'pay_later_approved': 1,
      'can_make_payment': 0,
      'maximum_payment_amount': 0,
      'payment_block_reason': 'Pay Later is approved.',
      'open_payment': '',
      'payments': const [],
    });

    expect(summary.isPayLater, isTrue);
    expect(summary.requestState, 'Activated');
    expect(summary.canonicalInvoice, isEmpty);
    expect(summary.canMakePayment, isFalse);
  });

  test(
    'Desk payment account title is included with structured bank details',
    () {
      const account = PaymentBankAccount(
        title: 'Primary PKR Account',
        bankName: 'Meezan Bank',
        accountTitle: 'OMC House',
        accountNumber: '00123456789',
        iban: 'PK00MEZN001234567890',
        branch: 'Gulberg',
        currency: 'PKR',
      );

      expect(
        account.displayDetails,
        contains('Payment account: Primary PKR Account'),
      );
      expect(account.displayDetails, contains('Bank: Meezan Bank'));
      expect(account.displayDetails, contains('Account title: OMC House'));
      expect(account.displayDetails, contains('Account number: 00123456789'));
      expect(account.displayDetails, contains('IBAN: PK00MEZN001234567890'));
    },
  );
}

class _PaymentDetailClient extends FrappeClient {
  _PaymentDetailClient(this.payment)
    : super(
        DioClient(
          secureStorageService: SecureStorageService(),
          dio: Dio(BaseOptions(baseUrl: 'https://erp.omchouse.com')),
        ),
      );

  final Map<String, dynamic> payment;

  @override
  Future<Map<String, dynamic>> getMethod(
    String method, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    return {
      'message': {'payment': payment},
    };
  }
}
