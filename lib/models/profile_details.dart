class ProfileDetails {
  final int id;
  final String userId;

  // ── Aadhaar ───────────────────────────────────────────
  final String? aadhaarNumber;
  final String? aadhaarUrl;
  final String? aadhaarBackUrl;

  // ── PAN ───────────────────────────────────────────────
  final String? panNumber;
  final String? panUrl;

  // ── Passport ──────────────────────────────────────────
  final String? passportNumber;
  final String? passportUrl;

  // ── Family ────────────────────────────────────────────
  final String? fatherName;
  final String? motherName;
  final String? spouseName;
  final List<dynamic> children;
  final List<dynamic> nominees;

  // ── Bank ──────────────────────────────────────────────
  final Map<String, dynamic>? bankDetails;
  final String? cancelledChequeUrl;
  final String? passbookUrl;

  // ── Profile fields (migrated from profiles table) ─────
  final String? dateOfBirth;
  final String? maritalStatus;
  final String? currentAddress;
  final String? permanentAddress;

  ProfileDetails({
    required this.id,
    required this.userId,
    this.aadhaarNumber,
    this.aadhaarUrl,
    this.aadhaarBackUrl,
    this.panNumber,
    this.panUrl,
    this.passportNumber,
    this.passportUrl,
    this.fatherName,
    this.motherName,
    this.spouseName,
    this.children    = const [],
    this.nominees    = const [],
    this.bankDetails,
    this.cancelledChequeUrl,
    this.passbookUrl,
    this.dateOfBirth,
    this.maritalStatus,
    this.currentAddress,
    this.permanentAddress,
  });

  factory ProfileDetails.fromMap(Map<String, dynamic> map) {
    return ProfileDetails(
      id:                 map['id'],
      userId:             map['user_id'],
      aadhaarNumber:      map['aadhaar_number'],
      aadhaarUrl:         map['aadhaar_url'],
      aadhaarBackUrl:     map['aadhaar_back_url'],
      panNumber:          map['pan_number'],
      panUrl:             map['pan_url'],
      passportNumber:     map['passport_number'],
      passportUrl:        map['passport_url'],
      fatherName:         map['father_name'],
      motherName:         map['mother_name'],
      spouseName:         map['spouse_name'],
      children:           map['children']  ?? [],
      nominees:           map['nominees']  ?? [],
      bankDetails:        map['bank_details'] != null
          ? Map<String, dynamic>.from(map['bank_details'])
          : null,
      cancelledChequeUrl: map['cancelled_cheque_url'],
      passbookUrl:        map['passbook_url'],
      dateOfBirth:        map['date_of_birth']?.toString(),
      maritalStatus:      map['marital_status'],
      currentAddress:     map['current_address'],
      permanentAddress:   map['permanent_address'],
    );
  }

  // ── Bank convenience getters ──────────────────────────
  String? get accountHolder => bankDetails?['account_holder'] as String?;
  String? get accountNumber => bankDetails?['account_number'] as String?;
  String? get accountType   => bankDetails?['account_type']   as String?;
  String? get ifscCode      => bankDetails?['ifsc_code']      as String?;
  String? get bankName      => bankDetails?['bank_name']      as String?;
  String? get branchName    => bankDetails?['branch_name']    as String?;
}