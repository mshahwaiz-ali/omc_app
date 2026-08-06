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
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(child: _buildPreview()),
    );
  }

  Widget _buildPreview() {
    if (_isPdf) {
      return PdfViewer.data(bytes, sourceName: fileName);
    }

    if (_isImage) {
      return Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const _UnsupportedPreview(
              message: 'This image could not be displayed.',
            ),
          ),
        ),
      );
    }

    return const _UnsupportedPreview(
      message: 'Preview is unavailable for this file type.',
    );
  }
}

class _UnsupportedPreview extends StatelessWidget {
  const _UnsupportedPreview({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
