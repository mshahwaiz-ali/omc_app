import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../network/api_error.dart';
import '../network/frappe_client.dart';

class UploadPolicy {
  const UploadPolicy({
    required this.allowedExtensions,
    required this.maxSizeBytes,
  });

  final Set<String> allowedExtensions;
  final int maxSizeBytes;
}

class UploadCoordinator {
  UploadCoordinator(this._client);

  final FrappeClient _client;

  Future<Map<String, dynamic>> upload({
    required String? filePath,
    required Uint8List? fileBytes,
    required String fileName,
    required int sizeBytes,
    required UploadPolicy policy,
    String? method,
    String? doctype,
    String? docname,
    Map<String, Object?>? extraFields,
    String? idempotencyKey,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) {
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    if (!policy.allowedExtensions.contains(extension)) {
      throw const ApiError(message: 'This file type is not supported.');
    }
    if (sizeBytes <= 0) {
      throw const ApiError(message: 'The selected file is empty.');
    }
    if (sizeBytes > policy.maxSizeBytes) {
      throw const ApiError(message: 'The selected file is too large.');
    }
    if ((filePath == null || filePath.trim().isEmpty) && fileBytes == null) {
      throw const ApiError(
        message: 'The selected file is not available on this device.',
      );
    }

    return _client.uploadFile(
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      method: method,
      doctype: doctype,
      docname: docname,
      extraFields: extraFields ?? const {},
      idempotencyKey: idempotencyKey,
      onSendProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}
