import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/spanco/spanco_lead.dart';
import '../models/spanco/spanco_stage_history.dart';

/// Lead Service
/// Handles all CRUD operations and business logic for SPANCO leads
class LeadService {
  // Singleton pattern
  static final LeadService _instance = LeadService._internal();
  factory LeadService() => _instance;
  LeadService._internal();

  final _supabase = supabase;

  // =====================================================
  // CREATE
  // =====================================================

  /// Create a new lead
  Future<SpancoLead?> createLead(SpancoLead lead) async {
    try {
      // ✅ Use toJsonForInsert() to exclude DB-managed fields
      final response = await _supabase
          .from('spanco_leads')
          .insert(lead.toJsonForInsert())
          .select()
          .single();

      return SpancoLead.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create lead: $e');
    }
  }

  // =====================================================
  // READ
  // =====================================================

  /// Get all leads (with optional filters)
  Future<List<SpancoLead>> getLeads({
    SpancoStage? stage,
    LeadStatus? status,
    String? assignedTo,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      PostgrestFilterBuilder query = _supabase
          .from('spanco_leads')
          .select();

      // Application-level security filter
      if (assignedTo == null) {
        query = query.eq('assigned_to', currentUserId);
      } else {
        query = query.eq('assigned_to', assignedTo);
      }

      // Apply other filters
      if (stage != null) {
        query = query.eq('current_stage', stage.value);
      }
      if (status != null) {
        query = query.eq('status', status.value);
      }

      // ✅ UPDATED: Search with JSONB operators
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'customer_info->>name.ilike.%$searchQuery%,'
              'customer_info->>phone.ilike.%$searchQuery%,'
              'lead_number.ilike.%$searchQuery%',
        );
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
      return (response as List).map((json) => SpancoLead.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch leads: $e');
    }
  }


