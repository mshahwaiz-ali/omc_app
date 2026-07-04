class DocumentAttachment {
  const DocumentAttachment({
    required this.id,
    required this.name,
    required this.sizeInBytes,
    this.path,
    this.extension,
  });

  final String id;
  final String name;
  final int sizeInBytes;
  final String? path;
  final String? extension;

  bool get hasUploadPath => path != null && path!.trim().isNotEmpty;
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
