import 'package:flutter/material.dart';
import '../models/spanco/spanco_lead.dart';
import '../models/spanco/spanco_stage_history.dart';
import '../services/lead_service.dart';

/// Lead Provider
/// Manages lead state and business logic using Provider pattern
class LeadProvider extends ChangeNotifier {
  final LeadService _leadService = LeadService();

  // =====================================================
  // STATE VARIABLES
  // =====================================================

  List<SpancoLead> _leads = [];
  List<SpancoLead> _filteredLeads = [];
  SpancoLead? _selectedLead;
  List<SpancoStageHistory> _stageHistory = [];

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Filter state
  SpancoStage? _selectedStage;
  LeadStatus? _selectedStatus;
  String? _selectedAssignee;
  String _searchQuery = '';
  int _currentPage = 0;
  static const int _leadsPerPage = 20;

  // =====================================================
  // GETTERS
  // =====================================================

  List<SpancoLead> get leads => hasActiveFilters ? _filteredLeads : _leads;

  SpancoLead? get selectedLead => _selectedLead;
  List<SpancoStageHistory> get stageHistory => _stageHistory;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // Filter getters
  SpancoStage? get selectedStage => _selectedStage;
  LeadStatus? get selectedStatus => _selectedStatus;
  String? get selectedAssignee => _selectedAssignee;
  String get searchQuery => _searchQuery;

  // After line 40 (after the filter getters section)
  bool get hasActiveFilters =>
      _selectedStage != null ||
          _selectedStatus != null ||
          _selectedAssignee != null ||
          _searchQuery.isNotEmpty;


  // Pagination getters
  int get currentPage => _currentPage;
  int get totalPages => (_leads.length / _leadsPerPage).ceil();
  bool get hasNextPage => _currentPage < totalPages - 1;
  bool get hasPreviousPage => _currentPage > 0;

  List<SpancoLead> get paginatedLeads {
    final startIndex = _currentPage * _leadsPerPage;
    final endIndex = (startIndex + _leadsPerPage).clamp(0, leads.length);
    return leads.sublist(startIndex, endIndex);
  }

  // =====================================================
  // INITIALIZATION & LOADING
  // =====================================================

  /// Initialize and load all leads
  Future<void> initialize() async {
    await loadLeads();
  }

