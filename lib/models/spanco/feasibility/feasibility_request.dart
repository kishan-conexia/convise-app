// lib/models/spanco/feasibility/feasibility_request.dart

import 'operational_cost_item.dart';
import 'service_location.dart';
import 'service_requirements.dart';
import 'connectivity_route.dart';
import 'site_survey.dart';
import 'attachment.dart';

enum FeasibilityStatus {
  pending('pending', 'Pending'),
  underReview('under_review', 'Under Review'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  cancelled('cancelled', 'Cancelled');

  final String value;
  final String label;
  const FeasibilityStatus(this.value, this.label);

  static FeasibilityStatus fromString(String value) {
    return FeasibilityStatus.values.firstWhere(
          (s) => s.value == value,
      orElse: () => FeasibilityStatus.pending,
    );
  }
}

class FeasibilityRequest {
  // Core Identity
  final int? id;
  final String? requestNumber;
  final int leadId;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  // Request Info
  final String requestedBy;
  final int requestingDepartment;
  final DateTime requestedAt;

  // Service Details (JSONB)
  final ServiceLocation serviceLocation;
  final ServiceRequirements serviceRequirements;

  // Connectivity Routes (JSONB)
  final ConnectivityRoute? primaryRoute;
  final ConnectivityRoute? secondaryRoute;

  // Site Survey (JSONB)
  final SiteSurvey? siteSurvey;

  // Operational costs (JSONB)
  final List<OperationalCostItem>? operationalCosts;

  // Review Status
  final FeasibilityStatus status;
  final bool? isFeasible;
  final String? feasibilityRemarks;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  // Commercial Assessment
  final double? estimatedCapex;
  final double? estimatedOpex;
  final int? estimatedRoiMonths;
  final bool? isCommerciallyViable;
  final String? commercialRemarks;

  // Timeline
  final int? estimatedInstallationDays;
  final DateTime? expectedCompletionDate;

  // Attachments (JSONB)
  final List<Attachment> attachments;

  // ✅ NEW: Status History (JSONB)
  final List<Map<String, dynamic>>? statusHistory;

  FeasibilityRequest({
    this.id,
    this.requestNumber,
    required this.leadId,
    required this.createdAt,
    required this.updatedAt,
    required this.requestedBy,
    required this.requestingDepartment,
    required this.requestedAt,
    required this.serviceLocation,
    required this.serviceRequirements,
    this.primaryRoute,
    this.secondaryRoute,
    this.siteSurvey,
    this.operationalCosts,
    this.status = FeasibilityStatus.pending,
    this.isFeasible,
    this.feasibilityRemarks,
    this.reviewedBy,
    this.reviewedAt,
    this.estimatedCapex,
    this.estimatedOpex,
    this.estimatedRoiMonths,
    this.isCommerciallyViable,
    this.commercialRemarks,
    this.estimatedInstallationDays,
    this.expectedCompletionDate,
    this.attachments = const [],
    this.statusHistory, // ✅ NEW
  });

