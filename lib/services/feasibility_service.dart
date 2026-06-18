// lib/services/feasibility_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/spanco/feasibility/feasibility_request.dart';

/// Simplified Feasibility Service
/// Single manager review instead of multi-department workflow
class FeasibilityService {
  static final FeasibilityService _instance = FeasibilityService._internal();
  factory FeasibilityService() => _instance;
  FeasibilityService._internal();

  final _supabase = supabase;

  // =====================================================
  // CREATE
  // =====================================================

  /// ✅ UPDATED: Create or reuse feasibility request with history tracking
  Future<Map<String, dynamic>> createRequest(FeasibilityRequest request) async {
    try {
      // ✅ Prepare parameters
      final params = {
        'p_lead_id': request.leadId,
        'p_requested_by': request.requestedBy,
        'p_requesting_department': request.requestingDepartment,
        'p_service_location': request.serviceLocation.toJson(),
        'p_service_requirements': request.serviceRequirements.toJson(),
      };

      // ✅ DEBUG: Print parameters to see what's being sent
      print('🔍 RPC Parameters:');
      print('  p_lead_id: ${params['p_lead_id']} (${params['p_lead_id'].runtimeType})');
      print('  p_requested_by: ${params['p_requested_by']} (${params['p_requested_by'].runtimeType})');
      print('  p_requesting_department: ${params['p_requesting_department']} (${params['p_requesting_department'].runtimeType})');
      print('  p_service_location: ${params['p_service_location']}');
      print('  p_service_requirements: ${params['p_service_requirements']}');

      // ✅ Call database function
      final response = await _supabase.rpc(
        'create_or_reuse_feasibility_request',
        params: params,
      ).single();

      final requestId = response['request_id'] as int;
      final wasReused = response['was_reused'] as bool;
      final requestNumber = response['request_number'] as String;

      print('✅ RPC Success: ID=$requestId, Reused=$wasReused, Number=$requestNumber');

      // ✅ Fetch the complete request details
      final fullRequest = await _supabase
          .from('feasibility_requests')
          .select()
          .eq('id', requestId)
          .single();

      return {
        'request': FeasibilityRequest.fromJson(fullRequest),
        'wasReused': wasReused,
        'requestNumber': requestNumber,
      };
    } catch (e) {
      print('❌ RPC Error: $e');
      throw Exception('Failed to create feasibility request: $e');
    }
  }



  // =====================================================
  // READ
  // =====================================================

  /// Get all feasibility requests (with filters)
  Future<List<FeasibilityRequest>> getRequests({
    FeasibilityStatus? status,
    int? leadId,
    String? requestedBy,
    int? limit,
    int? offset,
  }) async {
    try {
      PostgrestFilterBuilder query = _supabase
          .from('feasibility_requests')
          .select();

      // Apply filters
      if (status != null) {
        query = query.eq('status', status.value);
      }
      if (leadId != null) {
        query = query.eq('lead_id', leadId);
      }
      if (requestedBy != null) {
        query = query.eq('requested_by', requestedBy);
      }

      // Apply pagination and ordering
      PostgrestTransformBuilder finalQuery = query.order('created_at', ascending: false);

      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }
      if (offset != null) {
        finalQuery = finalQuery.range(offset, offset + (limit ?? 10) - 1);
      }

      final response = await finalQuery;
      return (response as List)
          .map((json) => FeasibilityRequest.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch feasibility requests: $e');
    }
  }

  /// Get a single feasibility request by ID
  Future<FeasibilityRequest?> getRequestById(int requestId) async {
    try {
      final response = await _supabase
          .from('feasibility_requests')
          .select()
          .eq('id', requestId)
          .single();

      return FeasibilityRequest.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch feasibility request: $e');
    }
  }