  /// Load all leads
  Future<void> loadLeads() async {
    _setLoading(true);
    _clearMessages();

    try {
      _leads = await _leadService.getLeads();
      _applyFilters();
      // _setSuccess('Leads loaded successfully');
    } catch (e) {
      _setError('Failed to load leads: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load my assigned leads
  Future<void> loadMyLeads() async {
    _setLoading(true);
    _clearMessages();

    try {
      _leads = await _leadService.getMyLeads();
      _applyFilters();
      _setSuccess('Your leads loaded successfully');
    } catch (e) {
      _setError('Failed to load your leads: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh leads
  Future<void> refreshLeads() async {
    await loadLeads();
  }

  // =====================================================
  // CREATE
  // =====================================================

  /// Create a new lead
  Future<SpancoLead?> createLead(SpancoLead lead) async {
    _setLoading(true);
    _clearMessages();

    try {
      // ✅ Service now uses toJsonForInsert() internally
      final newLead = await _leadService.createLead(lead);
      if (newLead != null) {
        _leads.insert(0, newLead);
        _applyFilters();
        _setSuccess('Lead created successfully');
        return newLead;
      }
    } catch (e) {
      _setError('Failed to create lead: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  // =====================================================
  // READ
  // =====================================================

  /// Get lead by ID
  Future<SpancoLead?> getLeadById(int leadId) async {
    try {
      final lead = await _leadService.getLeadById(leadId);
      if (lead != null) {
        _selectedLead = lead;
        await loadStageHistory(leadId);
        notifyListeners();
      }
      return lead;
    } catch (e) {
      _setError('Failed to fetch lead: $e');
      return null;
    }
  }

  /// Load stage history for selected lead
  Future<void> loadStageHistory(int leadId) async {
    try {
      _stageHistory = await _leadService.getStageHistory(leadId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load stage history: $e');
    }
  }

  // =====================================================
  // UPDATE
  // =====================================================

  /// Update a lead
  Future<SpancoLead?> updateLead(int leadId, Map<String, dynamic> updates) async {
    _setLoading(true);
    _clearMessages();

    try {
      // ✅ Service now auto-removes DB-managed fields
      final updatedLead = await _leadService.updateLead(leadId, updates);
      if (updatedLead != null) {
        final index = _leads.indexWhere((lead) => lead.id == leadId);
        if (index != -1) {
          _leads[index] = updatedLead;
        }
        _selectedLead = updatedLead;
        _applyFilters();
        _setSuccess('Lead updated successfully');
        return updatedLead;
      }
    } catch (e) {
      _setError('Failed to update lead: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  /// Move lead to next stage
  Future<SpancoLead?> moveToNextStage(int leadId, {String? reason, String? remarks}) async {
    _setLoading(true);
    _clearMessages();

    try {
      final updatedLead = await _leadService.moveToNextStage(
        leadId,
        reason: reason,
        remarks: remarks,
      );
      if (updatedLead != null) {
        final index = _leads.indexWhere((lead) => lead.id == leadId);
        if (index != -1) {
          _leads[index] = updatedLead;
        }
        _selectedLead = updatedLead;
        await loadStageHistory(leadId);
        _applyFilters();
        _setSuccess('Lead moved to ${updatedLead.currentStage.label}');
        return updatedLead;
      }
    } catch (e) {
      _setError('Failed to move lead: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  /// Move lead to specific stage
  Future<SpancoLead?> moveToStage(
      int leadId,
      SpancoStage newStage, {
        String? reason,
        String? remarks,
      }) async {
    _setLoading(true);
    _clearMessages();

    try {
      final updatedLead = await _leadService.moveToStage(
        leadId,
        newStage,
        reason: reason,
        remarks: remarks,
      );
      if (updatedLead != null) {
        final index = _leads.indexWhere((lead) => lead.id == leadId);
        if (index != -1) {
          _leads[index] = updatedLead;
        }
        _selectedLead = updatedLead;
        await loadStageHistory(leadId);
        _applyFilters();
        _setSuccess('Lead moved to ${newStage.label}');
        return updatedLead;
      }
    } catch (e) {
      _setError('Failed to move lead: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }


  /// Check if lead can move to next stage
  Future<Map<String, dynamic>> checkStageMovement(int leadId) async {
    try {
      return await _leadService.canMoveToNextStage(leadId);
    } catch (e) {
      return {
        'canMove': false,
        'reason': 'Error checking stage requirements: $e',
        'status': 'error',
      };
    }
  }


  /// Assign lead to user
  Future<SpancoLead?> assignLead(int leadId, String userId) async {
    _setLoading(true);
    _clearMessages();

    try {
      final updatedLead = await _leadService.assignLead(leadId, userId);
      if (updatedLead != null) {
        final index = _leads.indexWhere((lead) => lead.id == leadId);
        if (index != -1) {
          _leads[index] = updatedLead;
        }
        _selectedLead = updatedLead;
        _applyFilters();
        _setSuccess('Lead assigned successfully');
        return updatedLead;
      }
    } catch (e) {
      _setError('Failed to assign lead: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  /// ✅ UPDATED: Mark lead as won
  Future<SpancoLead?> markAsWon(int leadId, {DateTime? wonDate}) async {
    _setLoading(true);
    _clearMessages();

    try {
      final updatedLead = await _leadService.markAsWon(leadId, wonDate: wonDate);
      if (updatedLead != null) {
        final index = _leads.indexWhere((lead) => lead.id == leadId);
        if (index != -1) {
          _leads[index] = updatedLead;
        }
        _selectedLead = updatedLead;
        await loadStageHistory(leadId); // ✅ NEW: Reload stage history
        _applyFilters();
        _setSuccess('Lead marked as won!');
        return updatedLead;
      }
    } catch (e) {
      _setError('Failed to mark as won: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  /// ✅ UPDATED: Mark lead as lost
  Future<SpancoLead?> markAsLost(
      int leadId, {
        required String reason,
        String? remarks,
      }) async {
    _setLoading(true);
    _clearMessages();

    try {
      final updatedLead = await _leadService.markAsLost(
        leadId,
        reason: reason,
        remarks: remarks,
      );
      if (updatedLead != null) {
        final index = _leads.indexWhere((lead) => lead.id == leadId);
        if (index != -1) {
          _leads[index] = updatedLead;
        }
        _selectedLead = updatedLead;
        await loadStageHistory(leadId); // ✅ NEW: Reload stage history
        _applyFilters();
        _setSuccess('Lead marked as lost');
        return updatedLead;
      }
    } catch (e) {
      _setError('Failed to mark as lost: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  /// ✅ UPDATED: Re-qualify a lost lead back to active with stage selection
  Future<SpancoLead?> requalifyLostLead(int leadId, {required SpancoStage toStage}) async {
    _setLoading(true);
    _clearMessages();

    try {
      final updatedLead = await _leadService.requalifyLostLead(
        leadId,
        toStage: toStage, // ✅ Pass selected stage
      );
      if (updatedLead != null) {
        final index = _leads.indexWhere((lead) => lead.id == leadId);
        if (index != -1) {
          _leads[index] = updatedLead;
        }
        _selectedLead = updatedLead;
        await loadStageHistory(leadId);
        _applyFilters();
        _setSuccess('Lead re-qualified and moved to ${toStage.label}');
        return updatedLead;
      }
    } catch (e) {
      _setError('Failed to re-qualify lead: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }



  // =====================================================
  // DELETE
  // =====================================================

  /// Delete a lead (soft delete)
  Future<void> deleteLead(int leadId) async {
    _setLoading(true);
    _clearMessages();

    try {
      await _leadService.deleteLead(leadId);
      _leads.removeWhere((lead) => lead.id == leadId);
      _applyFilters();
      _setSuccess('Lead deleted successfully');
    } catch (e) {
      _setError('Failed to delete lead: $e');
    } finally {
      _setLoading(false);
    }
  }

  // =====================================================
  // FILTERING
  // =====================================================

  /// Set stage filter
  void setStageFilter(SpancoStage? stage) {
    _selectedStage = stage;
    _currentPage = 0;
    _applyFilters();
  }

  /// Set status filter
  void setStatusFilter(LeadStatus? status) {
    _selectedStatus = status;
    _currentPage = 0;
    _applyFilters();
  }

  /// Set assignee filter
  void setAssigneeFilter(String? assignee) {
    _selectedAssignee = assignee;
    _currentPage = 0;
    _applyFilters();
  }

  /// Search leads
  void search(String query) {
    _searchQuery = query;
    _currentPage = 0;
    _applyFilters();
  }

  /// Clear all filters
  void clearFilters() {
    _selectedStage = null;
    _selectedStatus = null;
    _selectedAssignee = null;
    _searchQuery = '';
    _currentPage = 0;
    _applyFilters();
  }

  /// Apply all filters to leads
  void _applyFilters() {
    _filteredLeads = _leads.where((lead) {
      // Stage filter
      if (_selectedStage != null && lead.currentStage != _selectedStage) {
        return false;
      }

      // Status filter
      if (_selectedStatus != null && lead.status != _selectedStatus) {
        return false;
      }

      // Assignee filter
      if (_selectedAssignee != null && lead.assignedTo != _selectedAssignee) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return lead.customerName.toLowerCase().contains(query) ||
            lead.contactPhone.contains(query) ||
            (lead.leadNumber?.toLowerCase().contains(query) ?? false);
      }

      return true;
    }).toList();

    notifyListeners();
  }

  // =====================================================
  // PAGINATION
  // =====================================================

  /// Go to next page
  void nextPage() {
    if (hasNextPage) {
      _currentPage++;
      notifyListeners();
    }
  }

  /// Go to previous page
  void previousPage() {
    if (hasPreviousPage) {
      _currentPage--;
      notifyListeners();
    }
  }

  /// Go to specific page
  void goToPage(int pageNumber) {
    if (pageNumber >= 0 && pageNumber < totalPages) {
      _currentPage = pageNumber;
      notifyListeners();
    }
  }

  /// Reset to first page
  void resetPagination() {
    _currentPage = 0;
    notifyListeners();
  }

  // =====================================================
  // PIPELINE ANALYTICS
  // =====================================================

  /// Get leads grouped by stage
  Map<SpancoStage, List<SpancoLead>> get leadsByStage {
    final Map<SpancoStage, List<SpancoLead>> grouped = {};
    for (var stage in SpancoStage.values) {
      grouped[stage] = _leads.where((lead) => lead.currentStage == stage).toList();
    }
    return grouped;
  }

  /// Get conversion rate
  Future<double> getConversionRate() async {
    try {
      return await _leadService.getConversionRate();
    } catch (e) {
      _setError('Failed to calculate conversion rate: $e');
      return 0.0;
    }
  }

  /// Get average time in stage
  Future<Map<String, double>> getAverageTimeInStage() async {
    try {
      return await _leadService.getAverageTimeInStage();
    } catch (e) {
      _setError('Failed to calculate average time: $e');
      return {};
    }
  }



  // =====================================================
// PUBLIC MESSAGE CLEARING METHODS
// =====================================================

  void clearSuccessMessage() {
    _successMessage = null;
    notifyListeners();
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  // =====================================================
  // PRIVATE HELPERS
  // =====================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _successMessage = null;
    notifyListeners();
  }

  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }




  // 💡 Minor Suggestions (Optional)

  /// Get count of leads by stage (useful for dashboard)
  Map<String, int> get leadsCountByStage {
    final Map<String, int> counts = {};
    for (var stage in SpancoStage.values) {
      counts[stage.value] = _leads
          .where((lead) => lead.currentStage == stage)
          .length;
    }
    return counts;
  }


  /// Quick statistics for dashboard
  Map<String, dynamic> get dashboardStats {
    return {
      'total_leads': _leads.length,
      'active_leads': _leads.where((l) => l.status == LeadStatus.active).length,
      'won_leads': _leads.where((l) => l.status == LeadStatus.won).length,
      'lost_leads': _leads.where((l) => l.status == LeadStatus.lost).length,
      'conversion_rate': (_leads.where((l) => l.status == LeadStatus.won).length /
          _leads.where((l) => l.status != LeadStatus.cancelled).length * 100).toStringAsFixed(1),
    };
  }


  /// ✅ UPDATED: Sort leads by different criteria with priority support
  void sortLeads(String sortBy) {
    switch (sortBy) {
    // ✅ NEW: Priority sorting
      case 'priority_high':
      // High to Low: Critical(4) → High(3) → Medium(2) → Low(1)
        _leads.sort((a, b) => b.priority.index.compareTo(a.priority.index));
        break;

      case 'priority_low':
      // Low to High: Low(1) → Medium(2) → High(3) → Critical(4)
        _leads.sort((a, b) => a.priority.index.compareTo(b.priority.index));
        break;

    // Date sorting
      case 'date_desc':  // ✅ UPDATED: Renamed for consistency
      case 'created_newest':  // Keep old name for backward compatibility
        _leads.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        break;

      case 'date_asc':  // ✅ UPDATED: Renamed for consistency
      case 'created_oldest':  // Keep old name for backward compatibility
        _leads.sort((a, b) => (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000)));
        break;

    // Name sorting
      case 'name_asc':
        _leads.sort((a, b) => a.customerName.toLowerCase().compareTo(b.customerName.toLowerCase()));
        break;

      case 'name_desc':
        _leads.sort((a, b) => b.customerName.toLowerCase().compareTo(a.customerName.toLowerCase()));
        break;

    // Stage sorting
      case 'stage_order':
        _leads.sort((a, b) => a.currentStage.stageOrder.compareTo(b.currentStage.stageOrder));
        break;

      case 'stage_reverse':  // ✅ NEW: Reverse stage order
        _leads.sort((a, b) => b.currentStage.stageOrder.compareTo(a.currentStage.stageOrder));
        break;

    // ✅ NEW: Estimated value sorting
      case 'value_desc':
      // Highest value first
        _leads.sort((a, b) {
          final aValue = a.estimatedValue ?? 0;
          final bValue = b.estimatedValue ?? 0;
          return bValue.compareTo(aValue);
        });
        break;

      case 'value_asc':
      // Lowest value first
        _leads.sort((a, b) {
          final aValue = a.estimatedValue ?? 0;
          final bValue = b.estimatedValue ?? 0;
          return aValue.compareTo(bValue);
        });
        break;

    // ✅ NEW: Expected closure date
      case 'closure_date':
        _leads.sort((a, b) {
          final aDate = a.expectedClosureDate ?? DateTime(2099);
          final bDate = b.expectedClosureDate ?? DateTime(2099);
          return aDate.compareTo(bDate);
        });
        break;

      default:
      // Default: newest first
        _leads.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    }

    _currentPage = 0;
    _applyFilters(); // ✅ UPDATED: Apply filters after sorting to maintain filter state
    notifyListeners();
  }



  /// Assign lead to current user
  // Future<SpancoLead?> assignToMe(int leadId) async {
  //   final currentUserId = _leadService._supabase.auth.currentUser?.id;
  //   if (currentUserId == null) {
  //     _setError('User not authenticated');
  //     return null;
  //   }
  //   return await assignLead(leadId, currentUserId);
  // }


  /// Assign multiple leads to a user
  Future<void> assignLeadsToUser(List<int> leadIds, String userId) async {
    _setLoading(true);
    try {
      for (var leadId in leadIds) {
        await assignLead(leadId, userId);
      }
      _setSuccess('${leadIds.length} leads assigned');
    } catch (e) {
      _setError('Failed to assign leads: $e');
    } finally {
      _setLoading(false);
    }
  }





}



