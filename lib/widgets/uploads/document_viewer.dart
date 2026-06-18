import 'package:flutter/material.dart';

class DocumentViewer extends StatelessWidget {
  final String url;
  final String title;

  const DocumentViewer({
    super.key,
    required this.url,
    this.title = 'Document',
  });

  bool get _isImage {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  bool get _isPdf {
    return url.toLowerCase().split('?').first.endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _isPdf
          ? _buildPdfView()
          : _isImage
          ? _buildImageView(context)
          : _buildUnsupported(),
    );
  }

  Widget _buildImageView(BuildContext context) {
    return InteractiveViewer(
      panEnabled: true,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                        : null,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text('Loading image...',
                      style: TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ),
            );
          },
          errorBuilder: (_, __, ___) => _buildError(),
        ),
      ),
    );
  }

  Widget _buildPdfView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf,
                  size: 64, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            const Text('PDF Document',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'PDF preview is not supported in-app',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupported() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined,
                size: 64, color: Colors.white70),
            SizedBox(height: 16),
            Text('Preview not available',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('This file type cannot be previewed',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined,
              size: 64, color: Colors.white38),
          SizedBox(height: 16),
          Text('Failed to load image',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }
}
