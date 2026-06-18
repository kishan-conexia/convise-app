import 'package:flutter/foundation.dart';
import '../main.dart';
import '../models/hr_request.dart';

class HrRequestProvider extends ChangeNotifier {
  List<HrRequest> requests    = [];
  bool loading                = false;
  String activeFilter         = 'pending';  // pending, under_review, all

  Future<void> fetchRequests() async {
    loading = true;
    notifyListeners();

    try {
      // ── Build base query ───────────────────────────────────
      var query = supabase
          .from('requests')
          .select('''
            *,
            profile:profiles!user_id(
              full_name,
              employee_code,
              avatar_url,
              departments!profiles_department_fkey(name)
            )
          ''')
          .eq('request_type', 'profile_update');

      // ── Apply filter BEFORE order ──────────────────────────
      if (activeFilter != 'all') {
        query = query.eq('status', activeFilter);
      } else {
        query = query.inFilter('status',
            ['pending', 'under_review', 'approved', 'rejected']);
      }

      // ── Order last ─────────────────────────────────────────
      final res = await query.order('created_at', ascending: false);

      requests = (res as List)
          .map((r) => HrRequest.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('HrRequestProvider fetchRequests error: $e');
    }

    loading = false;
    notifyListeners();
  }

  void setFilter(String filter) {
    activeFilter = filter;
    fetchRequests();
  }

  // Counts for badges
  int get pendingCount     => requests.where((r) => r.status == 'pending').length;
  int get underReviewCount => requests.where((r) => r.status == 'under_review').length;
}