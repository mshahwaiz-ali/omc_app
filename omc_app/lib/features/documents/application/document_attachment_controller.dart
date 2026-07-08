import 'package:file_picker/file_picker.dart';
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

  Future<DocumentPickResult> pickDocuments({
    List<DocumentAttachment> existingAttachments = const [],
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
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
}
