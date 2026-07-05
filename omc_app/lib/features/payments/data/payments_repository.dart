import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../../documents/data/document_attachment.dart';
import 'payment_item.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return PaymentsRepository(frappeClient: frappeClient);
});

final paymentsProvider = FutureProvider<List<PaymentItem>>((ref) async {
  final repository = ref.watch(paymentsRepositoryProvider);
  return repository.fetchPayments();
});

final paymentDetailProvider = FutureProvider.family<PaymentItem?, String>((
  ref,
  paymentId,
) {
  final repository = ref.watch(paymentsRepositoryProvider);

  return repository.fetchPaymentDetail(paymentId);
});

class PaymentsRepository {
  const PaymentsRepository({required this._frappeClient});

  final FrappeClient _frappeClient;

  Future<List<PaymentItem>> fetchPayments() async {
    final response = await _frappeClient.getMethod(ApiConfig.paymentsMethod);
    return _mapPaymentsResponse(response);
  }

  Future<PaymentItem?> fetchPaymentDetail(String paymentId) async {
    final cleanPaymentId = paymentId.trim();
    if (cleanPaymentId.isEmpty) return null;

    final response = await _frappeClient.getMethod(
      ApiConfig.paymentDetailMethod,
      queryParameters: {'payment_id': cleanPaymentId, 'name': cleanPaymentId},
    );

    return _mapPaymentDetailResponse(response);
  }

  Future<List<Map<String, dynamic>>> uploadPaymentReceipts({
    required String paymentId,
    required List<DocumentAttachment> attachments,
  }) async {
    final cleanPaymentId = paymentId.trim();
    if (cleanPaymentId.isEmpty) {
      throw const ApiError(message: 'Missing backend payment reference.');
    }

    final uploadableAttachments = attachments
        .where((attachment) => attachment.hasUploadPath)
        .toList(growable: false);

    if (uploadableAttachments.isEmpty) {
      throw const ApiError(
        message: 'Selected receipt is not available for upload on this device.',
      );
    }

    final uploadedFiles = <Map<String, dynamic>>[];

    for (final attachment in uploadableAttachments) {
      final filePath = attachment.path;
      if (filePath == null || filePath.trim().isEmpty) {
        continue;
      }

      final response = await _frappeClient.uploadFile(
        filePath: filePath,
        fileName: attachment.name,
        doctype: ApiConfig.paymentUploadDoctype,
        docname: cleanPaymentId,
      );

      uploadedFiles.add(response);
    }

    return uploadedFiles;
  }

  List<PaymentItem> _mapPaymentsResponse(Map<String, dynamic>? data) {
    if (data == null) return const [];

    final message = data['message'];
    final rawPayments = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['payments'] ?? message['data'] ?? message['items']
        : data['payments'] ?? data['data'] ?? data['items'];

    if (rawPayments is! List) return const [];

    return rawPayments
        .whereType<Map<String, dynamic>>()
        .map(_mapPayment)
        .toList(growable: false);
  }

  PaymentItem? _mapPaymentDetailResponse(Map<String, dynamic>? data) {
    if (data == null) return null;

    final message = data['message'];
    final rawPayment = message is Map<String, dynamic>
        ? message['payment'] ?? message['data'] ?? message['item'] ?? message
        : data['payment'] ?? data['data'] ?? data['item'];

    if (rawPayment is! Map<String, dynamic>) return null;

    return _mapPayment(rawPayment);
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
      invoiceUrl: _nullableString(
        json['invoice_url'] ?? json['invoice_file'] ?? json['invoice_link'],
      ),
      receiptUrl: _nullableString(
        json['receipt_url'] ?? json['receipt_file'] ?? json['receipt_link'],
      ),
      paymentUrl: _nullableString(
        json['payment_url'] ?? json['payment_link'] ?? json['gateway_url'],
      ),
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
