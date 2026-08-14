import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/network/mutation_intent.dart';
import '../../../core/uploads/upload_coordinator.dart';
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

final paymentPageProvider =
    FutureProvider.family<PaymentPage, PaymentPageQuery>(
      (ref, query) =>
          ref.watch(paymentsRepositoryProvider).fetchPaymentPage(query),
    );

final paymentDetailProvider = FutureProvider.family<PaymentItem?, String>((
  ref,
  paymentId,
) {
  final repository = ref.watch(paymentsRepositoryProvider);

  return repository.fetchPaymentDetail(paymentId);
});

class PaymentsRepository {
  PaymentsRepository({required FrappeClient frappeClient})
    : _frappeClient = frappeClient,
      _uploadCoordinator = UploadCoordinator(frappeClient);

  final FrappeClient _frappeClient;
  final UploadCoordinator _uploadCoordinator;
  final Map<String, MutationIntent> _receiptIntents = {};

  Future<List<PaymentItem>> fetchPayments() async {
    return (await fetchPaymentPage(
      const PaymentPageQuery(pageLength: 100),
    )).items;
  }

  Future<PaymentPage> fetchPaymentPage(PaymentPageQuery query) async {
    final response = await _frappeClient.getMethod(
      ApiConfig.paymentsMethod,
      queryParameters: {
        'limit_start': query.start,
        'limit_page_length': query.pageLength,
        if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
        if (query.status.trim().isNotEmpty) 'status': query.status.trim(),
      },
    );
    final payload = response['message'] is Map<String, dynamic>
        ? response['message'] as Map<String, dynamic>
        : response;
    final items = _mapPaymentsResponse(response);
    final total = _intValue(payload['total'], fallback: items.length);
    return PaymentPage(
      items: items,
      start: _intValue(payload['limit_start'], fallback: query.start),
      pageLength: _intValue(
        payload['limit_page_length'],
        fallback: query.pageLength,
      ),
      total: total,
      hasMore:
          _boolValue(payload['has_more']) || query.start + items.length < total,
    );
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
      'name': cleanPaymentId,
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
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final cleanPaymentId = paymentId.trim();
    if (cleanPaymentId.isEmpty) {
      throw const ApiError(message: 'Missing payment reference for upload.');
    }

    final uploadableAttachments = attachments
        .where((attachment) => attachment.hasUploadData)
        .toList(growable: false);

    if (uploadableAttachments.isEmpty) {
      throw const ApiError(
        message: 'Selected receipt is not available for upload on this device.',
      );
    }

    final uploadedFiles = <Map<String, dynamic>>[];

    for (final attachment in uploadableAttachments) {
      final intent = _receiptIntents.putIfAbsent(
        cleanPaymentId,
        MutationIntent.new,
      );
      final fingerprint = {
        'payment_id': cleanPaymentId,
        'file_name': attachment.name,
        'file_size': attachment.sizeInBytes,
      };
      final key = intent.keyFor(fingerprint);
      final response = await _uploadCoordinator.upload(
        filePath: attachment.path,
        fileBytes: attachment.bytes,
        fileName: attachment.name,
        sizeBytes: attachment.sizeInBytes,
        policy: const UploadPolicy(
          allowedExtensions: {'pdf', 'jpg', 'jpeg', 'png'},
          maxSizeBytes: 10 * 1024 * 1024,
        ),
        method: ApiConfig.uploadPaymentReceiptMultipartMethod,
        extraFields: {'payment_id': cleanPaymentId, 'name': cleanPaymentId},
        idempotencyKey: key,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      uploadedFiles.add(response);
      intent.complete();
    }

    return uploadedFiles;
  }

  Future<AuthenticatedPaymentFile> downloadReceipt(PaymentItem payment) async {
    final location = payment.receiptUrl?.trim() ?? '';
    if (location.isEmpty) {
      throw const ApiError(message: 'No receipt is attached to this payment.');
    }
    final uri = Uri.tryParse(location);
    final name = uri?.pathSegments.isNotEmpty == true
        ? Uri.decodeComponent(uri!.pathSegments.last)
        : 'payment-receipt';
    return AuthenticatedPaymentFile(
      name: name.isEmpty ? 'payment-receipt' : name,
      bytes: await _frappeClient.getAuthenticatedFile(location),
    );
  }

  List<PaymentItem> _mapPaymentsResponse(Map<String, dynamic>? data) {
    if (data == null) return const [];

    final message = data['message'];
    final rawPayments = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['payments'] ??
              message['payment_list'] ??
              message['data'] ??
              message['items'] ??
              message['rows'] ??
              message['results'] ??
              message['records']
        : data['payments'] ??
              data['payment_list'] ??
              data['data'] ??
              data['items'] ??
              data['rows'] ??
              data['results'] ??
              data['records'];

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
        ? message['payment'] ??
              message['payment_detail'] ??
              message['data'] ??
              message['item'] ??
              message['record'] ??
              message
        : data['payment'] ??
              data['payment_detail'] ??
              data['data'] ??
              data['item'] ??
              data['record'];

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
        json['invoice_url'] ??
            json['invoice_file'] ??
            json['invoice_link'] ??
            json['invoice_pdf'] ??
            json['invoice_attachment'],
      ),
      receiptUrl: _nullableString(
        json['receipt_url'] ??
            json['receipt_attachment'] ??
            json['receipt_file'] ??
            json['receipt_link'] ??
            json['file_url'],
      ),
      paymentUrl: _nullableString(
        json['payment_url'] ??
            json['payment_link'] ??
            json['gateway_url'] ??
            json['payment_gateway_url'],
      ),
      paymentChannel: _nullableString(
        json['payment_channel'] ?? json['channel'],
      ),
      paymentActionLabel: _nullableString(
        json['payment_action_label'] ?? json['action_label'],
      ),
      onlineGatewayAvailable: _boolValue(json['online_gateway_available']),
      paymentInstructions: _nullableString(
        json['payment_instructions'] ??
            json['payment_method_instructions'] ??
            json['manual_payment_instructions'],
      ),
      bankAccountDetails: _nullableString(
        json['bank_account_details'] ??
            json['bank_details'] ??
            json['deposit_account'],
      ),
      dueDateLabel: _nullableString(
        json['due_date_label'] ??
            json['due_date'] ??
            json['payment_deadline'] ??
            json['deadline'],
      ),
      paidDateLabel: _nullableString(
        json['paid_date_label'] ?? json['paid_date'] ?? json['paid_on'],
      ),
      serviceReference: _nullableString(
        json['service_reference'] ?? json['case_reference'] ?? json['case_id'],
      ),
      remarks: _nullableString(
        json['receipt_review_remarks'] ??
            json['review_remarks'] ??
            json['remarks'] ??
            json['notes'],
      ),
      status: _statusFromValue(json['status']),
      canReviewPayments: _boolValue(json['can_review_payments']),
      customerName: _nullableString(json['customer_name']),
      customerProfile: _nullableString(json['customer_profile']),
      scopeType: _nullableString(json['scope_type']),
    );
  }

  bool _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes' || text == 'on';
  }

  int _intValue(dynamic value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
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

class PaymentPageQuery {
  const PaymentPageQuery({
    this.start = 0,
    this.pageLength = 20,
    this.search = '',
    this.status = '',
  });

  final int start;
  final int pageLength;
  final String search;
  final String status;

  @override
  bool operator ==(Object other) =>
      other is PaymentPageQuery &&
      other.start == start &&
      other.pageLength == pageLength &&
      other.search == search &&
      other.status == status;

  @override
  int get hashCode => Object.hash(start, pageLength, search, status);
}

class PaymentPage {
  const PaymentPage({
    required this.items,
    required this.start,
    required this.pageLength,
    required this.total,
    required this.hasMore,
  });

  final List<PaymentItem> items;
  final int start;
  final int pageLength;
  final int total;
  final bool hasMore;
}

class AuthenticatedPaymentFile {
  const AuthenticatedPaymentFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
