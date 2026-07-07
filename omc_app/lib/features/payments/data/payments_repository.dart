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

  Future<PaymentItem?> reviewPaymentReceipt({
    required String paymentId,
    required String status,
    String? remarks,
    String? paymentReference,
  }) async {
    final cleanPaymentId = paymentId.trim();
    final cleanStatus = status.trim();

    if (cleanPaymentId.isEmpty) {
      throw const ApiError(message: 'Missing payment reference for review.');
    }

    if (cleanStatus.isEmpty) {
      throw const ApiError(message: 'Select a valid payment review status.');
    }

    final data = <String, dynamic>{
      'payment_id': cleanPaymentId,
      'status': cleanStatus,
    };

    if (remarks != null) {
      data['remarks'] = remarks;
    }

    if (paymentReference != null) {
      data['payment_reference'] = paymentReference;
    }

    final response = await _frappeClient.postMethod(
      ApiConfig.reviewPaymentReceiptMethod,
      data: data,
    );

    return _mapPaymentDetailResponse(response);
  }

  Future<List<Map<String, dynamic>>> uploadPaymentReceipts({
    required String paymentId,
    required List<DocumentAttachment> attachments,
  }) async {
    final cleanPaymentId = paymentId.trim();
    if (cleanPaymentId.isEmpty) {
      throw const ApiError(message: 'Missing payment reference for upload.');
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

      final uploadResponse = await _frappeClient.uploadFile(
        filePath: filePath,
        fileName: attachment.name,
        doctype: ApiConfig.paymentUploadDoctype,
        docname: cleanPaymentId,
      );

      final uploadedFileUrl = _extractFileUrl(uploadResponse);
      if (uploadedFileUrl == null) {
        throw const ApiError(
          message: 'Receipt uploaded but the server did not return a file URL.',
        );
      }

      final response = await _frappeClient.postMethod(
        ApiConfig.uploadPaymentReceiptMethod,
        data: {
          'payment_id': cleanPaymentId,
          'receipt_attachment': uploadedFileUrl,
          'receipt_url': uploadedFileUrl,
          'file_url': uploadedFileUrl,
        },
      );

      uploadedFiles.add(response);
    }

    return uploadedFiles;
  }

  String? _extractFileUrl(Map<String, dynamic> response) {
    final message = response['message'];
    final data = message is Map<String, dynamic> ? message : response;

    final fileUrl = data['file_url'] ?? data['url'] ?? data['file'];

    final text = fileUrl?.toString().trim();
    if (text == null || text.isEmpty) return null;

    return text;
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
        currency: json['currency'],
      ),
      reference: _nullableString(
        json['reference'] ??
            json['payment_reference'] ??
            json['invoice_number'],
      ),
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
        json['paid_date_label'] ?? json['paid_date'] ?? json['paid_on'],
      ),
      serviceReference: _nullableString(
        json['service_reference'] ?? json['case_reference'] ?? json['case_id'],
      ),
      remarks: _nullableString(json['remarks'] ?? json['notes']),
      status: _statusFromValue(json['status']),
    );
  }

  PaymentStatus _statusFromValue(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';

    if (status.contains('receipt submitted') ||
        status.contains('receipt_submitted') ||
        status.contains('submitted')) {
      return PaymentStatus.receiptSubmitted;
    }
    if (status.contains('under review') || status.contains('review')) {
      return PaymentStatus.underReview;
    }
    if (status.contains('reject')) return PaymentStatus.rejected;
    if (status.contains('overdue') || status.contains('expired')) {
      return PaymentStatus.overdue;
    }
    if (status.contains('unpaid') ||
        status.contains('pending') ||
        status.contains('awaiting') ||
        status == 'due' ||
        status.startsWith('due ')) {
      return PaymentStatus.pending;
    }
    if (status == 'paid' ||
        status == 'complete' ||
        status == 'completed' ||
        status.contains('fully paid')) {
      return PaymentStatus.paid;
    }
    if (status.contains('cancel')) return PaymentStatus.cancelled;

    return PaymentStatus.pending;
  }

  String _amountLabel(dynamic value, {dynamic currency}) {
    final currencyLabel = currency?.toString().trim();
    final resolvedCurrency = currencyLabel == null || currencyLabel.isEmpty
        ? 'PKR'
        : currencyLabel;

    if (value == null) return '$resolvedCurrency 0';

    if (value is num) {
      return '$resolvedCurrency ${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';
    }

    final text = value.toString().trim();
    if (text.isEmpty) return '$resolvedCurrency 0';

    return text.contains(RegExp(r'[A-Za-z]'))
        ? text
        : '$resolvedCurrency $text';
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