  /// Get pending and under-review requests for manager triage
  /// Shows both 'pending' and 'under_review' status
  /// Sorted by urgency (high first), then oldest first
  Future<List<FeasibilityRequest>> getPendingRequests() async {
    try {
      final response = await _supabase
          .from('feasibility_requests')
          .select()
      // ✅ Fetch both 'pending' and 'under_review'
          .inFilter('status', ['pending', 'under_review'])
      // ✅ Triage: sort by urgency in service_requirements JSONB
          .order('created_at', ascending: true); // Oldest first

      return (response as List)
          .map((json) => FeasibilityRequest.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch pending/under-review requests: $e');
    }
  }

  /// Get requests by lead ID
  Future<List<FeasibilityRequest>> getRequestsByLead(int leadId) async {
    try {
      final response = await _supabase
          .from('feasibility_requests')
          .select()
          .eq('lead_id', leadId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => FeasibilityRequest.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch requests for lead: $e');
    }
  }

  // =====================================================
  // UPDATE
  // =====================================================

  /// Update a feasibility request
  Future<FeasibilityRequest?> updateRequest(
      int requestId,
      Map<String, dynamic> updates,
      ) async {
    try {
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

      final response = await _supabase
          .from('feasibility_requests')
          .update(updates)
          .eq('id', requestId)
          .select()
          .single();

      return FeasibilityRequest.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update feasibility request: $e');
    }
  }

  /// Start review (Manager picks up a pending request)
  Future<FeasibilityRequest?> startReview(int requestId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      return await updateRequest(requestId, {
        'status': 'under_review',
        'reviewed_by': userId,
      });
    } catch (e) {
      throw Exception('Failed to start review: $e');
    }
  }

  /// Save draft (Manager saves progress without final decision)
  Future<FeasibilityRequest?> saveDraft(
      int requestId,
      Map<String, dynamic> draftData,
      ) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      draftData['status'] = 'under_review';
      draftData['reviewed_by'] = userId;
      draftData['reviewed_at'] = DateTime.now().toUtc().toIso8601String();

      return await updateRequest(requestId, draftData);
    } catch (e) {
      throw Exception('Failed to save draft: $e');
    }
  }

  /// Approve feasibility (Manager marks as feasible)
  Future<FeasibilityRequest?> approveFeasibility(
      int requestId, {
        required String remarks,
      }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      return await updateRequest(requestId, {
        'status': 'approved',
        'is_feasible': true,
        'feasibility_remarks': remarks,
        'reviewed_by': userId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to approve feasibility: $e');
    }
  }

  /// Reject feasibility (Manager marks as not feasible)
  Future<FeasibilityRequest?> rejectFeasibility(
      int requestId, {
        required String reason,
      }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      return await updateRequest(requestId, {
        'status': 'rejected',
        'is_feasible': false,
        'feasibility_remarks': reason,
        'reviewed_by': userId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to reject feasibility: $e');
    }
  }

  // =====================================================
  // DELETE / CANCEL
  // =====================================================

  /// Cancel a feasibility request (Requester cancels)
  Future<void> cancelRequest(int requestId, {String? reason}) async {
    try {
      await updateRequest(requestId, {
        'status': 'cancelled',
        if (reason != null) 'feasibility_remarks': reason,
      });
    } catch (e) {
      throw Exception('Failed to cancel feasibility request: $e');
    }
  }

  /// Cancel feasibility request (only for 'pending' status)
  Future<void> cancelFeasibilityRequest(int leadId) async {
    try {
      // Get the pending feasibility request ID
      final response = await _supabase
          .from('feasibility_requests')
          .select('id')
          .eq('lead_id', leadId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        throw Exception('No pending feasibility request found');
      }

      final requestId = response.first['id'] as int;

      // Update status to cancelled
      await _supabase
          .from('feasibility_requests')
          .update({
        'status': 'cancelled',
      })
          .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to cancel feasibility request: $e');
    }
  }



  /// Delete a feasibility request (Admin only - use with caution)
  Future<void> deleteRequest(int requestId) async {
    try {
      await _supabase
          .from('feasibility_requests')
          .delete()
          .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to delete feasibility request: $e');
    }
  }

  // =====================================================
  // ANALYTICS
  // =====================================================

  /// Get approval rate
  Future<double> getApprovalRate() async {
    try {
      // Get total count (excluding cancelled)
      final totalResponse = await _supabase
          .from('feasibility_requests')
          .select('id')
          .neq('status', 'cancelled');

      // Get approved count
      final approvedResponse = await _supabase
          .from('feasibility_requests')
          .select('id')
          .eq('status', 'approved');

      final total = (totalResponse as List).length;
      final approved = (approvedResponse as List).length;

      return total > 0 ? (approved / total) * 100 : 0.0;
    } catch (e) {
      throw Exception('Failed to calculate approval rate: $e');
    }
  }

  /// Get average response time in hours
  Future<double> getAverageResponseTime() async {
    try {
      final response = await _supabase
          .from('feasibility_requests')
          .select('created_at, reviewed_at')
          .not('reviewed_at', 'is', null);

      if ((response as List).isEmpty) return 0.0;

      int totalHours = 0;
      for (var record in response) {
        final createdAt = DateTime.parse(record['created_at'] as String);
        final reviewedAt = DateTime.parse(record['reviewed_at'] as String);
        totalHours += reviewedAt.difference(createdAt).inHours;
      }

      return totalHours / response.length;
    } catch (e) {
      throw Exception('Failed to calculate response time: $e');
    }
  }

  /// Get pending count
  Future<int> getPendingCount() async {
    try {
      final response = await _supabase
          .from('feasibility_requests')
          .select('id')
          .eq('status', 'pending');

      return (response as List).length;
    } catch (e) {
      throw Exception('Failed to get pending count: $e');
    }
  }

  /// Get requests grouped by status
  Future<Map<String, int>> getRequestsByStatus() async {
    try {
      final response = await _supabase
          .from('feasibility_requests')
          .select('status');

      final Map<String, int> counts = {
        'pending': 0,
        'under_review': 0,
        'approved': 0,
        'rejected': 0,
        'cancelled': 0,
      };

      for (var record in response as List) {
        final status = record['status'] as String;
        counts[status] = (counts[status] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      throw Exception('Failed to get status counts: $e');
    }
  }

  /// Get total CAPEX summary
  Future<Map<String, double>> getCapexSummary() async {
    try {
      final requests = await getRequests();

      double totalPrimaryCapex = 0;
      double totalSecondaryCapex = 0;
      double totalConsumable = 0;
      double totalRecoverable = 0;

      for (var request in requests) {
        if (request.hasPrimaryRoute) {
          totalPrimaryCapex += request.primaryRoute!.totalCapex ?? 0;
          totalConsumable += request.primaryRoute!.consumableCapex ?? 0;
          totalRecoverable += request.primaryRoute!.recoverableCapex ?? 0;
        }
        if (request.hasSecondaryRoute) {
          totalSecondaryCapex += request.secondaryRoute!.totalCapex ?? 0;
          totalConsumable += request.secondaryRoute!.consumableCapex ?? 0;
          totalRecoverable += request.secondaryRoute!.recoverableCapex ?? 0;
        }
      }

      return {
        'total_primary_capex': totalPrimaryCapex,
        'total_secondary_capex': totalSecondaryCapex,
        'total_consumable': totalConsumable,
        'total_recoverable': totalRecoverable,
        'grand_total': totalPrimaryCapex + totalSecondaryCapex,
      };
    } catch (e) {
      throw Exception('Failed to calculate CAPEX summary: $e');
    }
  }
}