  /// Get a single lead by ID
  Future<SpancoLead?> getLeadById(int leadId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // ✅ NEW: Application-level security check
      // First, try to get the lead with assigned_to filter
      final response = await _supabase
          .from('spanco_leads')
          .select()
          .eq('id', leadId)
          .eq('assigned_to', currentUserId)  // ✅ ADD THIS
          .maybeSingle();  // Use maybeSingle instead of single

      if (response == null) {
        throw Exception('Lead not found or access denied');
      }

      return SpancoLead.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch lead: $e');
    }
  }


  /// Get leads assigned to current user
  Future<List<SpancoLead>> getMyLeads() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      return await getLeads(assignedTo: userId);
    } catch (e) {
      throw Exception('Failed to fetch my leads: $e');
    }
  }

  /// Get leads by stage
  Future<List<SpancoLead>> getLeadsByStage(SpancoStage stage) async {
    try {
      return await getLeads(stage: stage);
    } catch (e) {
      throw Exception('Failed to fetch leads by stage: $e');
    }
  }

  /// Get lead count by stage (for pipeline dashboard)
  Future<Map<String, int>> getLeadCountByStage() async {
    try {
      final response = await _supabase
          .from('spanco_leads')
          .select('current_stage')
          .eq('status', 'active');

      final Map<String, int> counts = {
        'suspect': 0,
        'prospect': 0,
        'approach': 0,
        'negotiation': 0,
        'closure': 0,
        'order': 0,
      };

      for (var lead in response as List) {
        final stage = lead['current_stage'] as String;
        counts[stage] = (counts[stage] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      throw Exception('Failed to fetch lead counts: $e');
    }
  }

  // =====================================================
  // UPDATE
  // =====================================================

  /// Update a lead
  Future<SpancoLead?> updateLead(int leadId, Map<String, dynamic> updates) async {
    try {
      // ✅ REMOVED: Don't manually add updated_at (DB trigger handles it)
      // Also remove other DB-managed fields if present
      updates.remove('id');
      updates.remove('lead_number');
      updates.remove('created_at');
      updates.remove('updated_at');

      final response = await _supabase
          .from('spanco_leads')
          .update(updates)
          .eq('id', leadId)
          .select()
          .single();

      return SpancoLead.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update lead: $e');
    }
  }

  /// Move lead to next stage
  Future<SpancoLead?> moveToNextStage(
      int leadId, {
        String? reason,
        String? remarks,
      }) async {
    try {
      // Get current lead
      final lead = await getLeadById(leadId);
      if (lead == null) throw Exception('Lead not found');

      // Determine next stage
      final currentStageOrder = lead.currentStage.stageOrder;
      final nextStage = SpancoStage.values.firstWhere(
            (stage) => stage.stageOrder == currentStageOrder + 1,
        orElse: () => lead.currentStage,
      );

      if (nextStage == lead.currentStage) {
        throw Exception('Already at final stage');
      }

      // Update lead stage
      final updatedLead = await updateLead(leadId, {
        'current_stage': nextStage.value,
      });

      // Create stage history entry, handled automatically same in supabase as trigger
      // await createStageHistory(
      //   leadId: leadId,
      //   fromStage: lead.currentStage.value,
      //   toStage: nextStage.value,
      //   reason: reason,
      //   remarks: remarks,
      // );

      return updatedLead;
    } catch (e) {
      throw Exception('Failed to move to next stage: $e');
    }
  }

  /// Move lead to specific stage
  Future<SpancoLead?> moveToStage(
      int leadId,
      SpancoStage newStage, {
        String? reason,
        String? remarks,
      }) async {
    try {
      // Get current lead
      final lead = await getLeadById(leadId);
      if (lead == null) throw Exception('Lead not found');

      if (lead.currentStage == newStage) {
        throw Exception('Lead is already in this stage');
      }

      // Update lead stage
      final updatedLead = await updateLead(leadId, {
        'current_stage': newStage.value,
      });

      // Create stage history entry, handled automatically same in supabase as trigger
      // await createStageHistory(
      //   leadId: leadId,
      //   fromStage: lead.currentStage.value,
      //   toStage: newStage.value,
      //   reason: reason,
      //   remarks: remarks,
      // );

      return updatedLead;
    } catch (e) {
      throw Exception('Failed to move to stage: $e');
    }
  }

  /// Assign lead to user
  Future<SpancoLead?> assignLead(int leadId, String userId) async {
    try {
      return await updateLead(leadId, {
        'assigned_to': userId,
        'assigned_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to assign lead: $e');
    }
  }

  /// ✅ UPDATED: Mark lead as won with 'won' as final stage
  Future<SpancoLead?> markAsWon(int leadId, {DateTime? wonDate}) async {
    try {
      final lead = await getLeadById(leadId);
      if (lead == null) throw Exception('Lead not found');

      final wonDateTime = wonDate ?? DateTime.now().toUtc(); // ✅ Use UTC
      final currentUserId = _supabase.auth.currentUser?.id;

      // ✅ UPDATED: Set current_stage to 'won'
      final updatedLead = await updateLead(leadId, {
        'status': 'won',
        'current_stage': 'won', // ✅ CHANGED: from 'order' to 'won'
        'stage_updated_at': wonDateTime.toIso8601String(), // ✅ NEW: Track stage change
        'timeline': {
          ...?lead.timeline?.toJson(),
          'won_date': wonDateTime.toIso8601String(),
          'actual_closure_date': wonDateTime.toIso8601String(),
        },
        'outcome_details': {
          'result': 'won',
          'won_date': wonDateTime.toIso8601String(),
        },
      });

      // ✅ UPDATED: Use 'won' as to_stage
      // await _supabase.from('spanco_stage_history').insert({
      //   'lead_id': leadId,
      //   'from_stage': lead.currentStage.value,
      //   'to_stage': 'won', // ✅ CHANGED: from 'order' to 'won'
      //   'changed_at': wonDateTime.toIso8601String(),
      //   'change_reason': 'won',
      //   'remarks': '🎉 Lead marked as WON',
      //   'changed_by': currentUserId,
      // });

      return updatedLead;
    } catch (e) {
      throw Exception('Failed to mark as won: $e');
    }
  }




  /// ✅ UPDATED: Mark lead as lost with 'lost' as stage
  Future<SpancoLead?> markAsLost(
      int leadId, {
        required String reason,
        String? remarks,
      }) async {
    try {
      final lead = await getLeadById(leadId);
      if (lead == null) throw Exception('Lead not found');

      final currentUserId = _supabase.auth.currentUser?.id;
      final lostDateTime = DateTime.now().toUtc(); // ✅ Use UTC

      // ✅ UPDATED: Set current_stage to 'lost'
      final updatedLead = await updateLead(leadId, {
        'status': 'lost',
        'current_stage': 'lost', // ✅ NEW: Set to 'lost' stage
        'stage_updated_at': lostDateTime.toIso8601String(), // ✅ NEW: Track stage change
        'outcome_details': {
          'result': 'lost',
          'reason': reason,
          'remarks': remarks,
          'lost_date': lostDateTime.toIso8601String(), // ✅ NEW: Track when lost
        },
      });

      // ✅ UPDATED: Use 'lost' as to_stage
      // await _supabase.from('spanco_stage_history').insert({
      //   'lead_id': leadId,
      //   'from_stage': lead.currentStage.value,
      //   'to_stage': 'lost', // ✅ CHANGED: Use 'lost' instead of current stage
      //   'changed_at': lostDateTime.toIso8601String(),
      //   'change_reason': 'lost',
      //   'remarks': '❌ Lead marked as LOST: $reason${remarks != null && remarks.isNotEmpty ? " - $remarks" : ""}',
      //   'changed_by': currentUserId,
      // });

      return updatedLead;
    } catch (e) {
      throw Exception('Failed to mark as lost: $e');
    }
  }




  /// ✅ UPDATED: Re-qualify a lost lead with stage selection
  Future<SpancoLead?> requalifyLostLead(
      int leadId, {
        required SpancoStage toStage, // ✅ NEW: Required stage parameter
        String? remarks,
      }) async {
    try {
      final lead = await getLeadById(leadId);
      if (lead == null) throw Exception('Lead not found');

      if (lead.status != LeadStatus.lost) {
        throw Exception('Only lost leads can be re-qualified');
      }

      // ✅ Prevent re-qualification to Order stage
      if (toStage == SpancoStage.order) {
        throw Exception('Cannot re-qualify directly to Order stage');
      }

      final currentUserId = _supabase.auth.currentUser?.id;
      final requalifyDateTime = DateTime.now();
      final oldStage = lead.currentStage;

      // ✅ Clear lost status and move to selected stage
      final updates = <String, dynamic>{
        'status': 'active',
        'outcome_details': null,
        'current_stage': toStage.value, // ✅ Use selected stage
        'stage_updated_at': requalifyDateTime.toIso8601String(),
      };

      final updatedLead = await updateLead(leadId, updates);

      // ✅ Create stage history entry for Re-qualification
      // await _supabase.from('spanco_stage_history').insert({
      //   'lead_id': leadId,
      //   'from_stage': oldStage.value,
      //   'to_stage': toStage.value, // ✅ Use selected stage
      //   'changed_at': requalifyDateTime.toIso8601String(),
      //   'change_reason': 'requalified',
      //   'remarks': '♻️ Lead RE-QUALIFIED to ${toStage.label}${remarks != null && remarks.isNotEmpty ? ": $remarks" : ""}',
      //   'changed_by': currentUserId,
      // });

      return updatedLead;
    } catch (e) {
      throw Exception('Failed to re-qualify lead: $e');
    }
  }




  // =====================================================
  // DELETE
  // =====================================================

  /// Delete a lead (soft delete by marking as cancelled)
  Future<void> deleteLead(int leadId) async {
    try {
      await updateLead(leadId, {
        'status': 'cancelled',
      });
    } catch (e) {
      throw Exception('Failed to delete lead: $e');
    }
  }

  /// Permanently delete a lead (use with caution)
  Future<void> permanentlyDeleteLead(int leadId) async {
    try {
      await _supabase.from('spanco_leads').delete().eq('id', leadId);
    } catch (e) {
      throw Exception('Failed to permanently delete lead: $e');
    }
  }

  // =====================================================
  // STAGE HISTORY
  // =====================================================

  /// Create stage history entry, but it is automatically handled in supabase as trigger which do the same like this code
  // Future<SpancoStageHistory?> createStageHistory({
  //   required int leadId,
  //   required String fromStage,
  //   required String toStage,
  //   String? reason,
  //   String? remarks,
  // }) async {
  //   try {
  //     final userId = _supabase.auth.currentUser?.id;
  //     if (userId == null) throw Exception('User not authenticated');
  //
  //     final history = SpancoStageHistory(
  //       createdAt: DateTime.now(),
  //       leadId: leadId,
  //       fromStage: fromStage,
  //       toStage: toStage,
  //       changedAt: DateTime.now(),
  //       changedBy: userId,
  //       changeReason: reason,
  //       remarks: remarks,
  //     );
  //
  //     final response = await _supabase
  //         .from('spanco_stage_history')
  //         .insert(history.toJson())
  //         .select()
  //         .single();
  //
  //     return SpancoStageHistory.fromJson(response);
  //   } catch (e) {
  //     throw Exception('Failed to create stage history: $e');
  //   }
  // }

  /// Get stage history for a lead
  Future<List<SpancoStageHistory>> getStageHistory(int leadId) async {
    try {
      final response = await _supabase
          .from('spanco_stage_history')
          .select()
          .eq('lead_id', leadId)
          .order('changed_at', ascending: false);

      return (response as List)
          .map((json) => SpancoStageHistory.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch stage history: $e');
    }
  }

  // =====================================================
  // ANALYTICS
  // =====================================================

  /// Get conversion rate (won leads / total leads)
  Future<double> getConversionRate() async {
    try {
      final totalCount = await _supabase
          .from('spanco_leads')
          .select('id')
          .neq('status', 'cancelled')
          .count();

      final wonCount = await _supabase
          .from('spanco_leads')
          .select('id')
          .eq('status', 'won')
          .count();

      final total = totalCount.count;
      final won = wonCount.count;

      return total > 0 ? (won / total) * 100 : 0.0;
    } catch (e) {
      throw Exception('Failed to calculate conversion rate: $e');
    }
  }

  /// Get average time in stage (in days)
  Future<Map<String, double>> getAverageTimeInStage() async {
    try {
      final response = await _supabase
          .from('spanco_stage_history')
          .select('from_stage, days_in_previous_stage')
          .not('days_in_previous_stage', 'is', null);

      final Map<String, List<int>> stageData = {};

      for (var record in response as List) {
        final stage = record['from_stage'] as String;
        final days = record['days_in_previous_stage'] as int;

        stageData.putIfAbsent(stage, () => []).add(days);
      }

      final Map<String, double> averages = {};
      stageData.forEach((stage, days) {
        final sum = days.reduce((a, b) => a + b);
        averages[stage] = sum / days.length;
      });

      return averages;
    } catch (e) {
      throw Exception('Failed to calculate average time in stage: $e');
    }
  }



  /// ✅ UPDATED: Check feasibility status for all stages
  Future<Map<String, dynamic>> canMoveToNextStage(int leadId) async {
    try {
      final lead = await getLeadById(leadId);
      if (lead == null) {
        return {
          'canMove': false,
          'reason': 'Lead not found',
          'status': 'error',
        };
      }

      // ✅ UPDATED: Check feasibility status for all active stages
      return await _checkFeasibilityStatus(leadId);
    } catch (e) {
      return {
        'canMove': false,
        'reason': 'Error checking stage requirements: $e',
        'status': 'error',
      };
    }
  }



  /// ✅ UPDATED: Check feasibility status (for all stages, non-blocking)
  Future<Map<String, dynamic>> _checkFeasibilityStatus(int leadId) async {
    try {
      // Query feasibility_requests table for this lead
      final response = await _supabase
          .from('feasibility_requests')
          .select('id, status, is_feasible, feasibility_remarks, request_number')
          .eq('lead_id', leadId)
          .order('created_at', ascending: false)
          .limit(1);

      // ✅ No feasibility request exists
      if (response.isEmpty) {
        return {
          'canMove': true, // ✅ Always allow movement
          'reason': 'No feasibility request has been created for this lead',
          'status': 'no_request',
          'requestNumber': null,
          'conditions': null,
        };
      }

      final feasibility = response.first;
      final status = feasibility['status'] as String;
      final isFeasible = feasibility['is_feasible'] as bool?;
      final requestNumber = feasibility['request_number'] as String?;
      final remarks = feasibility['feasibility_remarks'] as String?;

      // ✅ Check feasibility status
      switch (status) {
        case 'pending':
          return {
            'canMove': true, // ✅ Not blocking
            'reason': 'Feasibility request is awaiting review by technical team',
            'status': 'pending',
            'requestNumber': requestNumber,
            'conditions': null,
          };

        case 'under_review':
          return {
            'canMove': true, // ✅ Not blocking
            'reason': 'Technical team is currently reviewing the feasibility',
            'status': 'under_review',
            'requestNumber': requestNumber,
            'conditions': null,
          };

        case 'approved':
          final hasConditions = remarks != null && remarks.isNotEmpty;
          return {
            'canMove': true,
            'reason': hasConditions
                ? 'Feasibility approved with specific conditions'
                : 'Feasibility approved - all technical requirements can be met',
            'status': 'approved',
            'requestNumber': requestNumber,
            'conditions': hasConditions,
            'isFeasible': isFeasible,
          };

        case 'rejected':
          return {
            'canMove': true, // ✅ Not blocking anymore
            'reason': 'Feasibility assessment shows technical or commercial constraints',
            'status': 'rejected',
            'requestNumber': requestNumber,
            'conditions': null,
          };

        case 'cancelled':
          return {
            'canMove': true,
            'reason': 'Previous feasibility request was cancelled',
            'status': 'cancelled',
            'requestNumber': requestNumber,
            'conditions': null,
          };

        default:
          return {
            'canMove': true,
            'reason': 'Feasibility status unknown',
            'status': 'no_request',
            'requestNumber': null,
            'conditions': null,
          };
      }
    } catch (e) {
      return {
        'canMove': true, // ✅ Allow movement on error
        'reason': 'Unable to check feasibility status',
        'status': 'no_request',
        'requestNumber': null,
        'conditions': null,
      };
    }
  }




}
