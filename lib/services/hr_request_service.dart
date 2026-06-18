import '../main.dart';

class HrRequestService {

  static Future<void> approveRequest({
    required int requestId,
    required String reviewerId,
    required String userId,
    required String documentType,
    required String stagingPath,
    String? stagingPathFront,
    String? stagingPathBack,
    String? dateFolder,
  }) async {
    final isAadhaar = documentType == 'aadhaar' &&
        stagingPathFront != null &&
        stagingPathBack  != null;

    String  permanentPath;
    String? permanentPathBack;   // ← declare here

    if (isAadhaar) {
      // ── Move front ───────────────────────────────────────
      final frontExt  = stagingPathFront.split('.').last;
      final frontPerm = '$userId/aadhaar/$dateFolder/front.$frontExt';
      await _moveFile(fromPath: stagingPathFront, toPath: frontPerm);

      // ── Move back ────────────────────────────────────────
      final backExt  = stagingPathBack!.split('.').last;
      final backPerm = '$userId/aadhaar/$dateFolder/back.$backExt';
      await _moveFile(fromPath: stagingPathBack, toPath: backPerm);

      permanentPath     = frontPerm;
      permanentPathBack = backPerm;   // ← assign here
    } else {
      final fileName = stagingPath.split('/').last;
      permanentPath  = '$userId/$documentType/$dateFolder/$fileName';
      await _moveFile(fromPath: stagingPath, toPath: permanentPath);
    }

    await supabase.rpc('approve_document_request', params: {
      'p_request_id':          requestId,
      'p_reviewer_id':         reviewerId,
      'p_permanent_path':      permanentPath,
      'p_permanent_path_back': permanentPathBack,   // null for non-aadhaar ✅
    });
  }

  // ── REJECT ───────────────────────────────────────────────────
  static Future<void> rejectRequest({
    required int requestId,
    required String reviewerId,
    required String stagingPath,
    required String rejectionReason,
  }) async {
    await supabase.storage
        .from('profile-documents')
        .remove([stagingPath]);

    await supabase.rpc('reject_document_request', params: {
      'p_request_id':       requestId,
      'p_reviewer_id':      reviewerId,
      'p_rejection_reason': rejectionReason,
    });
  }

  // ── MARK UNDER REVIEW ────────────────────────────────────────
  static Future<void> markUnderReview({
    required int requestId,
    required String reviewerId,
  }) async {
    await supabase
        .from('requests')
        .update({
      'status':      'under_review',
      'reviewed_by': reviewerId,
      'updated_at':  DateTime.now().toIso8601String(),
    })
        .eq('id', requestId)
        .eq('status', 'pending');
  }

  // ── MOVE FILE ────────────────────────────────────────────────
  static Future<void> _moveFile({
    required String fromPath,
    required String toPath,
  }) async {
    // ── Delete destination if it already exists ──────────
    // (happens when re-approving an updated document)
    try {
      await supabase.storage
          .from('profile-documents')
          .remove([toPath]);
    } catch (_) {
      // Ignore — file simply didn't exist yet, that's fine
    }

    // ── Now move safely ───────────────────────────────────
    await supabase.storage
        .from('profile-documents')
        .move(fromPath, toPath);
  }
}