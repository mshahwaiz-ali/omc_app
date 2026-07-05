import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'payment_item.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return PaymentsRepository(frappeClient: frappeClient);
});

final paymentsProvider = FutureProvider<List<PaymentItem>>((ref) async {
  final repository = ref.watch(paymentsRepositoryProvider);
  return repository.fetchPayments();
});

class PaymentsRepository {
  const PaymentsRepository({required this._frappeClient});

  final FrappeClient _frappeClient;

  Future<List<PaymentItem>> fetchPayments() async {
    try {
      final response = await _frappeClient.getMethod(ApiConfig.paymentsMethod);
      return _mapPaymentsResponse(response);
    } on ApiError {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  List<PaymentItem> _mapPaymentsResponse(Map<String, dynamic>? data) {
    if (data == null) return const [];

    final message = data['message'];
    final rawPayments = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['payments']
        : data['payments'];

    if (rawPayments is! List) return const [];

    return rawPayments
        .whereType<Map<String, dynamic>>()
        .map(_mapPayment)
        .toList(growable: false);
  }

  PaymentItem _mapPayment(Map<String, dynamic> json) {
    return PaymentItem(
      id: _stringValue(json['id'] ?? json['name'] ?? json['payment_id']),
      title: _stringValue(
        json['title'] ?? json['service_title'] ?? json['name'],
      ),
      amountLabel: _amountLabel(
        json['amount_label'] ?? json['amount'] ?? json['grand_total'],
      ),
      reference: _nullableString(json['reference'] ?? json['invoice_number']),
      dueDateLabel: _nullableString(json['due_date_label'] ?? json['due_date']),
      paidDateLabel: _nullableString(
        json['paid_date_label'] ?? json['paid_date'],
      ),
      serviceReference: _nullableString(
        json['service_reference'] ?? json['case_reference'],
      ),
      remarks: _nullableString(json['remarks'] ?? json['notes']),
      status: _statusFromValue(json['status']),
    );
  }

  PaymentStatus _statusFromValue(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';

    if (status.contains('paid') || status.contains('complete')) {
      return PaymentStatus.paid;
    }
    if (status.contains('overdue') || status.contains('expired')) {
      return PaymentStatus.overdue;
    }
    if (status.contains('cancel')) return PaymentStatus.cancelled;

    return PaymentStatus.pending;
  }

  String _amountLabel(dynamic value) {
    if (value is num) return 'PKR ${value.toStringAsFixed(0)}';

    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return 'PKR 0';
    if (text.toLowerCase().contains('pkr') || text.contains('Rs')) return text;

    return 'PKR $text';
  }

  String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