  /// Create from Supabase JSON
  factory FeasibilityRequest.fromJson(Map<String, dynamic> json) {
    return FeasibilityRequest(
      id: json['id'] as int?,
      requestNumber: json['request_number'] as String?,
      leadId: json['lead_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      requestedBy: json['requested_by'] as String,
      requestingDepartment: json['requesting_department'] as int,
      requestedAt: DateTime.parse(json['requested_at'] as String),

      // Parse JSONB fields
      serviceLocation: ServiceLocation.fromJson(
          json['service_location'] as Map<String, dynamic>
      ),
      serviceRequirements: ServiceRequirements.fromJson(
          json['service_requirements'] as Map<String, dynamic>
      ),

      primaryRoute: json['primary_route'] != null
          ? ConnectivityRoute.fromJson(json['primary_route'] as Map<String, dynamic>)
          : null,
      secondaryRoute: json['secondary_route'] != null
          ? ConnectivityRoute.fromJson(json['secondary_route'] as Map<String, dynamic>)
          : null,

      siteSurvey: json['site_survey'] != null
          ? SiteSurvey.fromJson(json['site_survey'] as Map<String, dynamic>)
          : null,

      status: FeasibilityStatus.fromString(json['status'] as String),
      isFeasible: json['is_feasible'] as bool?,
      feasibilityRemarks: json['feasibility_remarks'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,

      // Parse operational costs
      operationalCosts: json['operational_costs'] != null
          ? (json['operational_costs'] as List)
          .map((item) => OperationalCostItem.fromJson(item as Map<String, dynamic>))
          .toList()
          : null,

      estimatedCapex: json['estimated_capex'] != null
          ? (json['estimated_capex'] as num).toDouble()
          : null,
      estimatedOpex: json['estimated_opex'] != null
          ? (json['estimated_opex'] as num).toDouble()
          : null,
      estimatedRoiMonths: json['estimated_roi_months'] as int?,
      isCommerciallyViable: json['is_commercially_viable'] as bool?,
      commercialRemarks: json['commercial_remarks'] as String?,

      estimatedInstallationDays: json['estimated_installation_days'] as int?,
      expectedCompletionDate: json['expected_completion_date'] != null
          ? DateTime.parse(json['expected_completion_date'] as String)
          : null,

      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
          .map((item) => Attachment.fromJson(item as Map<String, dynamic>))
          .toList()
          : [],

      // ✅ NEW: Parse status history
      statusHistory: json['status_history'] != null
          ? List<Map<String, dynamic>>.from(
          (json['status_history'] as List).map((item) =>
          Map<String, dynamic>.from(item as Map)
          )
      )
          : null,
    );
  }

  /// Convert to JSON for INSERT (Salesperson creates request)
  Map<String, dynamic> toJsonForInsert() {
    return {
      'lead_id': leadId,
      'requested_by': requestedBy,
      'requesting_department': requestingDepartment,
      'requested_at': requestedAt.toUtc().toIso8601String(),
      'service_location': serviceLocation.toJson(),
      'service_requirements': serviceRequirements.toJson(),
    };
  }

  /// Convert to JSON for UPDATE (Manager fills routes)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (requestNumber != null) 'request_number': requestNumber,
      'lead_id': leadId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'requested_by': requestedBy,
      'requesting_department': requestingDepartment,
      'requested_at': requestedAt.toUtc().toIso8601String(),
      'service_location': serviceLocation.toJson(),
      'service_requirements': serviceRequirements.toJson(),
      if (primaryRoute != null) 'primary_route': primaryRoute!.toJson(),
      if (secondaryRoute != null) 'secondary_route': secondaryRoute!.toJson(),
      if (siteSurvey != null) 'site_survey': siteSurvey!.toJson(),
      'status': status.value,
      if (isFeasible != null) 'is_feasible': isFeasible,
      if (feasibilityRemarks != null) 'feasibility_remarks': feasibilityRemarks,
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      if (reviewedAt != null) 'reviewed_at': reviewedAt!.toUtc().toIso8601String(),
      if (operationalCosts != null)
        'operational_costs': operationalCosts!.map((c) => c.toJson()).toList(),
      if (estimatedCapex != null) 'estimated_capex': estimatedCapex,
      if (estimatedOpex != null) 'estimated_opex': estimatedOpex,
      if (estimatedRoiMonths != null) 'estimated_roi_months': estimatedRoiMonths,
      if (isCommerciallyViable != null) 'is_commercially_viable': isCommerciallyViable,
      if (commercialRemarks != null) 'commercial_remarks': commercialRemarks,
      if (estimatedInstallationDays != null) 'estimated_installation_days': estimatedInstallationDays,
      if (expectedCompletionDate != null)
        'expected_completion_date': expectedCompletionDate!.toIso8601String().split('T')[0],
      'attachments': attachments.map((a) => a.toJson()).toList(),
      // ✅ NEW: Include status history
      if (statusHistory != null) 'status_history': statusHistory,
    };
  }

