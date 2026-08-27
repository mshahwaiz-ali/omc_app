import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/document_attachment.dart';

final documentAttachmentControllerProvider =
    Provider<DocumentAttachmentController>((ref) {
      return DocumentAttachmentController();
    });

class DocumentAttachmentController {
  static const int maxFileSizeInBytes = 10 * 1024 * 1024;
  static const List<String> allowedExtensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'doc',
    'docx',
  ];

  static const bool _e2eFixtureRequested = bool.fromEnvironment(
    'OMC_E2E_FILE_PICKER',
    defaultValue: false,
  );

  static bool get e2eFixtureEnabled => _e2eFixtureRequested && !kReleaseMode;

  Future<DocumentPickResult> pickDocuments({
    List<DocumentAttachment> existingAttachments = const [],
    List<String> allowedExtensionsOverride = allowedExtensions,
    int? maxFiles,
  }) async {
    if (e2eFixtureEnabled) {
      return _pickE2eFixture(
        existingAttachments: existingAttachments,
        allowedExtensionsOverride: allowedExtensionsOverride,
        maxFiles: maxFiles,
      );
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensionsOverride,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) {
      return const DocumentPickResult(accepted: [], rejectedMessages: []);
    }

    final existingIds = existingAttachments
        .map((attachment) => attachment.id)
        .toSet();
    final accepted = <DocumentAttachment>[];
    final rejectedMessages = <String>[];

    for (final file in result.files) {
      if (maxFiles != null &&
          existingAttachments.length + accepted.length >= maxFiles) {
        rejectedMessages.add(
          'Only $maxFiles file${maxFiles == 1 ? '' : 's'} can be selected.',
        );
        continue;
      }
      final attachment = _fromPlatformFile(file);
      if (file.size > maxFileSizeInBytes) {
        rejectedMessages.add(
          '${file.name} is larger than ${formatFileSize(maxFileSizeInBytes)}.',
        );
        continue;
      }

      if (existingIds.contains(attachment.id) ||
          accepted.any((item) => item.id == attachment.id)) {
        rejectedMessages.add('${file.name} is already attached.');
        continue;
      }

      accepted.add(attachment);
    }

    return DocumentPickResult(
      accepted: accepted,
      rejectedMessages: rejectedMessages,
    );
  }

  DocumentPickResult _pickE2eFixture({
    required List<DocumentAttachment> existingAttachments,
    required List<String> allowedExtensionsOverride,
    required int? maxFiles,
  }) {
    final normalizedExtensions = allowedExtensionsOverride
        .map((extension) => extension.trim().toLowerCase())
        .where((extension) => extension.isNotEmpty)
        .toSet();

    if (!normalizedExtensions.contains('png')) {
      return const DocumentPickResult(
        accepted: [],
        rejectedMessages: [
          'The E2E attachment fixture requires PNG to be allowed by this upload.',
        ],
      );
    }

    if (maxFiles != null && existingAttachments.length >= maxFiles) {
      return DocumentPickResult(
        accepted: const [],
        rejectedMessages: [
          'Only $maxFiles file${maxFiles == 1 ? '' : 's'} can be selected.',
        ],
      );
    }

    final attachment = DocumentAttachment(
      id: 'omc-e2e-fixture.png|${_e2ePngBytes.length}',
      name: 'omc-e2e-fixture.png',
      sizeInBytes: _e2ePngBytes.length,
      bytes: Uint8List.fromList(_e2ePngBytes),
      extension: 'png',
    );

    if (existingAttachments.any((item) => item.id == attachment.id)) {
      return const DocumentPickResult(
        accepted: [],
        rejectedMessages: ['omc-e2e-fixture.png is already attached.'],
      );
    }

    return DocumentPickResult(
      accepted: [attachment],
      rejectedMessages: const [],
    );
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';

    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';

    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  DocumentAttachment _fromPlatformFile(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    final id = [
      file.path?.trim(),
      file.name.trim(),
      file.size.toString(),
    ].whereType<String>().where((part) => part.isNotEmpty).join('|');

    return DocumentAttachment(
      id: id,
      name: file.name,
      sizeInBytes: file.size,
      path: file.path,
      bytes: file.bytes,
      extension: extension,
    );
  }

  static const List<int> _e2ePngBytes = [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    13,
    73,
    72,
    68,
    82,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
    8,
    6,
    0,
    0,
    0,
    31,
    21,
    196,
    137,
    0,
    0,
    0,
    13,
    73,
    68,
    65,
    84,
    120,
    156,
    99,
    248,
    255,
    255,
    255,
    127,
    0,
    9,
    251,
    3,
    253,
    42,
    134,
    227,
    138,
    0,
    0,
    0,
    0,
    73,
    69,
    78,
    68,
    174,
    66,
    96,
    130,
  ];
}
