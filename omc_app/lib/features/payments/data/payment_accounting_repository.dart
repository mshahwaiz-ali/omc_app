import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'payment_accounting_summary.dart';

const _accountingSummaryMethod =
    'omc_app.api.payment_installments.get_accounting_summary';
const _createInstallmentMethod =
    'omc_app.api.payment_installments.create_installment';

final paymentAccountingRepositoryProvider = Provider<PaymentAccountingRepository>(
  (ref) {
    ref.watch(sessionEpochProvider);
    return PaymentAccountingRepository(
      frappeClient: ref.watch(frappeClientProvider),
    );
  },
);

final paymentAccountingSummaryProvider = FutureProvider.autoDispose
    .family<PaymentAccountingSummary, String>((ref, serviceRequest) async {
      return ref
          .watch(paymentAccountingRepositoryProvider)
          .fetchSummary(serviceRequest);
    });

class PaymentAccountingRepository {
  PaymentAccountingRepository({required FrappeClient frappeClient})
    : _frappeClient = frappeClient;

  final FrappeClient _frappeClient;

  Future<PaymentAccountingSummary> fetchSummary(String serviceRequest) async {
    final request = serviceRequest.trim();
    if (request.isEmpty) {
      throw const ApiError(
        message: 'Missing service request for payment accounting.',
      );
    }

    final response = await _frappeClient.getMethod(
      _accountingSummaryMethod,
      queryParameters: {'service_request': request},
    );
    final payload = _payload(response);
    return PaymentAccountingSummary.fromJson(payload);
  }

  Future<CreateInstallmentResult> createInstallment({
    required String serviceRequest,
    required double amount,
  }) async {
    final request = serviceRequest.trim();
    if (request.isEmpty) {
      throw const ApiError(
        message: 'Missing service request for payment accounting.',
      );
    }
    if (!amount.isFinite || amount <= 0) {
      throw const ApiError(message: 'Enter a valid payment amount.');
    }

    final response = await _frappeClient.postMethod(
      _createInstallmentMethod,
      data: {
        'service_request': request,
        'amount': amount,
      },
    );
    return CreateInstallmentResult.fromJson(_payload(response));
  }

  Map<String, dynamic> _payload(Map<String, dynamic> response) {
    final message = response['message'];
    if (message is Map<String, dynamic>) return message;
    return response;
  }
}
