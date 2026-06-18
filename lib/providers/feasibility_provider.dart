// lib/providers/feasibility_provider.dart

import 'package:flutter/material.dart';
import '../models/spanco/feasibility/feasibility_request.dart';
import '../services/feasibility_service.dart';

/// Simplified Feasibility Provider
/// Manages state for single-manager feasibility workflow
class FeasibilityProvider extends ChangeNotifier {
  final FeasibilityService _feasibilityService = FeasibilityService();

  // ✅ Separate state for different views
  List<FeasibilityRequest> _allRequests = [];
  List<FeasibilityRequest> _pendingRequests = [];
  List<FeasibilityRequest> _filteredRequests = [];
  FeasibilityRequest? _selectedRequest;

  // ✅ Track current view mode
  ViewMode _currentViewMode = ViewMode.all;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Filters
  FeasibilityStatus? _selectedStatus;
  String? _selectedUrgency; // Changed from Urgency enum to String (now in JSONB)
  String _searchQuery = '';
  int _currentPage = 0;
  static const int _requestsPerPage = 20;

  // ✅ Getters - return data based on current view mode
  List<FeasibilityRequest> get requests {
    if (_filteredRequests.isNotEmpty) {
      return _filteredRequests;
    }
    return _currentViewMode == ViewMode.pending
        ? _pendingRequests
        : _allRequests;
  }

  List<FeasibilityRequest> get allRequests => _allRequests;
  List<FeasibilityRequest> get pendingRequests => _pendingRequests;
  ViewMode get currentViewMode => _currentViewMode;

  FeasibilityRequest? get selectedRequest => _selectedRequest;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  FeasibilityStatus? get selectedStatus => _selectedStatus;
  String? get selectedUrgency => _selectedUrgency;
  String get searchQuery => _searchQuery;

  // Pagination
  int get currentPage => _currentPage;
  int get totalPages => (requests.length / _requestsPerPage).ceil();
  bool get hasNextPage => _currentPage < totalPages - 1;
  bool get hasPreviousPage => _currentPage > 0;
  List<FeasibilityRequest> get paginatedRequests {
    final startIndex = _currentPage * _requestsPerPage;
    final endIndex = (startIndex + _requestsPerPage).clamp(0, requests.length);
    return requests.sublist(startIndex, endIndex);
  }

  // =====================================================
  // INITIALIZATION & LOADING
  // =====================================================

  /// Initialize provider
  Future<void> initialize() async {
    await loadRequests();
  }

