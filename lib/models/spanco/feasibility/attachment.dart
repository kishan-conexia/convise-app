// lib/models/spanco/feasibility/attachment.dart

class Attachment {
  final String id;
  final String fileName;
  final String fileUrl;
  final String? fileType;
  final int? fileSize;
  final String? uploadedBy;
  final DateTime? uploadedAt;
  final String? description;

  Attachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    this.fileType,
    this.fileSize,
    this.uploadedBy,
    this.uploadedAt,
    this.description,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String,
      fileName: json['file_name'] as String,
      fileUrl: json['file_url'] as String,
      fileType: json['file_type'] as String?,
      fileSize: json['file_size'] as int?,
      uploadedBy: json['uploaded_by'] as String?,
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'] as String)
          : null,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'file_url': fileUrl,
      if (fileType != null) 'file_type': fileType,
      if (fileSize != null) 'file_size': fileSize,
      if (uploadedBy != null) 'uploaded_by': uploadedBy,
      if (uploadedAt != null) 'uploaded_at': uploadedAt!.toIso8601String(),
      if (description != null) 'description': description,
    };
  }

  String get fileSizeFormatted {
    if (fileSize == null) return 'Unknown';

    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize! < 1024 * 1024 * 1024) {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
