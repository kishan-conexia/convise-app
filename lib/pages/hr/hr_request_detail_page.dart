import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../models/hr_request.dart';
import '../../services/hr_request_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/uploads/document_viewer.dart';
import '../../main.dart';

class HrRequestDetailPage extends StatefulWidget {
  final HrRequest request;

  const HrRequestDetailPage({super.key, required this.request});

  @override
  State<HrRequestDetailPage> createState() => _HrRequestDetailPageState();
}

class _HrRequestDetailPageState extends State<HrRequestDetailPage> {
  final _rejectReasonCtrl = TextEditingController();
  final _formKey          = GlobalKey<FormState>();

  bool    _processing   = false;
  String? _error;
  String? _signedUrl;
  bool    _loadingUrl   = true;

  // ── Helpers ────────────────────────────────────────────────
  // True for field/list updates (nominees, children, profile_field, device_change)
  bool get _isProfileUpdate =>
      widget.request.documentType.isEmpty;

  String get _subtype =>
      widget.request.newData['subtype'] as String? ?? '';

  // True when new_data has a document_type (aadhaar, pan, cheque, etc.)
  bool get _isDocumentRequest =>
      widget.request.documentType.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isDocumentRequest) {
      _loadSignedUrl();
    } else {
      setState(() => _loadingUrl = false); // no file for profile_update
    }
  }

  @override
  void dispose() {
    _rejectReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSignedUrl() async {
    // Aadhaar uses dual paths — handled separately in _loadBothSignedUrls()
    if (widget.request.isDualPhoto) {
      setState(() => _loadingUrl = false);
      return;
    }

    // Rejected requests have their files deleted — nothing to load
    if (widget.request.status == 'rejected') {
      setState(() => _loadingUrl = false);
      return; 
    }

    try {
      String? storagePath;

      if (widget.request.status == 'approved') {
        // File was moved to permanent storage — fetch path from profile_details
        final urlCol = _urlColumnForDocType(widget.request.documentType);
        final result = await supabase
            .from('profile_details')
            .select(urlCol)
            .eq('user_id', widget.request.userId)
            .maybeSingle();
        storagePath = result?[urlCol] as String?;
      } else {
        // pending / under_review — file is still at the staging path
        storagePath = widget.request.stagingPath;
      }

      if (storagePath == null || storagePath.isEmpty) {
        setState(() => _loadingUrl = false);
        return;
      }

      final url = await supabase.storage
          .from('profile-documents')
          .createSignedUrl(storagePath, 3600);
      setState(() { _signedUrl = url; _loadingUrl = false; });
    } catch (_) {
      setState(() => _loadingUrl = false);
    }
  }

  Future<void> _markUnderReview() async {
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() { _processing = true; _error = null; });

    try {
      await HrRequestService.markUnderReview(
        requestId:  widget.request.id,
        reviewerId: appState.userId,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Failed to update status. Try again.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _approve() async {
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() { _processing = true; _error = null; });

    try {
      if (_isProfileUpdate) {
        // ── Universal RPC — no file movement needed ────────────
        await supabase.rpc('approve_profile_update_request', params: {
          'p_request_id':  widget.request.id,
          'p_reviewer_id': appState.userId,
        });
      } else {
        // ── Document request — move file + update profile_details
        await HrRequestService.approveRequest(
          requestId:        widget.request.id,
          reviewerId:       appState.userId,
          userId:           widget.request.userId,
          documentType:     widget.request.documentType,
          stagingPath:      widget.request.stagingPath,
          stagingPathFront: widget.request.isDualPhoto
              ? widget.request.stagingPathFront : null,
          stagingPathBack:  widget.request.isDualPhoto
              ? widget.request.stagingPathBack : null,
          dateFolder:       widget.request.dateFolder.isNotEmpty
              ? widget.request.dateFolder : null,
        );
      }
      if (mounted) _showResultSheet(approved: true);
    } catch (e) {
      debugPrint('Approve error: $e');
      setState(() => _error = 'Failed to approve request. Try again.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _reject() async {
    if (!_formKey.currentState!.validate()) return;
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() { _processing = true; _error = null; });

    try {
      await HrRequestService.rejectRequest(
        requestId:       widget.request.id,
        reviewerId:      appState.userId,
        stagingPath:     widget.request.stagingPath,
        rejectionReason: _rejectReasonCtrl.text.trim(),
      );
      if (mounted) {
        _showResultSheet(approved: false);
      }
    } catch (e) {
      debugPrint('Reject error: $e');
      setState(() => _error = 'Failed to reject request. Try again.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showResultSheet({required bool approved}) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: approved
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                approved
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                size: 56,
                color: approved ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              approved ? 'Request Approved' : 'Request Rejected',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              approved
                  ? 'Document has been moved to permanent storage and profile updated successfully.'
                  : 'Request has been rejected and the uploaded file has been removed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close sheet
                Navigator.pop(context); // back to list
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                approved ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.cancel_outlined,
                          color: Colors.red.shade600, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reject Request',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                        Text('Provide a reason for rejection',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Reason field
                TextFormField(
                  controller: _rejectReasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                    'e.g. Document is blurry, incorrect document uploaded...',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Rejection reason is required'
                      : null,
                ),
                const SizedBox(height: 20),

                // Confirm reject button
                ElevatedButton.icon(
                  onPressed: _processing
                      ? null
                      : () {
                    Navigator.pop(context);
                    _reject();
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Confirm Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending     = widget.request.status == 'pending';
    final isUnderReview = widget.request.status == 'under_review';
    final isActionable  = isPending || isUnderReview;
    final docType       = widget.request.documentType;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: const Text('Request Detail',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white70,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade400,
                  Colors.blue.shade600,
                  Colors.blue.shade800
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20)),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [

            // ── Employee Card ──────────────────────────────
            _SectionCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: widget.request.avatarUrl != null &&
                        widget.request.avatarUrl!.isNotEmpty
                        ? NetworkImage(widget.request.avatarUrl!)
                        : null,
                    child: widget.request.avatarUrl == null ||
                        widget.request.avatarUrl!.isEmpty
                        ? Text(
                      _initials(widget.request.userName ?? '?'),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700),
                    )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.request.userName ?? 'Unknown User',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      if (widget.request.empCode != null) ...[
                        const SizedBox(height: 2),
                        Text(widget.request.empCode!,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500)),
                      ],
                      const SizedBox(height: 6),
                      _StatusChipLarge(
                          status: widget.request.status),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Request Details ────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(icon: Icons.info_outline, title: 'Request Details'),
                  const SizedBox(height: 16),
                  _DetailRow(
                    label:     'Request Type',
                    value:     _isProfileUpdate ? 'Profile Update' : _docLabel(docType),
                    icon:      _isProfileUpdate
                        ? Icons.manage_accounts_outlined
                        : _docIcon(docType),
                    iconColor: Colors.indigo,
                  ),
                  if (_isProfileUpdate) ...[
                    _DetailRow(
                      label:     'Category',
                      value:     _subtypeLabel(_subtype),
                      icon:      Icons.category_outlined,
                      iconColor: Colors.grey,
                    ),

                    // ── Device Change ──────────────────────────────
                    // In the device_change details section
                    if (_subtype == 'device_change') ...[
                      if ((widget.request.newData['device_info']?['platform'] ?? '').isNotEmpty)
                        _DetailRow(label: 'Platform',      value: widget.request.newData['device_info']['platform'],      icon: Icons.devices_outlined,       iconColor: Colors.orange),
                      if ((widget.request.newData['device_info']?['model'] ?? '').isNotEmpty)
                        _DetailRow(label: 'Model',         value: widget.request.newData['device_info']['model'],         icon: Icons.phone_android_outlined,  iconColor: Colors.orange),
                      if ((widget.request.newData['device_info']?['manufacturer'] ?? '').isNotEmpty)
                        _DetailRow(label: 'Manufacturer',  value: widget.request.newData['device_info']['manufacturer'],  icon: Icons.business_outlined,       iconColor: Colors.grey),
                      if ((widget.request.newData['device_info']?['name'] ?? '').isNotEmpty)
                        _DetailRow(label: 'Device Name',   value: widget.request.newData['device_info']['name'],          icon: Icons.badge_outlined,          iconColor: Colors.grey),
                      _DetailRow(label: 'Reason',          value: widget.request.newData['reason'] ?? '',                 icon: Icons.edit_note_outlined,      iconColor: Colors.grey),
                    ],

                    // ── Simple field update ────────────────────────
                    if (_subtype == 'profile_field' || _subtype == 'family_field') ...[
                      _DetailRow(
                        label:     'Field',
                        value:     widget.request.newData['field_label'] ?? '',
                        icon:      Icons.edit_outlined,
                        iconColor: Colors.grey,
                      ),
                      _DetailRow(
                        label:     'Old Value',
                        value:     (widget.request.newData['old_value'] ?? '').toString(),
                        icon:      Icons.history_outlined,
                        iconColor: Colors.grey,
                      ),
                      _DetailRow(
                        label:     'New Value',
                        value:     (widget.request.newData['value'] ?? '').toString(),
                        icon:      Icons.check_circle_outline,
                        iconColor: Colors.green,
                      ),
                    ],

                    // ── Children ───────────────────────────────────
                    if (_subtype == 'children') ...[
                      const SizedBox(height: 4),
                      ...(widget.request.newData['value'] as List? ?? [])
                          .asMap()
                          .entries
                          .map((e) {
                        final child = Map<String, dynamic>.from(e.value);
                        return _DetailRow(
                          label:     'Child ${e.key + 1}',
                          value:     '${child['name'] ?? 'N/A'}  •  ${child['gender'] ?? ''}  •  ${child['dob'] ?? ''}',
                          icon:      Icons.child_care_outlined,
                          iconColor: Colors.teal,
                        );
                      }),
                    ],

                    // ── Nominees ───────────────────────────────────
                    if (_subtype == 'nominees') ...[
                      const SizedBox(height: 4),
                      ...(widget.request.newData['value'] as List? ?? [])
                          .asMap()
                          .entries
                          .map((e) {
                        final nominee = Map<String, dynamic>.from(e.value);
                        return _DetailRow(
                          label:     'Nominee ${e.key + 1}',
                          value:     '${nominee['name'] ?? 'N/A'}  •  ${nominee['relation'] ?? ''}  •  ${nominee['share_percentage'] ?? 0}%',
                          icon:      Icons.verified_user_outlined,
                          iconColor: Colors.purple,
                        );
                      }),
                    ],

                  ] else ...[
                    // ── Document fields ────────────────────────────
                    if (widget.request.documentNumber.isNotEmpty)
                      _DetailRow(
                        label:     '${Formatters.capitalizeFirst(docType)} Number',
                        value:     widget.request.documentNumber,
                        icon:      Icons.tag,
                        iconColor: Colors.grey,
                      ),
                    if (docType == 'cheque' || docType == 'passbook') ...[
                      if ((widget.request.newData['account_holder'] ?? '').isNotEmpty)
                        _DetailRow(label: 'Account Holder',  value: widget.request.newData['account_holder'], icon: Icons.person_outlined, iconColor: Colors.grey),
                      if ((widget.request.newData['account_number'] ?? '').isNotEmpty)
                        _DetailRow(label: 'Account Number',  value: widget.request.newData['account_number'], icon: Icons.tag_outlined, iconColor: Colors.grey),
                      if ((widget.request.newData['account_type'] ?? '').isNotEmpty)
                        _DetailRow(label: 'Account Type',    value: Formatters.capitalizeFirst(widget.request.newData['account_type']), icon: Icons.account_balance_wallet_outlined,  iconColor: Colors.grey),
                      if ((widget.request.newData['ifsc_code'] ?? '').isNotEmpty)
                        _DetailRow(label: 'IFSC Code',       value: widget.request.newData['ifsc_code'], icon: Icons.code_outlined, iconColor: Colors.grey),
                      if ((widget.request.newData['bank_name'] ?? '').isNotEmpty)
                        _DetailRow(label: 'Bank Name',       value: widget.request.newData['bank_name'], icon: Icons.account_balance_outlined, iconColor: Colors.grey),
                      if ((widget.request.newData['branch_name'] ?? '').isNotEmpty)
                        _DetailRow(label: 'Branch Name',     value: widget.request.newData['branch_name'], icon: Icons.location_on_outlined, iconColor: Colors.grey),
                    ],
                  ],

                  _DetailRow(label: 'Submitted',  value: Formatters.formatDateTimeDetailed(widget.request.createdAt),          icon: Icons.schedule_outlined, iconColor: Colors.grey),
                  _DetailRow(label: 'Priority',   value: Formatters.capitalizeFirst(widget.request.priority),                  icon: Icons.flag_outlined,     iconColor: _priorityColor(widget.request.priority)),
                  if (widget.request.userNote != null && widget.request.userNote!.isNotEmpty)
                    _DetailRow(label: 'User Note', value: widget.request.userNote!, icon: Icons.notes_outlined, iconColor: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Document Preview ── only for document requests ──────
            if (_isDocumentRequest)
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                        icon: Icons.attach_file_outlined,
                        title: 'Uploaded Document'),
                    const SizedBox(height: 16),
                    _loadingUrl
                        ? const Center(child: CircularProgressIndicator())
                        : (widget.request.isDualPhoto || _signedUrl != null)
                        ? _buildDocPreview()
                        : Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(Icons.broken_image_outlined,
                            color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        const Text('File unavailable'),
                      ]),
                    ),
                  ],
                ),
              ),
            if (_isDocumentRequest) const SizedBox(height: 16),
            const SizedBox(height: 16),

            // ── Rejection reason (if rejected) ─────────────
            if (widget.request.status == 'rejected' &&
                widget.request.rejectionReason != null) ...[
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                        icon: Icons.cancel_outlined,
                        title: 'Rejection Reason',
                        color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      widget.request.rejectionReason!,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Error ──────────────────────────────────────
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Action Buttons ─────────────────────────────
            if (isActionable) ...[
              if (isPending)
                OutlinedButton.icon(
                  onPressed: _processing ? null : _markUnderReview,
                  icon: const Icon(
                      Icons.manage_search_outlined, size: 18),
                  label: const Text('Mark as Under Review'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: BorderSide(
                        color: Colors.blue.shade300),
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Reject
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _processing
                          ? null
                          : _showRejectSheet,
                      icon: const Icon(
                          Icons.cancel_outlined, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(
                            color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                        minimumSize:
                        const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Approve
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _processing ? null : _approve,
                      icon: _processing
                          ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                          : const Icon(
                          Icons.check_circle_outline,
                          size: 18),
                      label: Text(
                          _processing ? 'Processing...' : 'Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                        minimumSize:
                        const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDocPreview() {
    if (widget.request.isDualPhoto) {
      return _buildDualImagePreview();
    }
    final isImage = _signedUrl!
        .toLowerCase()
        .split('?')
        .first
        .contains(RegExp(r'\.(jpg|jpeg|png|webp)'));

    return Column(
      children: [
        // Thumbnail
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentViewer(
                url: _signedUrl!,
                title: '${_docLabel(widget.request.documentType)} — ${widget.request.userName ?? ""}',
              ),
            ),
          ),
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: isImage
                ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _signedUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                      child: CircularProgressIndicator());
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      size: 48, color: Colors.grey),
                ),
              ),
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf,
                    size: 56, color: Colors.red.shade400),
                const SizedBox(height: 8),
                const Text('PDF Document',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // View full button
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentViewer(
                url: _signedUrl!,
                title: '${_docLabel(widget.request.documentType)} — ${widget.request.userName ?? ""}',
              ),
            ),
          ),
          icon: const Icon(Icons.fullscreen_outlined, size: 18),
          label: const Text('View Full Document'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.indigo,
            side: BorderSide(color: Colors.indigo.shade200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  Widget _buildDualImagePreview() {
    return FutureBuilder<List<String?>>(
      future: _loadBothSignedUrls(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final frontUrl = snapshot.data![0];
        final backUrl  = snapshot.data![1];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Front
            Text('Front Side',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            _buildImageTile(frontUrl, 'Aadhaar Front'),

            const SizedBox(height: 16),

            // Back
            Text('Back Side',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            _buildImageTile(backUrl, 'Aadhaar Back'),
          ],
        );
      },
    );
  }

  Future<List<String?>> _loadBothSignedUrls() async {
    String? frontUrl, backUrl;

    try {
      if (widget.request.status == 'approved') {
        // File was moved to permanent storage — fetch paths from profile_details
        final result = await supabase
            .from('profile_details')
            .select('aadhaar_url, aadhaar_back_url')
            .eq('user_id', widget.request.userId)
            .maybeSingle();

        final frontPath = result?['aadhaar_url'] as String?;
        final backPath  = result?['aadhaar_back_url'] as String?;

        if (frontPath != null && frontPath.isNotEmpty) {
          frontUrl = await supabase.storage
              .from('profile-documents')
              .createSignedUrl(frontPath, 3600);
        }
        if (backPath != null && backPath.isNotEmpty) {
          backUrl = await supabase.storage
              .from('profile-documents')
              .createSignedUrl(backPath, 3600);
        }
      } else {
        // pending / under_review — files are still at staging paths
        final front = widget.request.stagingPathFront;
        final back  = widget.request.stagingPathBack;

        if (front.isNotEmpty) {
          frontUrl = await supabase.storage
              .from('profile-documents')
              .createSignedUrl(front, 3600);
        }
        if (back.isNotEmpty) {
          backUrl = await supabase.storage
              .from('profile-documents')
              .createSignedUrl(back, 3600);
        }
      }
    } catch (_) {}

    return [frontUrl, backUrl];
  }

  Widget _buildImageTile(String? url, String label) {
    if (url == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
            child: Icon(Icons.broken_image_outlined,
                color: Colors.grey)),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentViewer(url: url, title: label),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) =>
          progress == null
              ? child
              : const SizedBox(
              height: 160,
              child: Center(
                  child: CircularProgressIndicator())),
          errorBuilder: (_, __, ___) => const SizedBox(
            height: 160,
            child: Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.grey)),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'urgent': return Colors.red;
      case 'high':   return Colors.orange;
      case 'low':    return Colors.grey;
      default:       return Colors.blue;
    }
  }

  /// Maps document_type to the corresponding URL column in profile_details.
  String _urlColumnForDocType(String docType) {
    switch (docType) {
      case 'cheque':   return 'cancelled_cheque_url';
      case 'passbook': return 'passbook_url';
      case 'aadhaar':  return 'aadhaar_url';
      case 'pan':      return 'pan_url';
      case 'passport': return 'passport_url';
      default:         return '${docType}_url';
    }
  }

  IconData _docIcon(String type) {
    switch (type) {
      case 'aadhaar':        return Icons.fingerprint;
      case 'pan':            return Icons.credit_card_outlined;
      case 'passport':       return Icons.book_outlined;
      case 'cheque':         return Icons.receipt_long_outlined;
      case 'passbook':       return Icons.account_balance_outlined;
      case 'device_change':  return Icons.smartphone_outlined;
      default:               return Icons.description_outlined;
    }
  }

  String _docLabel(String subtype) {
    switch (subtype) {
      case 'aadhaar':        return 'Aadhaar';
      case 'pan':            return 'PAN Card';
      case 'passport':       return 'Passport';
      case 'cheque':         return 'Cheque';
      case 'passbook':       return 'Passbook';
      case 'device_change':  return 'Device Change Request';
      default:               return subtype;
    }
  }

  String _subtypeLabel(String subtype) {
    switch (subtype) {
      case 'profile_field': return 'Personal / Contact Field';
      case 'family_field':  return 'Family Member Name';
      case 'children':      return 'Children';
      case 'nominees':      return 'Nominees';
      case 'device_change': return 'Device Change';   // ← add this
      default:              return subtype;
    }
  }

}

// ─────────────────────────────────────────────────────────────
// Reusable Widgets
// ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.6)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3))
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.color = Colors.indigo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 13, color: Colors.grey)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _StatusChipLarge extends StatelessWidget {
  final String status;
  const _StatusChipLarge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange; label = 'Pending';
        icon  = Icons.hourglass_top_outlined; break;
      case 'under_review':
        color = Colors.blue; label = 'Under Review';
        icon  = Icons.manage_search_outlined; break;
      case 'approved':
        color = Colors.green; label = 'Approved';
        icon  = Icons.check_circle_outline; break;
      case 'rejected':
        color = Colors.red; label = 'Rejected';
        icon  = Icons.cancel_outlined; break;
      default:
        color = Colors.grey; label = status;
        icon  = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}