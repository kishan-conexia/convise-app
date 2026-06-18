import 'package:flutter/material.dart';
import 'package:mnr/models/app_state.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class DeviceInfoPage extends StatefulWidget {
  final String deviceId;
  final Map<String, dynamic> deviceData;
  final bool deviceChanged;

  const DeviceInfoPage({
    super.key,
    required this.deviceId,
    required this.deviceChanged,
    required this.deviceData,
  });

  @override
  _DeviceInfoPageState createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  bool _loading    = true;
  bool _submitting = false;
  bool _submitted  = false;

  // null = no existing request, otherwise holds the existing request data
  Map<String, dynamic>? _existingRequest;

  final _formKey    = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  // ── Check if request already pending/under_review ──────────
  Future<void> _checkExistingRequest() async {
    setState(() => _loading = true);
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final res = await supabase
          .from('requests')
          .select('id, status, created_at, new_data')
          .eq('user_id', appState.userId)
          .eq('request_type', 'profile_update')
          .inFilter('status', ['pending', 'under_review'])
          .order('created_at', ascending: false)
          .limit(10);

      // Find any device_change subtype in the results
      final existing = (res as List).cast<Map<String, dynamic>>().where((r) {
        final nd = r['new_data'];
        return nd is Map && nd['subtype'] == 'device_change';
      }).toList();

      setState(() {
        _existingRequest = existing.isNotEmpty ? existing.first : null;
      });
    } catch (e) {
      debugPrint('DeviceInfoPage check error: $e');
    }
    setState(() => _loading = false);
  }

  // 2. Update _submitRequest to send deviceData map
  Future<void> _submitRequest(AppState appState) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await supabase.from('requests').insert({
        'user_id':      appState.userId,
        'request_type': 'profile_update',
        'new_data': {
          'subtype':      'device_change',
          'device_info':  widget.deviceData,   // ← full map like _deviceData
          'reason':       _reasonCtrl.text.trim(),
        },
        'status':   'pending',
        'priority': 'high',
      });
      setState(() => _submitted = true);
    } catch (e) {
      debugPrint('Device change request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to submit request. Please try again.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: AppBar(
              title: const Text('Device Changed',
                  style: TextStyle(color: Colors.white)),
              elevation: 0,
              backgroundColor: Colors.transparent,
              centerTitle: true,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: appState.appBarGradient,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
              ),
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _submitted
                ? _buildSuccessState()
                : _existingRequest != null
                ? _buildAlreadySubmittedState()
                : _buildRequestForm(appState),
          ),
        );
      },
    );
  }

  // 3. In _buildAlreadySubmittedState — show device info fields instead of raw ID
  Widget _buildAlreadySubmittedState() {
    final status       = _existingRequest!['status'] as String;
    final isUnderReview = status == 'under_review';
    final color        = isUnderReview ? Colors.blue : Colors.orange;
    final icon         = isUnderReview ? Icons.manage_search_outlined : Icons.hourglass_top_outlined;
    final label        = isUnderReview ? 'Under Review' : 'Pending';
    final submittedAt  = DateTime.tryParse(_existingRequest!['created_at']?.toString() ?? '');
    final deviceInfo   = Map<String, dynamic>.from(
        _existingRequest!['new_data']?['device_info'] ?? {});

    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 72, color: color),
        ),
        const SizedBox(height: 24),
        Text('Request Already Submitted',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'You already have a device change request that is currently $label. '
              'Please wait for HR to action it before submitting a new one.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
        ),
        const SizedBox(height: 28),

        // ── Status + device info card ──────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.smartphone_outlined, color: Colors.orange.shade600, size: 18),
                  const SizedBox(width: 8),
                  Text('New Device Info',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
                ],
              ),
              const SizedBox(height: 10),
              if (widget.deviceData['platform'] != null)
                _infoRow(Icons.devices_outlined,      widget.deviceData['platform'] ?? ''),
              if (widget.deviceData['model'] != null)
                _infoRow(Icons.phone_android_outlined, widget.deviceData['model']    ?? ''),
              if (widget.deviceData['manufacturer'] != null)
                _infoRow(Icons.business_outlined,     widget.deviceData['manufacturer'] ?? ''),
              if (widget.deviceData['name'] != null)    // iOS
                _infoRow(Icons.badge_outlined,        widget.deviceData['name']     ?? ''),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.support_agent_outlined, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Contact HR directly if this is urgent.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.4)),
              ),
            ],
          ),
        ),
      ],
    );
  }

// Small helper for info rows
  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // ── Success State ──────────────────────────────────────────
  Widget _buildSuccessState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_outline,
              size: 72, color: Colors.green.shade600),
        ),
        const SizedBox(height: 24),
        Text(
          'Request Submitted!',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700),
        ),
        const SizedBox(height: 12),
        Text(
          'Your device change request has been sent to HR.\nYou will be notified once it is reviewed.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15, color: Colors.grey.shade600, height: 1.5),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.devices_outlined, color: Colors.blue.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Device ID',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Text(
                      widget.deviceId,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Request Form ───────────────────────────────────────────
  Widget _buildRequestForm(AppState appState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded,
                size: 56, color: Colors.red.shade600),
          ),
          const SizedBox(height: 20),
          Text(
            'Device Change Detected!',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Your account is being accessed from a different device. '
                'Submit a request below to notify HR and get your new device approved.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.smartphone_outlined, color: Colors.orange.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New Device ID',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                      const SizedBox(height: 2),
                      Text(
                        widget.deviceId,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _reasonCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Reason for Device Change',
              hintText: 'e.g. Old device broken, new work phone issued...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Colors.blue.shade400, width: 2),
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.edit_note_outlined),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please provide a reason for the device change';
              }
              if (v.trim().length < 10) {
                return 'Reason must be at least 10 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : () => _submitRequest(appState),
              icon: _submitting
                  ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.send_outlined, color: Colors.white),
              label: Text(
                _submitting ? 'Submitting...' : 'Submit Device Change Request',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                disabledBackgroundColor: Colors.blue.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your request will be reviewed by HR. You may be contacted for verification.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}