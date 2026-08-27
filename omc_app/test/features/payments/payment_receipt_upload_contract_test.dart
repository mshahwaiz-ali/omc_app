import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/config/api_config.dart';
import 'package:omc_app/core/network/dio_client.dart';
import 'package:omc_app/core/network/frappe_client.dart';
import 'package:omc_app/core/storage/secure_storage_service.dart';
import 'package:omc_app/features/documents/data/document_attachment.dart';
import 'package:omc_app/features/payments/data/payments_repository.dart';

void main() {
  test(
    'multipart receipt sends the same idempotency key in field and header',
    () async {
      final client = _ReceiptFrappeClient();
      final repository = PaymentsRepository(frappeClient: client);

      await repository.uploadPaymentReceipts(
        paymentId: 'OMC-PAY-TEST',
        attachments: [
          DocumentAttachment(
            id: 'fixture.png|4',
            name: 'fixture.png',
            sizeInBytes: 4,
            bytes: Uint8List.fromList([137, 80, 78, 71]),
            extension: 'png',
          ),
        ],
      );

      expect(client.method, ApiConfig.uploadPaymentReceiptMultipartMethod);
      expect(client.extraFields?['payment_id'], 'OMC-PAY-TEST');
      expect(client.extraFields?['name'], 'OMC-PAY-TEST');
      expect(client.idempotencyKey, isNotEmpty);
      expect(client.extraFields?['idempotency_key'], client.idempotencyKey);
    },
  );
}

class _ReceiptFrappeClient extends FrappeClient {
  _ReceiptFrappeClient()
    : super(
        DioClient(
          secureStorageService: SecureStorageService(),
          dio: Dio(BaseOptions(baseUrl: 'https://erp.omchouse.com')),
        ),
      );

  String? method;
  Map<String, Object?>? extraFields;
  String? idempotencyKey;

  @override
  Future<Map<String, dynamic>> uploadFile({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    String? method,
    String? doctype,
    String? docname,
    bool isPrivate = true,
    Map<String, Object?> extraFields = const {},
    String? idempotencyKey,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    this.method = method;
    this.extraFields = extraFields;
    this.idempotencyKey = idempotencyKey;
    return {
      'message': {'uploaded': true},
    };
  }
}
