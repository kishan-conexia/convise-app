// ignore_for_file: constant_identifier_names

import 'dart:ui';

import '../../utils/colors.dart';
import 'package:flutter/material.dart';

/// SPANCO Lead Model - JSONB Version
/// Matches new spanco_leads table schema with JSONB columns
class SpancoLead {
  // ✅ Core Identity (top-level)
  final int? id;
  final String? leadNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ✅ Stage & Status (top-level for indexing)
  final SpancoStage currentStage;
  final DateTime stageUpdatedAt;
  final LeadStatus status;
  final Priority priority;

  // ✅ Assignment (top-level for filtering)
  final String? assignedTo;
  final DateTime? assignedAt;
  final int? salesTeamId;

  // ✅ NEW: Direct column for expected closure date (for performance)
  final DateTime? expectedClosureDate;

  // ✅ JSONB Fields (nested objects) - RENAMED to avoid conflicts
  final LeadCustomerInfo customerInfo;
  final LeadServiceLocation serviceLocation;
  final LeadServiceRequirements serviceRequirements;
  final LeadCommercialDetails? commercialDetails;
  final LeadTrackingInfo? leadTracking;
  final LeadTimeline? timeline;
  final LeadOutcomeDetails? outcomeDetails;
  final LeadNotes? notes;

  SpancoLead({
    this.id,
    this.leadNumber,
    this.createdAt,
    this.updatedAt,
    this.currentStage = SpancoStage.suspect,
    required this.stageUpdatedAt,
    this.status = LeadStatus.active,
    this.priority = Priority.medium,
    this.assignedTo,
    this.assignedAt,
    this.salesTeamId,
    this.expectedClosureDate, // ✅ NEW: Direct field
    required this.customerInfo,
    required this.serviceLocation,
    required this.serviceRequirements,
    this.commercialDetails,
    this.leadTracking,
    this.timeline,
    this.outcomeDetails,
    this.notes,
  });

