import 'dart:typed_data';

class DocumentAttachment {
  const DocumentAttachment({
    required this.id,
    required this.name,
    required this.sizeInBytes,
    this.path,
    this.bytes,
    this.extension,
  });

  final String id;
  final String name;
  final int sizeInBytes;
  final String? path;
  final Uint8List? bytes;
  final String? extension;

  bool get hasUploadPath => path != null && path!.trim().isNotEmpty;
  bool get hasUploadBytes => bytes != null && bytes!.isNotEmpty;
  bool get hasUploadData => hasUploadPath || hasUploadBytes;
}

class DocumentPickResult {
  const DocumentPickResult({
    required this.accepted,
    required this.rejectedMessages,
  });

  final List<DocumentAttachment> accepted;
  final List<String> rejectedMessages;

  bool get hasAcceptedFiles => accepted.isNotEmpty;
  bool get hasRejectedFiles => rejectedMessages.isNotEmpty;
}
