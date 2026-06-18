import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../models/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/uploads/document_viewer.dart';

class RequestHistoryPage extends StatefulWidget {
  const RequestHistoryPage({super.key});

  @override
  State<RequestHistoryPage> createState() => _RequestHistoryPageState();
}

class _RequestHistoryPageState extends State<RequestHistoryPage> {
  List<Map<String, dynamic>> _requests = [];
  bool   _loading      = false;
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchHistory());
  }

  Future<void> _fetchHistory() async {
    setState(() => _loading = true);
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      var query = supabase
          .from('requests')
          .select('id, request_type, new_data, status, rejection_reason, review_note, created_at, updated_at, reviewed_at')
          .eq('user_id', appState.userId);

      if (_activeFilter != 'all') {
        query = query.eq('status', _activeFilter);
      } else {
        query = query.inFilter('status', ['pending', 'under_review', 'approved', 'rejected']);
      }

      final res = await query.order('created_at', ascending: false);
      setState(() => _requests = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('RequestHistoryPage fetch error: $e');
    }
    setState(() => _loading = false);
  }

  void _setFilter(String filter) {
    setState(() => _activeFilter = filter);
    _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: const Text('Request History',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white70,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600, Colors.blue.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _fetchHistory,
            ),
          ],
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
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _requests.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                onRefresh: _fetchHistory,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _requests.length,
                  itemBuilder: (_, i) => _HistoryCard(
                    request: _requests[i],
                    onTap: () => _showRequestDetail(_requests[i]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      {'key': 'all',          'label': 'All'},
      {'key': 'pending',      'label': 'Pending'},
      {'key': 'under_review', 'label': 'Under Review'},
      {'key': 'approved',     'label': 'Approved'},
      {'key': 'rejected',     'label': 'Rejected'},
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isActive = _activeFilter == f['key'];
            final color    = _filterColor(f['key']!);
            return GestureDetector(
              onTap: () => _setFilter(f['key']!),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? color : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isActive ? color : Colors.grey.shade300),
                  boxShadow: isActive
                      ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _filterColor(String filter) {
    switch (filter) {
      case 'pending':      return Colors.orange;
      case 'under_review': return Colors.blue;
      case 'approved':     return Colors.green;
      case 'rejected':     return Colors.red;
      default:             return Colors.blueGrey;
    }
  }

  Widget _buildEmptyState() {
    final messages = {
      'all':          'No requests submitted yet',
      'pending':      'No pending requests',
      'under_review': 'No requests under review',
      'approved':     'No approved requests',
      'rejected':     'No rejected requests',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            messages[_activeFilter] ?? 'No requests found',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }

  void _showRequestDetail(Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _RequestDetailSheet(
          request: request,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// History Card
// ─────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onTap;

  const _HistoryCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final requestType = request['request_type'] ?? '';
    final newData     = Map<String, dynamic>.from(request['new_data'] ?? {});
    final status      = request['status'] ?? '';
    final createdAt   = DateTime.tryParse(request['created_at'] ?? '');
    final statusColor = _statusColor(status);

    final icon  = _requestIcon(requestType, newData);
    final label = _requestLabel(requestType, newData);
    final sub   = _requestSubtitle(requestType, newData);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    if (sub.isNotEmpty)
                      Text(sub,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      createdAt != null
                          ? Formatters.formatDateTimeDetailed(createdAt)
                          : '—',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusPill(status: status),
                  const SizedBox(height: 6),
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':      return Colors.orange;
      case 'under_review': return Colors.blue;
      case 'approved':     return Colors.green;
      case 'rejected':     return Colors.red;
      default:             return Colors.grey;
    }
  }

  // ── Shared helpers — use these in BOTH _HistoryCard and _RequestDetailSheetState ──

  IconData _requestIcon(String type, Map<String, dynamic> data) {
    final docType = data['document_type'] ?? '';
    if (docType.isNotEmpty) {
      switch (docType) {
        case 'aadhaar':  return Icons.fingerprint;
        case 'pan':      return Icons.credit_card_outlined;
        case 'passport': return Icons.book_outlined;
        case 'cheque':   return Icons.receipt_long_outlined;
        case 'passbook': return Icons.account_balance_outlined;
        default:         return Icons.description_outlined;
      }
    }
    switch (data['subtype'] ?? '') {
      case 'nominees':      return Icons.pie_chart_outline;
      case 'children':      return Icons.child_care_outlined;
      case 'family_field':  return Icons.family_restroom_outlined;
      case 'device_change': return Icons.smartphone_outlined;
      case 'profile_field':
        switch (data['field'] ?? '') {
          case 'current_address':
          case 'permanent_address': return Icons.home_outlined;
          case 'marital_status':    return Icons.favorite_outline;
          case 'date_of_birth':     return Icons.cake_outlined;
          default:                  return Icons.person_outlined;
        }
      default: return Icons.edit_note_outlined;
    }
  }

  String _requestLabel(String type, Map<String, dynamic> data) {
    final docType = data['document_type'] ?? '';
    if (docType.isNotEmpty) {
      switch (docType) {
        case 'aadhaar':  return 'Aadhaar Card';
        case 'pan':      return 'PAN Card';
        case 'passport': return 'Passport';
        case 'cheque':   return 'Cancelled Cheque';
        case 'passbook': return 'Bank Passbook';
        default:         return 'Document Update';
      }
    }
    switch (data['subtype'] ?? '') {
      case 'nominees':      return 'Nominee Update';
      case 'children':      return 'Children Update';
      case 'family_field':  return data['field_label'] ?? 'Family Info Update';
      case 'profile_field': return data['field_label'] ?? 'Profile Info Update';
      case 'device_change': return 'Device Change';
      default:
        final label = data['field_label'];
        if (label != null && label.toString().isNotEmpty) return label.toString();
        return 'Profile Update';
    }
  }

  String _requestSubtitle(String type, Map<String, dynamic> data) {
    final docType = data['document_type'] ?? '';
    if (docType.isNotEmpty) {
      final num = data['${docType}_number'] ?? data['account_number'] ?? '';
      return num.isNotEmpty ? num : '';
    }
    switch (data['subtype'] ?? '') {
      case 'nominees':
        final list = data['value'];
        if (list is List && list.isNotEmpty)
          return '${list.length} nominee${list.length > 1 ? 's' : ''}';
        return '';
      case 'children':
        final list = data['value'];
        if (list is List && list.isNotEmpty)
          return '${list.length} child${list.length > 1 ? 'ren' : ''}';
        return '';
      case 'family_field':
      case 'profile_field':
        final val = data['value']?.toString() ?? '';
        return val.isNotEmpty ? val : '';
      case 'device_change':
        final info = data['device_info'];
        if (info is Map) {
          final model    = info['model']    ?? '';
          final platform = info['platform'] ?? '';
          if (model.isNotEmpty) return model;
          if (platform.isNotEmpty) return platform;
        }
        return '';
      default:
        return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Request Detail Bottom Sheet
// ─────────────────────────────────────────────────────────────
class _RequestDetailSheet extends StatefulWidget {
  final Map<String, dynamic> request;
  final ScrollController scrollController;

  const _RequestDetailSheet({
    required this.request,
    required this.scrollController,
  });

  @override
  State<_RequestDetailSheet> createState() => _RequestDetailSheetState();
}

class _RequestDetailSheetState extends State<_RequestDetailSheet> {
  String? _signedUrl;
  String? _signedUrlFront;
  String? _signedUrlBack;
  bool    _loadingUrl = true;

  @override
  void initState() {
    super.initState();
    _loadSignedUrls();
  }

  Future<void> _loadSignedUrls() async {
    final newData = Map<String, dynamic>.from(widget.request['new_data'] ?? {});
    final docType = newData['document_type'] ?? '';

    if (docType.isEmpty) {
      if (mounted) setState(() => _loadingUrl = false);
      return;
    }

    try {
      if (docType == 'aadhaar') {
        final frontPath = newData['staging_path_front'] as String?;
        final backPath  = newData['staging_path_back']  as String?;
        if (frontPath != null && frontPath.isNotEmpty) {
          _signedUrlFront = await supabase.storage
              .from('profile-documents')
              .createSignedUrl(frontPath, 3600);
        }
        if (backPath != null && backPath.isNotEmpty) {
          _signedUrlBack = await supabase.storage
              .from('profile-documents')
              .createSignedUrl(backPath, 3600);
        }
      } else {
        final staging = newData['staging_path'] as String?;
        if (staging != null && staging.isNotEmpty) {
          _signedUrl = await supabase.storage
              .from('profile-documents')
              .createSignedUrl(staging, 3600);
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _loadingUrl = false);
  }

  @override
  Widget build(BuildContext context) {
    final requestType = widget.request['request_type'] ?? '';
    final newData     = Map<String, dynamic>.from(widget.request['new_data'] ?? {});
    final status      = widget.request['status'] ?? '';
    final color       = _statusColor(status);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Fixed header ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSheetHeader(requestType, newData, status, color),
                const SizedBox(height: 4),
                const Divider(),
              ],
            ),
          ),
          // ── Scrollable body ────────────────────────────────
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _buildMetaRows(status),
                const SizedBox(height: 4),
                _buildTypeSpecificDetails(requestType, newData, status),
                _buildStatusBanners(status),
                const SizedBox(height: 16),
                // Document preview — only for document uploads
                if ((newData['document_type'] ?? '').isNotEmpty) ...[
                  if (_loadingUrl)
                    const Center(child: CircularProgressIndicator())
                  else if (newData['document_type'] == 'aadhaar')
                    _buildDualImagePreview(context)
                  else if (_signedUrl != null)
                      _buildFilePreview(context, newData['document_type'] ?? '')
                    else
                      _buildFileUnavailable(status),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetHeader(
      String requestType, Map<String, dynamic> newData, String status, Color color) {
    // Uses top-level helpers — no duplication
    final icon  = _requestIcon(requestType, newData);
    final label = _requestLabel(requestType, newData);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              _StatusPill(status: status),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRows(String status) {
    final createdAt  = DateTime.tryParse(widget.request['created_at']  ?? '');
    final reviewedAt = DateTime.tryParse(widget.request['reviewed_at'] ?? '');
    return Column(
      children: [
        if (createdAt != null)
          _SheetDetailRow(
            icon: Icons.upload_outlined, label: 'Submitted',
            value: Formatters.formatDateTimeDetailed(createdAt),
          ),
        if (reviewedAt != null)
          _SheetDetailRow(
            icon: Icons.done_all_outlined, label: 'Reviewed At',
            value: Formatters.formatDateTimeDetailed(reviewedAt),
          ),
      ],
    );
  }

  // ── Per-type detail rows ──────────────────────────────────
  Widget _buildTypeSpecificDetails(
      String type, Map<String, dynamic> data, String status) {
    final docType = data['document_type'] ?? '';
    if (docType.isNotEmpty) return _buildDocumentDetails(data);

    switch (data['subtype'] ?? '') {
      case 'nominees':
      case 'children':
        return _buildListDetails(data, data['subtype']);
      case 'family_field':
      case 'profile_field':
        return _buildFieldDetails(data);
      case 'device_change':
        return _buildDeviceChangeDetails(data);
      default:
        return _buildGenericDetails(data);
    }
  }

  Widget _buildDeviceChangeDetails(Map<String, dynamic> data) {
    final info = data['device_info'];
    final deviceInfo = info is Map ? Map<String, dynamic>.from(info) : <String, dynamic>{};

    return Column(
      children: [
        if ((deviceInfo['platform'] ?? '').isNotEmpty)
          _SheetDetailRow(icon: Icons.devices_outlined,       label: 'Platform',     value: deviceInfo['platform']),
        if ((deviceInfo['model'] ?? '').isNotEmpty)
        //   _SheetDetailRow(icon: Icons.phone_android_outlined, label: 'Model',        value: deviceInfo['model']),
        // if ((deviceInfo['manufacturer'] ?? '').isNotEmpty)
        //   _SheetDetailRow(icon: Icons.business_outlined,      label: 'Manufacturer', value: deviceInfo['manufacturer']),
        // if ((deviceInfo['name'] ?? '').isNotEmpty)
        //   _SheetDetailRow(icon: Icons.badge_outlined,         label: 'Device Name',  value: deviceInfo['name']),
        if ((data['reason'] ?? '').isNotEmpty)
          _SheetDetailRow(icon: Icons.edit_note_outlined,     label: 'Reason',       value: data['reason']),
      ],
    );
  }

// For single field updates (DOB, marital status, address, father name etc.)
  Widget _buildFieldDetails(Map<String, dynamic> data) {
    final label    = data['field_label'] ?? data['field'] ?? '';
    final newValue = data['value']?.toString() ?? '';
    final oldValue = data['old_value']?.toString() ?? '';
    return Column(
      children: [
        if (label.isNotEmpty)
          _SheetDetailRow(icon: Icons.edit_outlined,              label: 'Field',          value: label),
        if (newValue.isNotEmpty)
          _SheetDetailRow(icon: Icons.arrow_circle_up_outlined,   label: 'New Value',      value: newValue),
        if (oldValue.isNotEmpty)
          _SheetDetailRow(icon: Icons.history_outlined,           label: 'Previous Value', value: oldValue),
      ],
    );
  }

// For nominees / children list updates
  Widget _buildListDetails(Map<String, dynamic> data, String listType) {
    final rawItems = data['value'];
    final rawOld   = data['old_value'];

    final items = (rawItems is List)
        ? rawItems.where((e) {
      final item = Map<String, dynamic>.from(e ?? {});
      return (item['name'] ?? '').toString().trim().isNotEmpty;
    }).toList()
        : [];
    final oldItems = (rawOld is List)
        ? rawOld.where((e) {
      final item = Map<String, dynamic>.from(e ?? {});
      return (item['name'] ?? '').toString().trim().isNotEmpty;
    }).toList()
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Updated ${listType == 'nominees' ? 'Nominees' : 'Children'}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
          ),
          ...items.asMap().entries.map((e) {
            final item = Map<String, dynamic>.from(e.value ?? {});
            return _buildListItemCard(listType, e.key, item);
          }),
        ],
        if (oldItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Previous Values',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
            ),
          ),
          ...oldItems.asMap().entries.map((e) {
            final item = Map<String, dynamic>.from(e.value ?? {});
            return _buildListItemCard(listType, e.key, item, isOld: true);
          }),
        ],
      ],
    );
  }

  Widget _buildListItemCard(String listType, int idx, Map<String, dynamic> item,
      {bool isOld = false}) {
    final color = isOld
        ? Colors.grey
        : (listType == 'nominees' ? Colors.purple : Colors.teal);

    List<Widget> rows = [];
    if ((item['name']     ?? '').isNotEmpty) rows.add(_SheetDetailRow(icon: Icons.person_outlined,   label: 'Name',     value: item['name']));
    if ((item['relation'] ?? '').isNotEmpty) rows.add(_SheetDetailRow(icon: Icons.people_outlined,   label: 'Relation', value: item['relation']));
    if (listType == 'nominees' && item['share_percentage'] != null) {
      rows.add(_SheetDetailRow(icon: Icons.pie_chart_outline, label: 'Share', value: '${item['share_percentage']}%'));
    }
    if ((item['dob']     ?? '').isNotEmpty) rows.add(_SheetDetailRow(icon: Icons.cake_outlined,    label: 'DOB',     value: item['dob'].toString()));
    if ((item['gender']  ?? '').isNotEmpty) rows.add(_SheetDetailRow(icon: Icons.wc_outlined,      label: 'Gender',  value: item['gender']));
    if ((item['contact'] ?? '').isNotEmpty) rows.add(_SheetDetailRow(icon: Icons.phone_outlined,   label: 'Contact', value: item['contact'].toString()));

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Icon(Icons.person_pin_outlined, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                isOld
                    ? 'Previous ${idx + 1}'
                    : '${listType == 'nominees' ? 'Nominee' : 'Child'} ${idx + 1}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentDetails(Map<String, dynamic> data) {
    final docType   = data['document_type'] ?? '';
    final docNumber = data['${docType}_number'] ?? '';
    final isBankDoc = docType == 'passbook' || docType == 'cheque';

    return Column(
      children: [
        if (docNumber.isNotEmpty)
          _SheetDetailRow(
            icon: Icons.tag,
            label: '${Formatters.capitalizeFirst(docType)} Number',
            value: docNumber,
          ),
        if (isBankDoc) ...[
          if ((data['account_holder'] ?? '').isNotEmpty)
            _SheetDetailRow(icon: Icons.person_outlined,                label: 'Account Holder', value: data['account_holder']),
          if ((data['account_number'] ?? '').isNotEmpty)
            _SheetDetailRow(icon: Icons.tag_outlined,                   label: 'Account Number', value: data['account_number']),
          if ((data['account_type'] ?? '').isNotEmpty)
            _SheetDetailRow(icon: Icons.account_balance_wallet_outlined, label: 'Account Type',
                value: Formatters.capitalizeFirst(data['account_type'])),
          if ((data['ifsc_code'] ?? '').isNotEmpty)
            _SheetDetailRow(icon: Icons.code_outlined,                  label: 'IFSC Code',      value: data['ifsc_code']),
          if ((data['bank_name'] ?? '').isNotEmpty)
            _SheetDetailRow(icon: Icons.account_balance_outlined,       label: 'Bank Name',      value: data['bank_name']),
          if ((data['branch_name'] ?? '').isNotEmpty)
            _SheetDetailRow(icon: Icons.location_on_outlined,           label: 'Branch Name',    value: data['branch_name']),
        ],
      ],
    );
  }

  Widget _buildFamilyDetails(Map<String, dynamic> data) {
    final field = data['field'] ?? '';
    final items = data['value'];  // usually a List

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (field.isNotEmpty)
          _SheetDetailRow(
            icon:  Icons.category_outlined,
            label: 'Section',
            value: _familyFieldLabel(field),
          ),
        if (items is List && items.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...items.asMap().entries.map((e) {
            final idx  = e.key;
            final item = Map<String, dynamic>.from(e.value ?? {});
            return _buildFamilyItemCard(field, idx, item);
          }),
        ],
      ],
    );
  }

  Widget _buildFamilyItemCard(String field, int idx, Map<String, dynamic> item) {
    final labelColor = _fieldColor(field);

    List<Widget> rows = [];

    if (field == 'nominees') {
      if ((item['name'] ?? '').isNotEmpty)
        rows.add(_SheetDetailRow(icon: Icons.person_outlined,     label: 'Name',       value: item['name']));
      if ((item['relation'] ?? '').isNotEmpty)
        rows.add(_SheetDetailRow(icon: Icons.people_outlined,     label: 'Relation',   value: item['relation']));
      if ((item['share'] ?? '').toString().isNotEmpty)
        rows.add(_SheetDetailRow(icon: Icons.pie_chart_outline,   label: 'Share',      value: '${item['share']}%'));
      if ((item['dob'] ?? '').isNotEmpty)
        rows.add(_SheetDetailRow(icon: Icons.cake_outlined,       label: 'DOB',        value: item['dob']));
    } else if (field == 'emergency_contacts') {
      if ((item['name'] ?? '').isNotEmpty)
        rows.add(_SheetDetailRow(icon: Icons.person_outlined,     label: 'Name',       value: item['name']));
      if ((item['relation'] ?? '').isNotEmpty)
        rows.add(_SheetDetailRow(icon: Icons.people_outlined,     label: 'Relation',   value: item['relation']));
      if ((item['phone'] ?? '').isNotEmpty)
        rows.add(_SheetDetailRow(icon: Icons.phone_outlined,      label: 'Phone',      value: item['phone']));
      if ((item['priority'] ?? '').isNotEmpty)
        rows.add(_SheetDetailRow(icon: Icons.priority_high,       label: 'Priority',   value: Formatters.capitalizeFirst(item['priority'])));
    } else if (field == 'dependants') {
      if ((item['name'] ?? '').isNotEmpty)
        rows.add(_SheetDetailRow(icon: Icons.person_outlined,     label: 'Name',       value: item['name']));
      if ((item['relation'] ?? '').isNotEmpty)
        rows.add(_SheetDetailRow(icon: Icons.people_outlined,     label: 'Relation',   value: item['relation']));
      if ((item['dob'] ?? '').isNotEmpty)
        rows.add(_SheetDetailRow(icon: Icons.cake_outlined,       label: 'DOB',        value: item['dob']));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: labelColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: labelColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: labelColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.person_pin_outlined, size: 14, color: labelColor),
                const SizedBox(width: 6),
                Text('${_familyFieldLabel(field)} ${idx + 1}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: labelColor)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressDetails(Map<String, dynamic> data) {
    return Column(
      children: [
        if ((data['address_line1'] ?? '').isNotEmpty)
          _SheetDetailRow(icon: Icons.home_outlined,          label: 'Address Line 1', value: data['address_line1']),
        if ((data['address_line2'] ?? '').isNotEmpty)
          _SheetDetailRow(icon: Icons.home_work_outlined,     label: 'Address Line 2', value: data['address_line2']),
        if ((data['city'] ?? '').isNotEmpty)
          _SheetDetailRow(icon: Icons.location_city_outlined, label: 'City',           value: data['city']),
        if ((data['state'] ?? '').isNotEmpty)
          _SheetDetailRow(icon: Icons.map_outlined,           label: 'State',          value: data['state']),
        if ((data['pincode'] ?? '').isNotEmpty)
          _SheetDetailRow(icon: Icons.pin_drop_outlined,      label: 'Pincode',        value: data['pincode']),
        if ((data['country'] ?? '').isNotEmpty)
          _SheetDetailRow(icon: Icons.flag_outlined,          label: 'Country',        value: data['country']),
      ],
    );
  }

  Widget _buildPersonalDetails(Map<String, dynamic> data) {
    final field = data['field'] ?? data['section'] ?? '';
    final value = data['value'];

    return Column(
      children: [
        if (field.isNotEmpty)
          _SheetDetailRow(
            icon:  Icons.edit_outlined,
            label: 'Field',
            value: Formatters.capitalizeFirst(field),
          ),
        if (value != null && value.toString().isNotEmpty)
          _SheetDetailRow(
            icon:  Icons.info_outline,
            label: 'New Value',
            value: value.toString(),
          ),
      ],
    );
  }

  // ── Generic fallback ──────────────────────────────────────
  Widget _buildGenericDetails(Map<String, dynamic> data) {
    return Column(
      children: data.entries
          .where((e) => e.value != null && e.value.toString().isNotEmpty)
          .map((e) => _SheetDetailRow(
        icon:  Icons.data_object_outlined,
        label: Formatters.capitalizeFirst(e.key.replaceAll('_', ' ')),
        value: e.value.toString(),
      ))
          .toList(),
    );
  }

  // ── Status banners (rejection reason / review note) ───────
  Widget _buildStatusBanners(String status) {
    final rejectionReason = widget.request['rejection_reason'];
    final reviewNote      = widget.request['review_note'];
    return Column(
      children: [
        if (status == 'rejected' &&
            rejectionReason != null &&
            rejectionReason.toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoBanner(
            icon: Icons.cancel_outlined, title: 'Rejection Reason',
            content: rejectionReason.toString(), color: Colors.red,
          ),
        ],
        if (reviewNote != null && reviewNote.toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoBanner(
            icon: Icons.notes_outlined, title: 'Admin Note',
            content: reviewNote.toString(), color: Colors.blue,
          ),
        ],
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────
  String _familyFieldLabel(String field) {
    switch (field) {
      case 'emergency_contacts': return 'Emergency Contact';
      case 'nominees':           return 'Nominee';
      case 'dependants':         return 'Dependant';
      default:                   return Formatters.capitalizeFirst(field);
    }
  }

  Color _fieldColor(String field) {
    switch (field) {
      case 'nominees':           return Colors.purple;
      case 'emergency_contacts': return Colors.red;
      case 'dependants':         return Colors.teal;
      default:                   return Colors.blueGrey;
    }
  }

  // ── File unavailable placeholder ──────────────────────────
  Widget _buildFileUnavailable(String status) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade400, size: 16),
          const SizedBox(width: 8),
          Text(
            status == 'approved'
                ? 'File moved to storage'
                : status == 'rejected'
                ? 'File was removed after rejection'
                : 'File unavailable',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDualImagePreview(BuildContext context) {
    if (_signedUrlFront == null && _signedUrlBack == null) {
      return _buildFileUnavailable(widget.request['status'] ?? '');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Front Side',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        _buildImageTile(context, _signedUrlFront, 'Aadhaar Front'),
        const SizedBox(height: 14),
        Text('Back Side',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        _buildImageTile(context, _signedUrlBack, 'Aadhaar Back'),
      ],
    );
  }

  Widget _buildFilePreview(BuildContext context, String docType) {
    final isImage = _signedUrl!.toLowerCase().split('?').first
        .contains(RegExp(r'\.(jpg|jpeg|png|webp)'));
    final title = _requestLabel(docType, {});
    return Column(
      children: [
        isImage
            ? _buildImageTile(context, _signedUrl, title)
            : GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => DocumentViewer(url: _signedUrl!, title: title))),
          child: Container(
            height: 120, width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, size: 44, color: Colors.red.shade400),
                const SizedBox(height: 8),
                const Text('PDF — tap to view', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => DocumentViewer(url: _signedUrl!, title: title))),
          icon:  const Icon(Icons.fullscreen_outlined, size: 18),
          label: const Text('View Full Document'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.indigo,
            side: BorderSide(color: Colors.indigo.shade200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  Widget _buildImageTile(BuildContext context, String? url, String label) {
    if (url == null) return _buildFileUnavailable(widget.request['status'] ?? '');
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DocumentViewer(url: url, title: label))),
      child: Container(
        height: 180, width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey)),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':      return Colors.orange;
      case 'under_review': return Colors.blue;
      case 'approved':     return Colors.green;
      case 'rejected':     return Colors.red;
      default:             return Colors.grey;
    }
  }

  // Inside _RequestDetailSheetState — replace both methods

  IconData _requestIcon(String type, Map<String, dynamic> data) {
    final docType = data['document_type'] ?? '';
    if (docType.isNotEmpty) {
      switch (docType) {
        case 'aadhaar':  return Icons.fingerprint;
        case 'pan':      return Icons.credit_card_outlined;
        case 'passport': return Icons.book_outlined;
        case 'cheque':   return Icons.receipt_long_outlined;
        case 'passbook': return Icons.account_balance_outlined;
        default:         return Icons.description_outlined;
      }
    }
    switch (data['subtype'] ?? '') {
      case 'nominees':      return Icons.pie_chart_outline;
      case 'children':      return Icons.child_care_outlined;
      case 'family_field':  return Icons.family_restroom_outlined;
      case 'device_change': return Icons.smartphone_outlined;
      case 'profile_field':
        switch (data['field'] ?? '') {
          case 'current_address':
          case 'permanent_address': return Icons.home_outlined;
          case 'marital_status':    return Icons.favorite_outline;
          case 'date_of_birth':     return Icons.cake_outlined;
          default:                  return Icons.person_outlined;
        }
      default: return Icons.edit_note_outlined;
    }
  }

  String _requestLabel(String type, Map<String, dynamic> data) {
    final docType = data['document_type'] ?? '';
    if (docType.isNotEmpty) {
      switch (docType) {
        case 'aadhaar':  return 'Aadhaar Card';
        case 'pan':      return 'PAN Card';
        case 'passport': return 'Passport';
        case 'cheque':   return 'Cancelled Cheque';
        case 'passbook': return 'Bank Passbook';
        default:         return 'Document Update';
      }
    }
    switch (data['subtype'] ?? '') {
      case 'nominees':      return 'Nominee Update';
      case 'children':      return 'Children Update';
      case 'family_field':  return data['field_label'] ?? 'Family Info Update';
      case 'profile_field': return data['field_label'] ?? 'Profile Info Update';
      case 'device_change': return 'Device Change';
      default:
        final label = data['field_label'];
        if (label != null && label.toString().isNotEmpty) return label.toString();
        return 'Profile Update';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Info Banner (rejection / admin note)
// ─────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  Color get _dark => Color.lerp(color, Colors.black, 0.25)!;

  Color get _darker => Color.lerp(color, Colors.black, 0.35)!;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: _dark),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _darker)),
          ]),
          const SizedBox(height: 6),
          Text(content, style: TextStyle(fontSize: 13, color: _darker)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case 'pending':
        color = Colors.orange; label = 'Pending';      icon = Icons.hourglass_top_outlined; break;
      case 'under_review':
        color = Colors.blue;   label = 'Under Review'; icon = Icons.manage_search_outlined; break;
      case 'approved':
        color = Colors.green;  label = 'Approved';     icon = Icons.check_circle_outline;   break;
      case 'rejected':
        color = Colors.red;    label = 'Rejected';     icon = Icons.cancel_outlined;        break;
      default:
        color = Colors.grey;   label = status;         icon = Icons.help_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SheetDetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  const _SheetDetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Text('$label: ',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}