  /// Load all requests
  Future<void> loadRequests() async {
    _setLoading(true);
    _clearMessages();
    _currentViewMode = ViewMode.all;
    try {
      _allRequests = await _feasibilityService.getRequests();
      _applyFilters();
      _setSuccess('Requests loaded');
    } catch (e) {
      _setError('Failed to load requests: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load pending + under_review requests
  Future<void> loadPendingRequests() async {
    _setLoading(true);
    _clearMessages();
    _currentViewMode = ViewMode.pending;
    try {
      _pendingRequests = await _feasibilityService.getPendingRequests();
      _applyFilters();
      _setSuccess('Pending requests loaded');
    } catch (e) {
      _setError('Failed to load pending requests: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load both datasets at once (for manager view with tabs)
  Future<void> loadBothDatasets() async {
    _setLoading(true);
    _clearMessages();
    try {
      // Load both in parallel for efficiency
      await Future.wait([
        _feasibilityService.getRequests().then((data) {
          _allRequests = data;
        }),
        _feasibilityService.getPendingRequests().then((data) {
          _pendingRequests = data;
        }),
      ]);
      _applyFilters();
      _setSuccess('Data loaded');
    } catch (e) {
      _setError('Failed to load data: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh based on current view mode
  Future<void> refreshRequests() async {
    if (_currentViewMode == ViewMode.pending) {
      await loadPendingRequests();
    } else {
      await loadRequests();
    }
  }

  /// Refresh both views (useful after approval/rejection)
  Future<void> refreshBothViews() async {
    _setLoading(true);
    _clearMessages();
    try {
      await Future.wait([
        _feasibilityService.getRequests().then((data) => _allRequests = data),
        _feasibilityService.getPendingRequests().then((data) => _pendingRequests = data),
      ]);
      _applyFilters();
    } catch (e) {
      _setError('Failed to refresh: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Switch view mode without reloading
  void switchViewMode(ViewMode mode) {
    if (_currentViewMode != mode) {
      _currentViewMode = mode;
      _currentPage = 0;
      clearFilters();
      notifyListeners();
    }
  }

  // =====================================================
  // CREATE & UPDATE
  // =====================================================

  /// ✅ UPDATED: Create a new feasibility request (or reuse cancelled one)
  Future<Map<String, dynamic>?> createRequest(FeasibilityRequest request) async {
    _setLoading(true);
    _clearMessages();
    try {
      final result = await _feasibilityService.createRequest(request);

      // ✅ FIXED: No null check needed - service throws on error
      final newRequest = result['request'] as FeasibilityRequest;
      final wasReused = result['wasReused'] as bool;
      final requestNumber = result['requestNumber'] as String;

      // ✅ Check if request already exists in list (for reused requests)
      final existingIndex = _allRequests.indexWhere((r) => r.id == newRequest.id);

      if (existingIndex != -1) {
        // ✅ Update existing request in list (reused case)
        _allRequests[existingIndex] = newRequest;

        // Update pending list if status is pending
        final pendingIndex = _pendingRequests.indexWhere((r) => r.id == newRequest.id);
        if (newRequest.status == FeasibilityStatus.pending) {
          if (pendingIndex != -1) {
            _pendingRequests[pendingIndex] = newRequest;
          } else {
            _pendingRequests.insert(0, newRequest);
          }
        } else if (pendingIndex != -1) {
          _pendingRequests.removeAt(pendingIndex);
        }
      } else {
        // ✅ Add new request to lists (new request case)
        _allRequests.insert(0, newRequest);
        if (newRequest.status == FeasibilityStatus.pending) {
          _pendingRequests.insert(0, newRequest);
        }
      }

      _applyFilters();

      // ✅ Set appropriate success message
      if (wasReused) {
        _setSuccess('Reactivated cancelled request #$requestNumber');
      } else {
        _setSuccess('Request #$requestNumber created successfully');
      }

      return {
        'request': newRequest,
        'wasReused': wasReused,
        'requestNumber': requestNumber,
      };
    } catch (e) {
      _setError('Failed to create request: $e');
      return null; // ✅ Return null on error
    } finally {
      _setLoading(false);
    }
  }



  /// Get request by ID
  Future<FeasibilityRequest?> getRequestById(int requestId) async {
    try {
      _setLoading(true);
      final request = await _feasibilityService.getRequestById(requestId);
      if (request != null) {
        _selectedRequest = request;
        notifyListeners();
      }
      return request;
    } catch (e) {
      _setError('Failed to fetch request: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get requests by lead ID
  Future<List<FeasibilityRequest>> getRequestsByLead(int leadId) async {
    try {
      _setLoading(true);
      final requests = await _feasibilityService.getRequestsByLead(leadId);
      return requests;
    } catch (e) {
      _setError('Failed to fetch requests: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Start review (Manager picks up request)
  Future<FeasibilityRequest?> startReview(int requestId) async {
    try {
      final updated = await _feasibilityService.startReview(requestId);
      if (updated != null) {
        _updateLocalRequest(updated);
      }
      return updated;
    } catch (e) {
      _setError('Failed to start review: $e');
      return null;
    }
  }

  /// Save draft (Manager saves progress)
  Future<FeasibilityRequest?> saveDraft(
      int requestId,
      Map<String, dynamic> updates,
      ) async {
    _setLoading(true);
    _clearMessages();
    try {
      final updated = await _feasibilityService.saveDraft(requestId, updates);
      if (updated != null) {
        _updateLocalRequest(updated);
        _setSuccess('Draft saved successfully');
        return updated;
      }
    } catch (e) {
      _setError('Failed to save draft: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  /// Approve feasibility
  Future<FeasibilityRequest?> approveFeasibility(
      int requestId, {
        required String remarks,
      }) async {
    _setLoading(true);
    _clearMessages();
    try {
      final updated = await _feasibilityService.approveFeasibility(
        requestId,
        remarks: remarks,
      );
      if (updated != null) {
        _updateLocalRequest(updated);
        _setSuccess('Feasibility approved!');
        return updated;
      }
    } catch (e) {
      _setError('Failed to approve: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  /// Reject feasibility
  Future<FeasibilityRequest?> rejectFeasibility(
      int requestId, {
        required String reason,
      }) async {
    _setLoading(true);
    _clearMessages();
    try {
      final updated = await _feasibilityService.rejectFeasibility(
        requestId,
        reason: reason,
      );
      if (updated != null) {
        _updateLocalRequest(updated);
        _setSuccess('Feasibility rejected');
        return updated;
      }
    } catch (e) {
      _setError('Failed to reject: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  /// Submit final decision (generic update)
  Future<FeasibilityRequest?> submitDecision(
      int requestId,
      Map<String, dynamic> updates,
      ) async {
    _setLoading(true);
    _clearMessages();
    try {
      final updated = await _feasibilityService.updateRequest(requestId, updates);
      if (updated != null) {
        await refreshBothViews();
        _setSuccess('Decision submitted successfully');
        return updated;
      }
    } catch (e) {
      _setError('Failed to submit decision: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  /// Cancel request (Requester)
  Future<void> cancelRequest(int requestId, {String? reason}) async {
    _setLoading(true);
    _clearMessages();
    try {
      await _feasibilityService.cancelRequest(requestId, reason: reason);
      // Remove from both lists
      _allRequests.removeWhere((req) => req.id == requestId);
      _pendingRequests.removeWhere((req) => req.id == requestId);
      _applyFilters();
      _setSuccess('Request cancelled');
    } catch (e) {
      _setError('Failed to cancel: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel pending feasibility request by lead ID
  Future<void> cancelFeasibilityRequest(int leadId) async {
    _setLoading(true);
    _clearMessages();

    try {
      await _feasibilityService.cancelFeasibilityRequest(leadId);

      // ✅ FIXED: Use enum value instead of string
      _allRequests.removeWhere((req) =>
      req.leadId == leadId && req.status == FeasibilityStatus.pending
      );
      _pendingRequests.removeWhere((req) => req.leadId == leadId);

      // Reapply filters to update UI
      _applyFilters();

      // Show success message
      _setSuccess('Feasibility request cancelled successfully');
    } catch (e) {
      // Set error message
      _setError('Failed to cancel feasibility: $e');
    } finally {
      // Always reset loading state
      _setLoading(false);
    }
  }



  // =====================================================
  // FILTERS & SEARCH
  // =====================================================

  /// Set status filter
  void setStatusFilter(FeasibilityStatus? status) {
    _selectedStatus = status;
    _currentPage = 0;
    _applyFilters();
  }

  /// Set urgency filter (String now, from JSONB)
  void setUrgencyFilter(String? urgency) {
    _selectedUrgency = urgency;
    _currentPage = 0;
    _applyFilters();
  }

  /// Search requests
  void search(String query) {
    _searchQuery = query;
    _currentPage = 0;
    _applyFilters();
  }

  /// Clear all filters
  void clearFilters() {
    _selectedStatus = null;
    _selectedUrgency = null;
    _searchQuery = '';
    _currentPage = 0;
    _applyFilters();
  }

  /// Apply filters to current view
  void _applyFilters() {
    // Get the base list based on current view mode
    final baseList = _currentViewMode == ViewMode.pending
        ? _pendingRequests
        : _allRequests;

    _filteredRequests = baseList.where((request) {
      // Status filter
      if (_selectedStatus != null && request.status != _selectedStatus) {
        return false;
      }

      // Urgency filter (from JSONB serviceRequirements)
      if (_selectedUrgency != null &&
          request.serviceRequirements.urgency != _selectedUrgency) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return request.requestNumber?.toLowerCase().contains(query) ?? false ||
            request.serviceLocation.address.toLowerCase().contains(query) ||
            request.serviceLocation.city.toLowerCase().contains(query);
      }

      return true;
    }).toList();

    notifyListeners();
  }

  // =====================================================
  // PAGINATION
  // =====================================================

  void nextPage() {
    if (hasNextPage) {
      _currentPage++;
      notifyListeners();
    }
  }

  void previousPage() {
    if (hasPreviousPage) {
      _currentPage--;
      notifyListeners();
    }
  }

  // =====================================================
  // HELPERS
  // =====================================================

  /// Update local request in both lists
  void _updateLocalRequest(FeasibilityRequest updated) {
    // Update in all requests list
    final allIndex = _allRequests.indexWhere((r) => r.id == updated.id);
    if (allIndex != -1) {
      _allRequests[allIndex] = updated;
    }

    // Update in pending requests list
    final pendingIndex = _pendingRequests.indexWhere((r) => r.id == updated.id);

    // If pending or under_review, should be in pending list
    if (updated.status == FeasibilityStatus.pending ||
        updated.status == FeasibilityStatus.underReview) {
      if (pendingIndex != -1) {
        _pendingRequests[pendingIndex] = updated;
      } else {
        _pendingRequests.insert(0, updated);
      }
    } else {
      // No longer pending - remove from pending list
      if (pendingIndex != -1) {
        _pendingRequests.removeAt(pendingIndex);
      }
    }

    _selectedRequest = updated;
    _applyFilters();
  }

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
}

// ✅ Enum to track view mode
enum ViewMode {
  all,
  pending,
}
