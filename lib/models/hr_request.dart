class HrRequest {
  final int id;
  final String userId;
  final String requestType;
  final Map<String, dynamic> newData;
  final String? userNote;
  final String priority;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined from profiles
  final String? userName;
  final String? empCode;
  final String? avatarUrl;

  final String? departmentName;

  HrRequest({
    required this.id,
    required this.userId,
    required this.requestType,
    required this.newData,
    this.userNote,
    required this.priority,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.empCode,
    this.avatarUrl,
    this.departmentName,
  });

  String get documentType => newData['document_type'] ?? '';
  // String get stagingPath  => newData['staging_path']  ?? '';
  String get documentNumber {
    final key = '${documentType}_number';
    return newData[key] ?? '';
  }
  // Add these getters alongside existing stagingPath getter
  String get stagingPath      => newData['staging_path']       ?? '';
  String get stagingPathFront => newData['staging_path_front'] ?? '';
  String get stagingPathBack  => newData['staging_path_back']  ?? '';
  String get dateFolder       => newData['date_folder']        ?? '';

  bool get isAadhaar => documentType == 'aadhaar';
  bool get isDualPhoto => isAadhaar &&
      stagingPathFront.isNotEmpty &&
      stagingPathBack.isNotEmpty;

  factory HrRequest.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>?;
    return HrRequest(
      id:              map['id'],
      userId:          map['user_id'],
      requestType: map['request_type'] ?? 'document_upload',
      newData: map['new_data'] != null
          ? Map<String, dynamic>.from(map['new_data'] as Map)
          : {},
      userNote:        map['user_note'],
      priority:        map['priority'] ?? 'normal',
      status:          map['status'],
      reviewedBy:      map['reviewed_by'],
      reviewedAt:      map['reviewed_at'] != null
          ? DateTime.tryParse(map['reviewed_at'])
          : null,
      reviewNote:      map['review_note'],
      rejectionReason: map['rejection_reason'],
      createdAt:       DateTime.parse(map['created_at']),
      updatedAt:       DateTime.parse(map['updated_at']),
      userName:        profile?['full_name'],
      empCode:         profile?['employee_code'],
      avatarUrl:       profile?['avatar_url'],
      departmentName: map['profile']?['departments']?['name'] as String?,
    );
  }
}