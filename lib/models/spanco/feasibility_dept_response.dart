// import 'dart:ui';
// import 'package:flutter/material.dart';
//
// /// Feasibility Department Response Model
// /// Tracks individual department responses to feasibility requests
// class FeasibilityDeptResponse {
//   // Primary Key
//   final int? id;
//   final DateTime createdAt;
//   final DateTime updatedAt;
//
//   // Link to Request
//   final int requestId;
//
//   // Department Information
//   final int departmentId;
//   final String departmentName; // inventory, noc, feasibility, fieldops, finance
//
//   // Response Details
//   final String responseStatus; // pending, approved, rejected, conditional, etc.
//   final String? remarks;
//   final String? detailedComments;
//
//   // Responder Information
//   final String? respondedBy; // UUID
//   final DateTime? respondedAt;
//
//   // Department-Specific Fields
//   final Map<String, dynamic>? responseData; // JSONB for flexible storage
//
//   // For Inventory Department
//   final bool? inventoryAvailable;
//   final String? itemsAvailable;
//   final String? itemsUnavailable;
//   final int? estimatedProcurementDays;
//
//   // For NOC Department (Can Veto)
//   final bool? nocApproved;
//   final String? networkCapacityCheck;
//   final String? conflictingServices;
//   final String? recommendedSolution;
//
//   // For Feasibility Department
//   final bool? technicallyFeasible;
//   final String? feasibilityType; // full, partial, not_feasible
//   final String? alternativeSolution;
//   final int? complexityLevel; // 1-5
//
//   // For Field Ops Department (Can Veto)
//   final bool? siteAccessible;
//   final bool? permissionsRequired;
//   final String? siteConditions;
//   final int? estimatedWorkDays;
//
//   // For Finance Department
//   final bool? financiallyViable;
//   final double? estimatedCost;
//   final double? estimatedRevenue;
//   final String? paymentTerms;
//   final String? riskAssessment;
//
//   // Attachments
//   final String? attachmentUrl;
//   final List<String>? attachmentUrls; // Multiple files
//
//   // Priority & SLA
//   final int? slaHours; // Expected response time
//   final DateTime? slaDeadline;
//   final bool? slaBreached;
//
//   FeasibilityDeptResponse({
//     this.id,
//     required this.createdAt,
//     required this.updatedAt,
//     required this.requestId,
//     required this.departmentId,
//     required this.departmentName,
//     required this.responseStatus,
//     this.remarks,
//     this.detailedComments,
//     this.respondedBy,
//     this.respondedAt,
//     this.responseData,
//     this.inventoryAvailable,
//     this.itemsAvailable,
//     this.itemsUnavailable,
//     this.estimatedProcurementDays,
//     this.nocApproved,
//     this.networkCapacityCheck,
//     this.conflictingServices,
//     this.recommendedSolution,
//     this.technicallyFeasible,
//     this.feasibilityType,
//     this.alternativeSolution,
//     this.complexityLevel,
//     this.siteAccessible,
//     this.permissionsRequired,
//     this.siteConditions,
//     this.estimatedWorkDays,
//     this.financiallyViable,
//     this.estimatedCost,
//     this.estimatedRevenue,
//     this.paymentTerms,
//     this.riskAssessment,
//     this.attachmentUrl,
//     this.attachmentUrls,
//     this.slaHours,
//     this.slaDeadline,
//     this.slaBreached,
//   });
//
//   /// Create from Supabase JSON
//   factory FeasibilityDeptResponse.fromJson(Map<String, dynamic> json) {
//     return FeasibilityDeptResponse(
//       id: json['id'] as int?,
//       createdAt: DateTime.parse(json['created_at'] as String),
//       updatedAt: DateTime.parse(json['updated_at'] as String),
//       requestId: json['request_id'] as int,
//       departmentId: json['department_id'] as int,
//       departmentName: json['department_name'] as String,
//       responseStatus: json['response_status'] as String,
//       remarks: json['remarks'] as String?,
//       detailedComments: json['detailed_comments'] as String?,
//       respondedBy: json['responded_by'] as String?,
//       respondedAt: json['responded_at'] != null
//           ? DateTime.parse(json['responded_at'] as String)
//           : null,
//       responseData: json['response_data'] as Map<String, dynamic>?,
//       inventoryAvailable: json['inventory_available'] as bool?,
//       itemsAvailable: json['items_available'] as String?,
//       itemsUnavailable: json['items_unavailable'] as String?,
//       estimatedProcurementDays: json['estimated_procurement_days'] as int?,
//       nocApproved: json['noc_approved'] as bool?,
//       networkCapacityCheck: json['network_capacity_check'] as String?,
//       conflictingServices: json['conflicting_services'] as String?,
//       recommendedSolution: json['recommended_solution'] as String?,
//       technicallyFeasible: json['technically_feasible'] as bool?,
//       feasibilityType: json['feasibility_type'] as String?,
//       alternativeSolution: json['alternative_solution'] as String?,
//       complexityLevel: json['complexity_level'] as int?,
//       siteAccessible: json['site_accessible'] as bool?,
//       permissionsRequired: json['permissions_required'] as bool?,
//       siteConditions: json['site_conditions'] as String?,
//       estimatedWorkDays: json['estimated_work_days'] as int?,
//       financiallyViable: json['financially_viable'] as bool?,
//       estimatedCost: json['estimated_cost'] != null
//           ? (json['estimated_cost'] as num).toDouble()
//           : null,
//       estimatedRevenue: json['estimated_revenue'] != null
//           ? (json['estimated_revenue'] as num).toDouble()
//           : null,
//       paymentTerms: json['payment_terms'] as String?,
//       riskAssessment: json['risk_assessment'] as String?,
//       attachmentUrl: json['attachment_url'] as String?,
//       attachmentUrls: json['attachment_urls'] != null
//           ? List<String>.from(json['attachment_urls'] as List)
//           : null,
//       slaHours: json['sla_hours'] as int?,
//       slaDeadline: json['sla_deadline'] != null
//           ? DateTime.parse(json['sla_deadline'] as String)
//           : null,
//       slaBreached: json['sla_breached'] as bool?,
//     );
//   }
//
//   /// Convert to Supabase JSON
//   Map<String, dynamic> toJson() {
//     return {
//       if (id != null) 'id': id,
//       'created_at': createdAt.toIso8601String(),
//       'updated_at': updatedAt.toIso8601String(),
//       'request_id': requestId,
//       'department_id': departmentId,
//       'department_name': departmentName,
//       'response_status': responseStatus,
//       'remarks': remarks,
//       'detailed_comments': detailedComments,
//       'responded_by': respondedBy,
//       'responded_at': respondedAt?.toIso8601String(),
//       'response_data': responseData,
//       'inventory_available': inventoryAvailable,
//       'items_available': itemsAvailable,
//       'items_unavailable': itemsUnavailable,
//       'estimated_procurement_days': estimatedProcurementDays,
//       'noc_approved': nocApproved,
//       'network_capacity_check': networkCapacityCheck,
//       'conflicting_services': conflictingServices,
//       'recommended_solution': recommendedSolution,
//       'technically_feasible': technicallyFeasible,
//       'feasibility_type': feasibilityType,
//       'alternative_solution': alternativeSolution,
//       'complexity_level': complexityLevel,
//       'site_accessible': siteAccessible,
//       'permissions_required': permissionsRequired,
//       'site_conditions': siteConditions,
//       'estimated_work_days': estimatedWorkDays,
//       'financially_viable': financiallyViable,
//       'estimated_cost': estimatedCost,
//       'estimated_revenue': estimatedRevenue,
//       'payment_terms': paymentTerms,
//       'risk_assessment': riskAssessment,
//       'attachment_url': attachmentUrl,
//       'attachment_urls': attachmentUrls,
//       'sla_hours': slaHours,
//       'sla_deadline': slaDeadline?.toIso8601String(),
//       'sla_breached': slaBreached,
//     };
//   }
//
//   /// Get response time in hours
//   int? get responseTimeHours {
//     if (respondedAt == null) return null;
//     return respondedAt!.difference(createdAt).inHours;
//   }
//
//   /// Check if response is overdue
//   bool get isOverdue {
//     if (slaDeadline == null || respondedAt != null) return false;
//     return DateTime.now().isAfter(slaDeadline!);
//   }
//
//   /// Get department color
//   Color getDepartmentColor() {
//     switch (departmentName.toLowerCase()) {
//       case 'inventory':
//         return Colors.blue;
//       case 'noc':
//         return Colors.orange;
//       case 'feasibility':
//         return Colors.purple;
//       case 'fieldops':
//         return Colors.green;
//       case 'finance':
//         return Colors.red;
//       default:
//         return Colors.grey;
//     }
//   }
// }