  /// Copy with method for easy updates
  FeasibilityRequest copyWith({
    int? id,
    String? requestNumber,
    int? leadId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? requestedBy,
    int? requestingDepartment,
    DateTime? requestedAt,
    ServiceLocation? serviceLocation,
    ServiceRequirements? serviceRequirements,
    ConnectivityRoute? primaryRoute,
    ConnectivityRoute? secondaryRoute,
    SiteSurvey? siteSurvey,
    List<OperationalCostItem>? operationalCosts,
    FeasibilityStatus? status,
    bool? isFeasible,
    String? feasibilityRemarks,
    String? reviewedBy,
    DateTime? reviewedAt,
    double? estimatedCapex,
    double? estimatedOpex,
    int? estimatedRoiMonths,
    bool? isCommerciallyViable,
    String? commercialRemarks,
    int? estimatedInstallationDays,
    DateTime? expectedCompletionDate,
    List<Attachment>? attachments,
    List<Map<String, dynamic>>? statusHistory, // ✅ NEW
  }) {
    return FeasibilityRequest(
      id: id ?? this.id,
      requestNumber: requestNumber ?? this.requestNumber,
      leadId: leadId ?? this.leadId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      requestedBy: requestedBy ?? this.requestedBy,
      requestingDepartment: requestingDepartment ?? this.requestingDepartment,
      requestedAt: requestedAt ?? this.requestedAt,
      serviceLocation: serviceLocation ?? this.serviceLocation,
      serviceRequirements: serviceRequirements ?? this.serviceRequirements,
      primaryRoute: primaryRoute ?? this.primaryRoute,
      secondaryRoute: secondaryRoute ?? this.secondaryRoute,
      siteSurvey: siteSurvey ?? this.siteSurvey,
      operationalCosts: operationalCosts ?? this.operationalCosts,
      status: status ?? this.status,
      isFeasible: isFeasible ?? this.isFeasible,
      feasibilityRemarks: feasibilityRemarks ?? this.feasibilityRemarks,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      estimatedCapex: estimatedCapex ?? this.estimatedCapex,
      estimatedOpex: estimatedOpex ?? this.estimatedOpex,
      estimatedRoiMonths: estimatedRoiMonths ?? this.estimatedRoiMonths,
      isCommerciallyViable: isCommerciallyViable ?? this.isCommerciallyViable,
      commercialRemarks: commercialRemarks ?? this.commercialRemarks,
      estimatedInstallationDays: estimatedInstallationDays ?? this.estimatedInstallationDays,
      expectedCompletionDate: expectedCompletionDate ?? this.expectedCompletionDate,
      attachments: attachments ?? this.attachments,
      statusHistory: statusHistory ?? this.statusHistory, // ✅ NEW
    );
  }

  // Computed properties
  bool get hasPrimaryRoute => primaryRoute != null && primaryRoute!.isFeasible;
  bool get hasSecondaryRoute => secondaryRoute != null && secondaryRoute!.isFeasible;
  bool get hasRedundancy => hasPrimaryRoute && hasSecondaryRoute;

  double get totalCapexWithRedundancy {
    double total = 0;
    if (hasPrimaryRoute) {
      total += primaryRoute!.totalCapex ?? 0;
    }
    if (hasSecondaryRoute) {
      total += secondaryRoute!.totalCapex ?? 0;
    }
    return total;
  }

  double get totalCapexPrimaryOnly {
    return hasPrimaryRoute ? (primaryRoute!.totalCapex ?? 0) : 0;
  }

  String get primaryRouteStatus {
    if (primaryRoute == null) return 'Not Evaluated';
    return primaryRoute!.isFeasible ? 'Feasible' : 'Not Feasible';
  }

  String get secondaryRouteStatus {
    if (secondaryRoute == null) return 'Not Evaluated';
    return secondaryRoute!.isFeasible ? 'Feasible' : 'Not Feasible';
  }

  // ✅ NEW: Status history helpers
  bool get hasStatusHistory => statusHistory != null && statusHistory!.isNotEmpty;

  int get historyCount => statusHistory?.length ?? 0;

  Map<String, dynamic>? get latestHistoryEntry {
    if (statusHistory == null || statusHistory!.isEmpty) return null;
    return statusHistory!.last;
  }

  bool get wasReactivated {
    if (statusHistory == null) return false;
    return statusHistory!.any((entry) => entry['event'] == 'reactivated');
  }
}
