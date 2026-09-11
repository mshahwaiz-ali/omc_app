import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/payments/data/payment_item.dart';

void main() {
  test('partially paid remains actionable until full settlement', () {
    const payment = PaymentItem(
      id: 'OMC-PAY-TEST',
      title: 'Test payment',
      amountLabel: 'PKR 50000',
      status: PaymentStatus.partiallyPaid,
    );

    expect(payment.status.label, 'Partially Paid');
    expect(payment.requiresAction, isTrue);
  });
}
