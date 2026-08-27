import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/config/api_config.dart';
import 'package:omc_app/core/network/dio_client.dart';
import 'package:omc_app/core/network/frappe_client.dart';
import 'package:omc_app/core/storage/secure_storage_service.dart';
import 'package:omc_app/features/documents/data/document_attachment.dart';
import 'package:omc_app/features/documents/data/documents_repository.dart';

void main() {
  test('customer upload stays unlinked until canonical registration', () async {
    final client = _UploadFrappeClient();
    final repository = DocumentsRepository(client);

    await repository.uploadRequiredDocument(
      serviceRequestId: 'OMC-SR-TEST',
      documentKey: 'cnic-front',
      documentTitle: 'CNIC front',
      documentType: 'Identity',
      attachment: DocumentAttachment(
        id: 'fixture.png|4',
        name: 'fixture.png',
        sizeInBytes: 4,
        bytes: Uint8List.fromList([137, 80, 78, 71]),
        extension: 'png',
      ),
    );

    expect(client.uploadDoctype, isNull);
    expect(client.uploadDocname, isNull);
    expect(client.registrationMethod, ApiConfig.uploadServiceDocumentMethod);
    expect(client.registrationData?['service_request'], 'OMC-SR-TEST');
    expect(
      client.registrationData?['attachment'],
      '/private/files/fixture.png',
    );
  });
}

class _UploadFrappeClient extends FrappeClient {
  _UploadFrappeClient()
    : super(
        DioClient(
          secureStorageService: SecureStorageService(),
          dio: Dio(BaseOptions(baseUrl: 'https://erp.omchouse.com')),
        ),
      );

  String? uploadDoctype;
  String? uploadDocname;
  String? registrationMethod;
  Map<String, dynamic>? registrationData;

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
    uploadDoctype = doctype;
    uploadDocname = docname;
    return {
      'message': {'file_url': '/private/files/fixture.png'},
    };
  }

  @override
  Future<Map<String, dynamic>> postMethod(
    String method, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    String? idempotencyKey,
  }) async {
    registrationMethod = method;
    registrationData = Map<String, dynamic>.from(data! as Map);
    return {
      'message': {
        'uploaded': true,
        'document': {'name': 'OMC-DOC-TEST'},
      },
    };
  }
}
