import 'package:flutter/foundation.dart';
import '../main.dart';
import '../models/profile_details.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileDetails? profileDetails;
  String? departmentName;
  String? positionDesignation;
  String? positionLevel;
  Map<String, Map<String, dynamic>> pendingRequests = {};

  bool loading = false;
  bool initialized = false;


  Future<void> fetchAll(String userId, {bool forceRefresh = false}) async {
    if (initialized && !forceRefresh) return;   // ← respect forceRefresh
    loading = true;
    notifyListeners();

    try {
      final res = await supabase
          .from('profiles')
          .select('''
          *,
          profile_details(*),
          dept:departments!department(name),
          pos:positions!position(designation, level)
        ''')
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        if (res['profile_details'] != null) {
          profileDetails = ProfileDetails.fromMap(res['profile_details']);
        }
        departmentName      = res['dept']?['name'];
        positionDesignation = res['pos']?['designation'];
        positionLevel       = res['pos']?['level'];
      }
    } catch (e) {
      debugPrint('ProfileProvider fetchAll error: $e');
    }
    // ← called here so it runs every time fetchAll runs
    await fetchPendingDocumentRequests(userId);

    loading = false;
    initialized = true;
    notifyListeners();
  }

  Future<void> fetchPendingDocumentRequests(String userId) async {
    try {
      final res = await supabase
          .from('requests')
          .select('id, new_data, status, request_type, created_at')
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'under_review']);

      pendingRequests = {};

      for (final row in res) {
        final data        = row['new_data'] as Map<String, dynamic>? ?? {};
        final requestType = row['request_type'] as String? ?? '';
        String key;

        if (requestType == 'profile_update') {
          final subtype  = data['subtype'] as String? ?? '';
          final field    = data['field']   as String? ?? '';
          // key = "profile_update|subtype|field"
          // field is empty for children/nominees — that's fine
          key = 'profile_update|$subtype|$field';
        } else {
          // document_upload — keyed by document_type as before
          final docType = data['document_type'] as String? ?? '';
          key = 'document_upload|$docType';
        }

        pendingRequests[key] = Map<String, dynamic>.from(row);
      }
    } catch (e) {
      debugPrint('fetchPendingDocumentRequests error: $e');
    }
    notifyListeners();
  }

  /// Returns true if a pending/under_review request already exists
  /// for the given subtype + optional field key.
  bool hasPendingRequest({
    required String subtype,
    String? fieldKey,
  }) {
    final key = 'profile_update|$subtype|${fieldKey ?? ''}';
    return pendingRequests.containsKey(key);
  }

  /// Existing document-type check — keeps old behaviour intact
  bool hasDocumentPending(String documentType) {
    return pendingRequests.containsKey('document_upload|$documentType');
  }

  void reset() {
    profileDetails       = null;
    departmentName       = null;
    positionDesignation  = null;
    positionLevel        = null;
    pendingRequests      = {};    // ← was missing
    initialized          = false;
    notifyListeners();
  }
}