  /// Create from Supabase JSON
  factory SpancoLead.fromJson(Map<String, dynamic> json) {
    return SpancoLead(
      id: json['id'] as int?,
      leadNumber: json['lead_number'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      currentStage: SpancoStage.fromString(json['current_stage'] as String),
      stageUpdatedAt: DateTime.parse(json['stage_updated_at'] as String),
      status: LeadStatus.fromString(json['status'] as String),
      priority: Priority.fromString(json['priority'] as String),
      assignedTo: json['assigned_to'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      salesTeamId: json['sales_team_id'] as int?,

      // ✅ NEW: Parse expected_closure_date from direct column
      expectedClosureDate: json['expected_closure_date'] != null
          ? DateTime.parse(json['expected_closure_date'] as String)
          : null,

      // ✅ Parse JSONB fields
      customerInfo: LeadCustomerInfo.fromJson(json['customer_info'] as Map<String, dynamic>),
      serviceLocation: LeadServiceLocation.fromJson(json['service_location'] as Map<String, dynamic>),
      serviceRequirements: LeadServiceRequirements.fromJson(json['service_requirements'] as Map<String, dynamic>),

      commercialDetails: json['commercial_details'] != null
          ? LeadCommercialDetails.fromJson(json['commercial_details'] as Map<String, dynamic>)
          : null,

      leadTracking: json['lead_tracking'] != null
          ? LeadTrackingInfo.fromJson(json['lead_tracking'] as Map<String, dynamic>)
          : null,

      timeline: json['timeline'] != null
          ? LeadTimeline.fromJson(json['timeline'] as Map<String, dynamic>)
          : null,

      outcomeDetails: json['outcome_details'] != null
          ? LeadOutcomeDetails.fromJson(json['outcome_details'] as Map<String, dynamic>)
          : null,

      notes: json['notes'] != null
          ? LeadNotes.fromJson(json['notes'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert to JSON for database insert
  Map<String, dynamic> toJsonForInsert() {
    return {
      'current_stage': currentStage.value,
      'stage_updated_at': stageUpdatedAt.toIso8601String(),
      'status': status.value,
      'priority': priority.value,
      'assigned_to': assignedTo,
      'assigned_at': assignedAt?.toIso8601String(),
      'sales_team_id': salesTeamId,

      // ✅ NEW: Include expected_closure_date as direct column
      'expected_closure_date': expectedClosureDate?.toIso8601String().split('T')[0], // Date only

      // ✅ JSONB fields
      'customer_info': customerInfo.toJson(),
      'service_location': serviceLocation.toJson(),
      'service_requirements': serviceRequirements.toJson(),
      'commercial_details': commercialDetails?.toJson(),
      'lead_tracking': leadTracking?.toJson(),
      'timeline': timeline?.toJson(),
      'outcome_details': outcomeDetails?.toJson(),
      'notes': notes?.toJson(),
    };
  }

  /// Convert to JSON for database update
  Map<String, dynamic> toJsonForUpdate() {
    return toJsonForInsert();
  }

  /// Convert to full JSON (includes all fields)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (leadNumber != null) 'lead_number': leadNumber,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'current_stage': currentStage.value,
      'stage_updated_at': stageUpdatedAt.toIso8601String(),
      'status': status.value,
      'priority': priority.value,
      'assigned_to': assignedTo,
      'assigned_at': assignedAt?.toIso8601String(),
      'sales_team_id': salesTeamId,

      // ✅ NEW: Include expected_closure_date
      'expected_closure_date': expectedClosureDate?.toIso8601String().split('T')[0],

      'customer_info': customerInfo.toJson(),
      'service_location': serviceLocation.toJson(),
      'service_requirements': serviceRequirements.toJson(),
      'commercial_details': commercialDetails?.toJson(),
      'lead_tracking': leadTracking?.toJson(),
      'timeline': timeline?.toJson(),
      'outcome_details': outcomeDetails?.toJson(),
      'notes': notes?.toJson(),
    };
  }

  /// Create a copy with updated fields
  SpancoLead copyWith({
    int? id,
    String? leadNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    SpancoStage? currentStage,
    DateTime? stageUpdatedAt,
    LeadStatus? status,
    Priority? priority,
    String? assignedTo,
    DateTime? assignedAt,
    int? salesTeamId,
    DateTime? expectedClosureDate, // ✅ NEW: Add to copyWith
    LeadCustomerInfo? customerInfo,
    LeadServiceLocation? serviceLocation,
    LeadServiceRequirements? serviceRequirements,
    LeadCommercialDetails? commercialDetails,
    LeadTrackingInfo? leadTracking,
    LeadTimeline? timeline,
    LeadOutcomeDetails? outcomeDetails,
    LeadNotes? notes,
  }) {
    return SpancoLead(
      id: id ?? this.id,
      leadNumber: leadNumber ?? this.leadNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentStage: currentStage ?? this.currentStage,
      stageUpdatedAt: stageUpdatedAt ?? this.stageUpdatedAt,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedAt: assignedAt ?? this.assignedAt,
      salesTeamId: salesTeamId ?? this.salesTeamId,
      expectedClosureDate: expectedClosureDate ?? this.expectedClosureDate, // ✅ NEW
      customerInfo: customerInfo ?? this.customerInfo,
      serviceLocation: serviceLocation ?? this.serviceLocation,
      serviceRequirements: serviceRequirements ?? this.serviceRequirements,
      commercialDetails: commercialDetails ?? this.commercialDetails,
      leadTracking: leadTracking ?? this.leadTracking,
      timeline: timeline ?? this.timeline,
      outcomeDetails: outcomeDetails ?? this.outcomeDetails,
      notes: notes ?? this.notes,
    );
  }

  // ✅ Convenience getters for backward compatibility
  String get customerName => customerInfo.name;
  CustomerType get customerType => customerInfo.type;
  String get contactPhone => customerInfo.phone;
  String? get contactEmail => customerInfo.email;
  String? get contactPerson => customerInfo.contactPerson;
  String? get alternatePhone => customerInfo.alternatePhone;
  String? get companyName => customerInfo.companyName;
  String? get gstin => customerInfo.gstin;
  String? get pan => customerInfo.pan;

  String get serviceAddress => serviceLocation.address;
  String get serviceCity => serviceLocation.city;
  String get serviceState => serviceLocation.state;
  String get servicePincode => serviceLocation.pincode;
  double? get serviceLatitude => serviceLocation.latitude;
  double? get serviceLongitude => serviceLocation.longitude;
  String? get landmark => serviceLocation.landmark;

  ConnectionType get connectionType => serviceRequirements.connectionType;
  String get bandwidthRequired => serviceRequirements.bandwidthRequired;
  String? get serviceType => serviceRequirements.serviceType;
  String? get planInterest => serviceRequirements.planInterest;
  bool get staticIpRequired => serviceRequirements.staticIpRequired;
  int get staticIpCount => serviceRequirements.staticIpCount;
  bool get ipv6Required => serviceRequirements.ipv6Required;
  int get numberOfConnections => serviceRequirements.numberOfConnections;
  int? get currentCustomers => serviceRequirements.currentCustomers;
  int? get expectedCustomers => serviceRequirements.expectedCustomers;

  double? get estimatedValue => commercialDetails?.estimatedValue;
  double? get proposedMonthlyRental => commercialDetails?.proposedMonthlyRental;
  double? get proposedInstallationCharge => commercialDetails?.proposedInstallationCharge;
  double? get proposedSecurityDeposit => commercialDetails?.proposedSecurityDeposit;
  double? get discountPercentage => commercialDetails?.discountPercentage;
  int? get contractPeriodMonths => commercialDetails?.contractPeriodMonths;
  String? get equipmentRequired => commercialDetails?.equipmentRequired;

  LeadSource? get leadSource => leadTracking?.source;
  String? get leadSourceDetails => leadTracking?.sourceDetails;
  String? get referralBy => leadTracking?.referralBy;
  String? get campaignId => leadTracking?.campaignId;

  // ✅ REMOVED: No longer use timeline getter, use direct field
  // DateTime? get expectedClosureDate => timeline?.expectedClosureDate;

  // ✅ Keep other timeline getters for backward compatibility
  DateTime? get actualClosureDate => timeline?.actualClosureDate;
  DateTime? get wonDate => timeline?.wonDate;
  DateTime? get orderDate => timeline?.orderDate;
  String? get installationType => timeline?.installationType;

  String? get lostReason => outcomeDetails?.reason;
  String? get lostRemarks => outcomeDetails?.remarks;

  String? get remarks => notes?.remarks;
  String? get internalNotes => notes?.internalNotes;
}

// =====================================================
// JSONB NESTED CLASSES (RENAMED TO AVOID CONFLICTS)
// =====================================================

/// 1️⃣ Customer Information JSONB
class LeadCustomerInfo {
  final String name;
  final CustomerType type;
  final String? contactPerson;
  final String phone;
  final String? alternatePhone;
  final String? email;
  final String? companyName;
  final String? gstin;
  final String? pan;

  LeadCustomerInfo({
    required this.name,
    required this.type,
    this.contactPerson,
    required this.phone,
    this.alternatePhone,
    this.email,
    this.companyName,
    this.gstin,
    this.pan,
  });

  factory LeadCustomerInfo.fromJson(Map<String, dynamic> json) {
    return LeadCustomerInfo(
      name: json['name'] as String,
      type: CustomerType.fromString(json['type'] as String),
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String,
      alternatePhone: json['alternate_phone'] as String?,
      email: json['email'] as String?,
      companyName: json['company_name'] as String?,
      gstin: json['gstin'] as String?,
      pan: json['pan'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.value,
      'contact_person': contactPerson,
      'phone': phone,
      'alternate_phone': alternatePhone,
      'email': email,
      'company_name': companyName,
      'gstin': gstin,
      'pan': pan,
    };
  }
}

/// 2️⃣ Service Location JSONB
class LeadServiceLocation {
  final String address;
  final String city;
  final String state;
  final String pincode;
  final double? latitude;
  final double? longitude;
  final String? landmark;

  LeadServiceLocation({
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    this.latitude,
    this.longitude,
    this.landmark,
  });

  factory LeadServiceLocation.fromJson(Map<String, dynamic> json) {
    return LeadServiceLocation(
      address: json['address'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      pincode: json['pincode'] as String,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      landmark: json['landmark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'landmark': landmark,
    };
  }
}

/// 3️⃣ Service Requirements JSONB
class LeadServiceRequirements {
  final ConnectionType connectionType;
  final String bandwidthRequired;
  final String? serviceType;
  final String? planInterest;
  final bool staticIpRequired;
  final int staticIpCount;
  final bool ipv6Required;
  final int numberOfConnections;
  // ✅ NEW: Partner-specific fields
  final int? currentCustomers;
  final int? expectedCustomers;

  LeadServiceRequirements({
    required this.connectionType,
    required this.bandwidthRequired,
    this.serviceType,
    this.planInterest,
    this.staticIpRequired = false,
    this.staticIpCount = 0,
    this.ipv6Required = false,
    this.numberOfConnections = 1,
    // ✅ NEW: Add to constructor
    this.currentCustomers,
    this.expectedCustomers,
  });

  factory LeadServiceRequirements.fromJson(Map<String, dynamic> json) {
    return LeadServiceRequirements(
      connectionType: ConnectionType.fromString(json['connection_type'] as String),
      bandwidthRequired: json['bandwidth_required'] as String,
      serviceType: json['service_type'] as String?,
      planInterest: json['plan_interest'] as String?,
      staticIpRequired: json['static_ip_required'] as bool? ?? false,
      staticIpCount: json['static_ip_count'] as int? ?? 0,
      ipv6Required: json['ipv6_required'] as bool? ?? false,
      numberOfConnections: json['number_of_connections'] as int? ?? 1,
      // ✅ NEW: Parse from JSON
      currentCustomers: json['current_customers'] as int?,
      expectedCustomers: json['expected_customers'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'connection_type': connectionType.value,
      'bandwidth_required': bandwidthRequired,
      'service_type': serviceType,
      'plan_interest': planInterest,
      'static_ip_required': staticIpRequired,
      'static_ip_count': staticIpCount,
      'ipv6_required': ipv6Required,
      'number_of_connections': numberOfConnections,
      // ✅ NEW: Add to JSON output
      'current_customers': currentCustomers,
      'expected_customers': expectedCustomers,
    };
  }
}


/// 4️⃣ Commercial Details JSONB
class LeadCommercialDetails {
  final double? estimatedValue;
  final double? proposedMonthlyRental;
  final double? proposedInstallationCharge;
  final double? proposedSecurityDeposit;
  final double? discountPercentage;
  final int? contractPeriodMonths;
  final String? equipmentRequired;

  LeadCommercialDetails({
    this.estimatedValue,
    this.proposedMonthlyRental,
    this.proposedInstallationCharge,
    this.proposedSecurityDeposit,
    this.discountPercentage,
    this.contractPeriodMonths,
    this.equipmentRequired,
  });

  factory LeadCommercialDetails.fromJson(Map<String, dynamic> json) {
    return LeadCommercialDetails(
      estimatedValue: json['estimated_value'] != null
          ? (json['estimated_value'] as num).toDouble()
          : null,
      proposedMonthlyRental: json['proposed_monthly_rental'] != null
          ? (json['proposed_monthly_rental'] as num).toDouble()
          : null,
      proposedInstallationCharge: json['proposed_installation_charge'] != null
          ? (json['proposed_installation_charge'] as num).toDouble()
          : null,
      proposedSecurityDeposit: json['proposed_security_deposit'] != null
          ? (json['proposed_security_deposit'] as num).toDouble()
          : null,
      discountPercentage: json['discount_percentage'] != null
          ? (json['discount_percentage'] as num).toDouble()
          : null,
      contractPeriodMonths: json['contract_period_months'] as int?,
      equipmentRequired: json['equipment_required'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'estimated_value': estimatedValue,
      'proposed_monthly_rental': proposedMonthlyRental,
      'proposed_installation_charge': proposedInstallationCharge,
      'proposed_security_deposit': proposedSecurityDeposit,
      'discount_percentage': discountPercentage,
      'contract_period_months': contractPeriodMonths,
      'equipment_required': equipmentRequired,
    };
  }
}

/// 5️⃣ Lead Tracking JSONB
class LeadTrackingInfo {
  final LeadSource? source;
  final String? sourceDetails;
  final String? referralBy;
  final String? campaignId;

  LeadTrackingInfo({
    this.source,
    this.sourceDetails,
    this.referralBy,
    this.campaignId,
  });

  factory LeadTrackingInfo.fromJson(Map<String, dynamic> json) {
    return LeadTrackingInfo(
      source: json['source'] != null
          ? LeadSource.fromString(json['source'] as String)
          : null,
      sourceDetails: json['source_details'] as String?,
      referralBy: json['referral_by'] as String?,
      campaignId: json['campaign_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source?.value,
      'source_details': sourceDetails,
      'referral_by': referralBy,
      'campaign_id': campaignId,
    };
  }
}

/// 6️⃣ Timeline JSONB
/// ⚠️ NOTE: expected_closure_date is now a direct column in spanco_leads table
/// This class still maintains it for backward compatibility with timeline JSONB
class LeadTimeline {
  final DateTime? expectedClosureDate; // ⚠️ Deprecated: Use direct column instead
  final DateTime? actualClosureDate;
  final DateTime? wonDate;
  final DateTime? orderDate;
  final String? installationType;

  LeadTimeline({
    this.expectedClosureDate,
    this.actualClosureDate,
    this.wonDate,
    this.orderDate,
    this.installationType,
  });

  factory LeadTimeline.fromJson(Map<String, dynamic> json) {
    return LeadTimeline(
      expectedClosureDate: json['expected_closure_date'] != null
          ? DateTime.parse(json['expected_closure_date'] as String)
          : null,
      actualClosureDate: json['actual_closure_date'] != null
          ? DateTime.parse(json['actual_closure_date'] as String)
          : null,
      wonDate: json['won_date'] != null
          ? DateTime.parse(json['won_date'] as String)
          : null,
      orderDate: json['order_date'] != null
          ? DateTime.parse(json['order_date'] as String)
          : null,
      installationType: json['installation_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expected_closure_date': expectedClosureDate?.toIso8601String(),
      'actual_closure_date': actualClosureDate?.toIso8601String(),
      'won_date': wonDate?.toIso8601String(),
      'order_date': orderDate?.toIso8601String(),
      'installation_type': installationType,
    };
  }
}

/// 7️⃣ Outcome Details JSONB (for won/lost leads)
class LeadOutcomeDetails {
  final String? result; // 'won' or 'lost'
  final String? reason;
  final String? remarks;

  LeadOutcomeDetails({
    this.result,
    this.reason,
    this.remarks,
  });

  factory LeadOutcomeDetails.fromJson(Map<String, dynamic> json) {
    return LeadOutcomeDetails(
      result: json['result'] as String?,
      reason: json['reason'] as String?,
      remarks: json['remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'result': result,
      'reason': reason,
      'remarks': remarks,
    };
  }
}

/// 8️⃣ Notes JSONB
class LeadNotes {
  final String? remarks;
  final String? internalNotes;
  final List<String>? tags;

  LeadNotes({
    this.remarks,
    this.internalNotes,
    this.tags,
  });

  factory LeadNotes.fromJson(Map<String, dynamic> json) {
    return LeadNotes(
      remarks: json['remarks'] as String?,
      internalNotes: json['internal_notes'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'remarks': remarks,
      'internal_notes': internalNotes,
      'tags': tags,
    };
  }
}

// =====================================================
// SPANCO STAGE ENUM
// =====================================================

enum SpancoStage {
  suspect('suspect', 'Suspect', 1, false),
  prospect('prospect', 'Prospect', 2, false),
  approach('approach', 'Approach', 3, false),
  negotiation('negotiation', 'Negotiation', 4, false),
  closure('closure', 'Closure', 5, false),
  order('order', 'Order', 6, false),
  won('won', 'Won', 7, true),      // ✅ NEW: Outcome, not a pipeline stage
  lost('lost', 'Lost', 8, true);   // ✅ NEW: Outcome, not a pipeline stage

  final String value;
  final String label;
  final int stageOrder;
  final bool isOutcome; // ✅ NEW: Marks won/lost as outcomes, not active stages

  const SpancoStage(this.value, this.label, this.stageOrder, this.isOutcome);

  /// ✅ UPDATED: Parse from database value
  static SpancoStage fromString(String value) {
    return SpancoStage.values.firstWhere(
          (stage) => stage.value == value,
      orElse: () => SpancoStage.suspect, // Default fallback
    );
  }

  /// ✅ NEW: Get only active pipeline stages (exclude won/lost)
  static List<SpancoStage> get activeStages {
    return SpancoStage.values.where((stage) => !stage.isOutcome).toList();
  }

  /// ✅ NEW: Get only outcome stages (won/lost)
  static List<SpancoStage> get outcomeStages {
    return SpancoStage.values.where((stage) => stage.isOutcome).toList();
  }

  /// ✅ NEW: Check if this is an active pipeline stage
  bool get isActiveStage => !isOutcome;
}


enum CustomerType {
  enterprise('enterprise', 'Enterprise/Partner'),
  business('business', 'Business/Leased Line'),
  individual('individual', 'SME'); // ✅ Update this label

  final String value;
  final String label;
  const CustomerType(this.value, this.label);

  static CustomerType fromString(String value) {
    return CustomerType.values.firstWhere(
          (type) => type.value == value,
      orElse: () => CustomerType.individual,
    );
  }
}

enum ConnectionType {
  fiber('fiber', 'Fiber'),
  wireless('wireless', 'Wireless'),
  leasedLine('leased_line', 'Leased Line'),
  partnerNetwork('partner_network', 'Partner Network');

  final String value;
  final String label;

  const ConnectionType(this.value, this.label);

  static ConnectionType fromString(String value) {
    return ConnectionType.values.firstWhere(
          (type) => type.value == value,
      orElse: () => ConnectionType.fiber,
    );
  }
}

enum LeadSource {
  website('website', 'Website'),
  referral('referral', 'Referral'),
  coldCall('cold_call', 'Cold Call'),
  marketing('marketing', 'Marketing'),
  walkIn('walk_in', 'Walk-in'),
  partner('partner', 'Partner'),
  existingCustomer('existing_customer', 'Existing Customer');

  final String value;
  final String label;

  const LeadSource(this.value, this.label);

  static LeadSource fromString(String value) {
    return LeadSource.values.firstWhere(
          (source) => source.value == value,
      orElse: () => LeadSource.website,
    );
  }
}

enum LeadStatus {
  active('active', 'Active'),
  onHold('on_hold', 'On Hold'),
  won('won', 'Won'),
  lost('lost', 'Lost'),
  cancelled('cancelled', 'Cancelled');

  final String value;
  final String label;

  const LeadStatus(this.value, this.label);

  static LeadStatus fromString(String value) {
    return LeadStatus.values.firstWhere(
          (status) => status.value == value,
      orElse: () => LeadStatus.active,
    );
  }
}

enum Priority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  urgent('urgent', 'Urgent'),
  critical('critical', 'Critical');

  final String value;
  final String label;

  const Priority(this.value, this.label);

  static Priority fromString(String value) {
    return Priority.values.firstWhere(
          (priority) => priority.value == value,
      orElse: () => Priority.medium,
    );
  }
}

/// Extension methods for SpancoStage
extension SpancoStageExtension on SpancoStage {
  /// Get display color for this stage
  Color get color {
    switch (this) {
      case SpancoStage.suspect:
        return AppColors.suspect;
      case SpancoStage.prospect:
        return AppColors.prospect;
      case SpancoStage.approach:
        return AppColors.approach;
      case SpancoStage.negotiation:
        return AppColors.negotiation;
      case SpancoStage.closure:
        return AppColors.closure;
      case SpancoStage.order:
        return AppColors.order;
      case SpancoStage.won:
        return AppColors.won;
      case SpancoStage.lost:
        return AppColors.lost;
    }
  }

  /// Get icon for this stage
  IconData get icon {
    switch (this) {
      case SpancoStage.suspect:
        return Icons.person_search;
      case SpancoStage.prospect:
        return Icons.person_add;
      case SpancoStage.approach:
        return Icons.handshake;
      case SpancoStage.negotiation:
        return Icons.balance;
      case SpancoStage.closure:
        return Icons.request_quote;
      case SpancoStage.order:
        return Icons.shopping_cart;
      case SpancoStage.won:
        return Icons.celebration;
      case SpancoStage.lost:
        return Icons.cancel;
    }
  }
}

/// Extension methods for Priority
extension PriorityExtension on Priority {
  /// Get display color for this priority
  Color get color {
    switch (this) {
      case Priority.low:
        return AppColors.priorityLow;
      case Priority.medium:
        return AppColors.priorityMedium;
      case Priority.high:
        return AppColors.priorityHigh;
      case Priority.urgent:
        return AppColors.priorityUrgent;
      case Priority.critical:
        return AppColors.priorityCritical;
    }
  }

  /// Get icon for this priority
  IconData get icon {
    switch (this) {
      case Priority.low:
        return Icons.arrow_downward;
      case Priority.medium:
        return Icons.remove;
      case Priority.high:
        return Icons.arrow_upward;
      case Priority.urgent:
        return Icons.priority_high;
      case Priority.critical:
        return Icons.warning;
    }
  }
}

/// Extension methods for LeadStatus
extension LeadStatusExtension on LeadStatus {
  /// Get display color for this status
  Color get color {
    switch (this) {
      case LeadStatus.active:
        return AppColors.statusActive;
      case LeadStatus.onHold:
        return AppColors.statusOnHold;
      case LeadStatus.won:
        return AppColors.statusWon;
      case LeadStatus.lost:
        return AppColors.statusLost;
      case LeadStatus.cancelled:
        return AppColors.statusCancelled;
    }
  }
}

/// Extension methods for ConnectionType
extension ConnectionTypeExtension on ConnectionType {
  /// Get display color for this connection type
  Color get color {
    switch (this) {
      case ConnectionType.fiber:
        return AppColors.fiber;
      case ConnectionType.wireless:
        return AppColors.wireless;
      case ConnectionType.leasedLine:
        return AppColors.leasedLine;
      case ConnectionType.partnerNetwork:
        return AppColors.partnerNetwork;
    }
  }
}
