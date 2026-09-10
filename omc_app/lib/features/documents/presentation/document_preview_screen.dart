import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class DocumentPreviewScreen extends StatelessWidget {
  const DocumentPreviewScreen({
    required this.fileName,
    required this.bytes,
    super.key,
  });

  final String fileName;
  final Uint8List bytes;

  bool get _isPdf => fileName.toLowerCase().split('?').first.endsWith('.pdf');

  bool get _isImage {
    final name = fileName.toLowerCase().split('?').first;
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        titleSpacing: 4,
        title: Semantics(
          label: 'File: $fileName',
          header: true,
          excludeSemantics: true,
          child: Text(
            fileName,
            maxLines: 2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_isPdf || _isImage) const _PreviewHint(),
            Expanded(child: _buildPreview(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (_isPdf) {
      return Semantics(
        label:
            'PDF preview of $fileName. Use pinch gestures to zoom and drag to move through the document.',
        container: true,
        child: PdfViewer.data(bytes, sourceName: fileName),
      );
    }

    if (_isImage) {
      return Semantics(
        image: true,
        label:
            'Image preview of $fileName. Use pinch gestures to zoom and drag to pan.',
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              semanticLabel: fileName,
              errorBuilder: (_, _, _) => _UnsupportedPreview(
                fileName: fileName,
                message:
                    'This image could not be displayed. The downloaded file may be damaged or use an unsupported image encoding.',
              ),
            ),
          ),
        ),
      );
    }

    return _UnsupportedPreview(
      fileName: fileName,
      message:
          'Preview is unavailable for this file type. Return to the previous screen to use any download or file actions available there.',
    );
  }
}

class _PreviewHint extends StatelessWidget {
  const _PreviewHint();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Preview controls: pinch to zoom and drag to pan.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          border: Border(bottom: BorderSide(color: Color(0xFF2B2B2B))),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pinch_rounded, color: Colors.white70, size: 17),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Pinch to zoom · drag to pan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedPreview extends StatelessWidget {
  const _UnsupportedPreview({required this.fileName, required this.message});

  final String fileName;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Icon(
                  Icons.insert_drive_file_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Preview unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'File: $fileName',
                child: Text(
                  fileName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to document'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
