import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/payments/data/payment_item.dart';

void main() {
  test('partially paid remains actionable until full settlement', () {
    const payment = PaymentItem(
      id: 'OMC-PAY-TEST',
      title: 'Test payment',
      amountLabel: 'PKR 9000',
      accountedAmountLabel: 'PKR 4000',
      invoiceNumber: 'SINV-O-03059',
      invoiceNumbers: <String>['SINV-O-03059', 'SINV-LEGACY-00001'],
      paymentProofUrl: '/private/files/proof-1.png',
      paymentProofUrls: <String>[
        '/private/files/proof-1.png',
        '/private/files/proof-2.png',
      ],
      status: PaymentStatus.partiallyPaid,
    );

    expect(payment.status.label, 'Partially Paid');
    expect(payment.requiresAction, isTrue);
    expect(payment.isSettlementEvidenceLocked, isTrue);
    expect(payment.heroAmountTitle, 'ERP accounted');
    expect(payment.heroAmountLabel, 'PKR 4000');
    expect(payment.effectiveInvoiceNumbers, hasLength(2));
    expect(payment.effectivePaymentProofUrls, hasLength(2));
  });

  test(
    'Desk bank account details remain readable as structured payment data',
    () {
      const account = PaymentBankAccount(
        title: 'Primary PKR Account',
        bankName: 'Meezan Bank',
        accountTitle: 'OMC House',
        accountNumber: '1234567890',
        iban: 'PK00MEZN0000001234567890',
        branch: 'Main Branch',
        currency: 'PKR',
      );

      expect(account.hasDetails, isTrue);
      expect(account.displayDetails, contains('Bank: Meezan Bank'));
      expect(account.displayDetails, contains('Account title: OMC House'));
      expect(account.displayDetails, contains('Account number: 1234567890'));
      expect(
        account.displayDetails,
        contains('IBAN: PK00MEZN0000001234567890'),
      );
      expect(account.displayDetails, contains('Branch: Main Branch'));
      expect(account.displayDetails, contains('Currency: PKR'));
    },
  );
}
