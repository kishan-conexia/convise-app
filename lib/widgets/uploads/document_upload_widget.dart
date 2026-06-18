import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

enum DocumentUploadType { imageOnly, pdfOnly, any }

class DocumentUploadWidget extends StatelessWidget {
  final String label;
  final String? subtitle;
  final File? selectedFile;
  final void Function(File file, String fileName) onFilePicked;
  final VoidCallback? onClear;
  final DocumentUploadType type;
  final Color accentColor;

  const DocumentUploadWidget({
    super.key,
    required this.label,
    required this.selectedFile,
    required this.onFilePicked,
    this.subtitle,
    this.onClear,
    this.type = DocumentUploadType.any,
    this.accentColor = Colors.indigo,
  });

  bool get _isPdf {
    if (selectedFile == null) return false;
    return selectedFile!.path.toLowerCase().endsWith('.pdf');
  }

  Future<void> _pickFile(BuildContext context) async {
    switch (type) {
      case DocumentUploadType.imageOnly:
        await _pickImage(context);
        break;
      case DocumentUploadType.pdfOnly:
        await _pickPdf();
        break;
      case DocumentUploadType.any:
        _showSourceOptions(context);
        break;
    }
  }

  Future<void> _pickImage(BuildContext context, {ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked != null) {
      onFilePicked(File(picked.path), picked.name);
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      onFilePicked(
        File(result.files.single.path!),
        result.files.single.name,
      );
    }
  }

  Future<void> _pickAny() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      onFilePicked(
        File(result.files.single.path!),
        result.files.single.name,
      );
    }
  }

  void _showSourceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('Select Document Source',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800)),
              const SizedBox(height: 12),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: accentColor.withOpacity(0.1),
                  child: Icon(Icons.camera_alt_outlined, color: accentColor),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Capture document with camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(context, source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: accentColor.withOpacity(0.1),
                  child: Icon(Icons.photo_library_outlined, color: accentColor),
                ),
                title: const Text('Choose Image'),
                subtitle: const Text('JPG or PNG from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(context, source: ImageSource.gallery);
                },
              ),
              // ListTile(
              //   leading: CircleAvatar(
              //     backgroundColor: accentColor.withOpacity(0.1),
              //     child: Icon(Icons.picture_as_pdf_outlined, color: accentColor),
              //   ),
              //   title: const Text('Choose PDF'),
              //   subtitle: const Text('Select PDF file'),
              //   onTap: () {
              //     Navigator.pop(context);
              //     _pickPdf();
              //   },
              // ),
              if (selectedFile != null && onClear != null) ...[
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text('Remove',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    onClear!();
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickFile(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selectedFile != null
                ? accentColor
                : Colors.grey.shade300,
            width: selectedFile != null ? 2 : 1.5,
          ),
          color: selectedFile != null
              ? accentColor.withOpacity(0.04)
              : Colors.grey.shade50,
        ),
        child: selectedFile == null
            ? _buildEmpty()
            : _buildSelected(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.upload_file_outlined,
              color: accentColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ] else ...[
                const SizedBox(height: 2),
                Text('PDF, JPG, PNG supported',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ],
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: Colors.grey.shade400),
      ],
    );
  }

  Widget _buildSelected() {
    final fileName = selectedFile!.path.split('/').last;
    final fileSize = selectedFile!.lengthSync();
    final fileSizeKb = (fileSize / 1024).toStringAsFixed(1);

    return Row(
      children: [
        // Preview or PDF icon
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: accentColor.withOpacity(0.1),
          ),
          child: _isPdf
              ? Icon(Icons.picture_as_pdf, color: Colors.red.shade600, size: 28)
              : ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(selectedFile!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 14, color: Colors.green.shade600),
                  const SizedBox(width: 4),
                  Text('Ready · $fileSizeKb KB',
                      style: TextStyle(
                          fontSize: 12, color: Colors.green.shade600)),
                ],
              ),
            ],
          ),
        ),
        // Change button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('Change',
              style: TextStyle(
                  fontSize: 12,
                  color: accentColor,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
