import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mnr/models/app_state.dart';

import '../main.dart';

class AttendanceRegularizationPage extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String managerId;
  final int managerLevel;

  const AttendanceRegularizationPage({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.managerId,
    required this.managerLevel,
  });

  @override
  State<AttendanceRegularizationPage> createState() => _AttendanceRegularizationPageState();
}

class _AttendanceRegularizationPageState extends State<AttendanceRegularizationPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _regularizations = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedType = 'all';
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize pulse animation
    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _zoomAnimation = Tween<double>(
      begin: 0.98,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOut,
    ));

    _fetchRegularizations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _zoomController.dispose();
    super.dispose();
  }


  Future<void> _fetchRegularizations() async {
    setState(() => _isLoading = true);

    try {

      final response = await supabase
          .from('attendance_regularizations')
          .select('*')
          .eq('employee_id', widget.employeeId)
          .order('created_at', ascending: false);

      setState(() {
        _regularizations = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load regularizations: ${e.toString()}');
    }
  }

  List<Map<String, dynamic>> get _filteredRegularizations {
    return _regularizations.where((reg) {
      // Status filter
      if (_selectedStatus != 'all' && reg['status'] != _selectedStatus) {
        return false;
      }

      // Type filter
      if (_selectedType != 'all' && reg['regularization_type'] != _selectedType) {
        return false;
      }

      // Search filter
      if (_searchController.text.isNotEmpty) {
        final searchTerm = _searchController.text.toLowerCase();
        final reason = (reg['reason'] ?? '').toString().toLowerCase();
        if (!reason.contains(searchTerm)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showApprovalDialog(Map<String, dynamic> regularization) {
    final TextEditingController commentsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take Action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Regularization Type: ${regularization['regularization_type']?.toString().replaceAll('_', ' ').toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${_formatDate(regularization['requested_punch_in'] ?? regularization['created_at'])}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Employee: ${widget.employeeName}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Reason: ${
                  (regularization['reason'] != null && regularization['reason'].isNotEmpty)
                      ? regularization['reason']
                      : 'N/A'
              }',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentsController,
              decoration: const InputDecoration(
                labelText: 'Comments (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Add your comments here...',
              ),
              maxLines: 3,
              maxLength: 100,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              _handleApprovalAction(
                regularization,
                'rejected',
                commentsController.text.trim(),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              _handleApprovalAction(
                regularization,
                'approved',
                commentsController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprovalAction(
      Map<String, dynamic> regularization,
      String action,
      String comments,
      ) async {
    try {

      final now = await AppState().getCurrentTime(); // Assumes device is in IST
      final startTime = DateTime(now.year, now.month, now.day, 6, 0);     // 6:00 AM
      final endTime = DateTime(now.year, now.month, now.day, 23, 30);     // 11:30 PM

      if (now.isBefore(startTime) || now.isAfter(endTime)) {
        _showMessage('Regularization are allowed only between 6:00 AM and 11:30 PM', isError: true);
        return;
      }

      final response = await supabase.rpc('_handle_approval_action', params: {
        'regularization_id': regularization['id'],
        'manager_id': widget.managerId,
        'action': action,
        'comments': comments,
        'current_level': widget.managerLevel,
        'attendance_id_param': regularization['attendance_id'],
      });

      if (response != null && response.isNotEmpty) {
        final result = response.first;
        final statusCode = result['status_code'] as int;
        final message = result['message'] as String;

        if (statusCode >= 200 && statusCode < 300) {
          _showMessage(message);
        } else if (statusCode == 409) {
          _showMessage(message, isError: true);
        } else {
          _showErrorSnackBar(message);
        }

        // Refresh UI
        await _fetchRegularizations();
      }
    } catch (e) {
      _showErrorSnackBar('Approval failed: ${e.toString()}');
    }
  }

  Future<void> _cancelRegularization(int regId) async {

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Cancellation'),
        content: const Text('Are you sure you want to cancel this regularization request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return; // Exit if user cancelled the dialog

    try {

      final now = await AppState().getCurrentTime(); // Assumes device is in IST
      final startTime = DateTime(now.year, now.month, now.day, 6, 0);     // 6:00 AM
      final endTime = DateTime(now.year, now.month, now.day, 23, 30);     // 11:30 PM

      if (now.isBefore(startTime) || now.isAfter(endTime)) {
        _showErrorSnackBar('Cancellation are allowed only between 6:00 AM and 11:30 PM');
        return;
      }

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final response = await supabase.rpc('cancel_attendance_regularization', params: {
        'regularization_id': regId,
      });

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
      }

      if (response != null && response.isNotEmpty) {
        final result = response.first;
        final statusCode = result['status_code'] as int;
        final message = result['message'] as String;

        if (statusCode == 200) {
          _showMessage(message);
          await _fetchRegularizations();
        } else {
          _showErrorSnackBar(message);
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
      _showErrorSnackBar('Cancellation failed: ${e.toString()}');
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min, // Ensures the Column takes minimum vertical space
          children: [
            const Text(
              'Regularization',
              style: TextStyle(color: Colors.white),
            ),
            // Conditionally show employee name if managerId is not empty
            if (widget.managerLevel > 0)
              Text(
                widget.employeeName, // Assuming widget.employeeName is available
                style: const TextStyle(
                  color: Colors.white70, // Slightly desaturated for a subtitle effect
                  fontSize: 14, // Smaller font size for the name
                  // You might want to add fontWeight: FontWeight.w400 for a lighter look
                ),
              ),
          ],
        ),
        centerTitle: true,
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade600, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.refresh),
        //     onPressed: _fetchRegularizations,
        //   ),
        // ],
      ),
      body: Container(
        decoration: BoxDecoration(
            gradient: AppState().bodyGradient
        ),
        child: Column(
          children: [
            // Search bar
            // Container(
            //   padding: const EdgeInsets.all(16),
            //   child: TextField(
            //     controller: _searchController,
            //     decoration: InputDecoration(
            //       hintText: 'Search by reason...',
            //       prefixIcon: const Icon(Icons.search),
            //       suffixIcon: _searchController.text.isNotEmpty
            //           ? IconButton(
            //         icon: const Icon(Icons.clear),
            //         onPressed: () {
            //           _searchController.clear();
            //           setState(() {});
            //         },
            //       ) : null,
            //       border: OutlineInputBorder(
            //         borderRadius: BorderRadius.circular(25),
            //         borderSide: BorderSide.none,
            //       ),
            //       filled: true,
            //       fillColor: Colors.white,
            //       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            //     ),
            //     onChanged: (value) => setState(() {}),
            //   ),
            // ),

            // Filters
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildFilterChips(),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredRegularizations.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No regularizations found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your attendance regularization requests will appear here',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                onRefresh: _fetchRegularizations,
                child: ListView.builder(
                  itemCount: _filteredRegularizations.length,
                  itemBuilder: (context, index) {
                    return _buildRegularizationCard(_filteredRegularizations[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // Navigate to new regularization request page
      //     // Navigator.pushNamed(context, '/new-regularization');
      //   },
      //   child: const Icon(Icons.add),
      // ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'late_arrival':
        return Icons.timer_sharp;
      case 'missed_swipe':
        return Icons.fingerprint;
      case 'outdoor_client_visit':
        return Icons.location_on;
      // case 'missed_punch':
      //   return Icons.warning;
      default:
        return Icons.access_time;
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatDate(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid time';
    }
  }

  Widget _buildApprovalLevel(Map<String, dynamic> regularization, int level) {
    final statusKey = 'level_${level}_status';
    final actionAtKey = 'level_${level}_action_at';
    final commentsKey = 'level_${level}_comments';

    // final status = regularization[statusKey];
    final String? rawStatus = regularization[statusKey] as String?;

    final String status = (rawStatus != null && rawStatus.isNotEmpty)
        ? rawStatus
        : 'pending';
    final actionAt = regularization[actionAtKey];
    final comments = regularization[commentsKey];

    // if (status == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Level $level Approver',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // if (actionAt != null) ...[
          //   const SizedBox(height: 4),
          //   Text(
          //     'Action taken: ${_formatDateTime(actionAt)}',
          //     style: TextStyle(
          //       fontSize: 12,
          //       color: Colors.grey[600],
          //     ),
          //   ),
          // ],
          if (comments != null && comments.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Comments: $comments',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRegularizationDetails(Map<String, dynamic> regularization) {
    final statusColor = _getStatusColor(regularization['status'] ?? 'pending');
    final totalLevels = regularization['approval_levels'] ?? 0;
    final level = widget.managerLevel;

    // Get current status and check if request is in terminal state
    final String? overallStatus = regularization['status'] as String?;
    final bool isTerminalState = ['rejected', 'cancelled', 'withdrawn', 'approved']
        .contains(overallStatus?.toLowerCase());

    // Get status at current manager level
    final String? levelStatus = regularization['level_${level}_status'] as String?;
    final String currentLevelStatus = (levelStatus != null && levelStatus.isNotEmpty)
        ? levelStatus
        : 'pending';

    // Check if any lower level has rejected
    bool isRejectedAtLowerLevel = false;
    for (int i = 1; i < level; i++) {
      final String? lowerLevelStatus = regularization['level_${i}_status'] as String?;
      if (lowerLevelStatus != null && lowerLevelStatus.toLowerCase() == 'rejected') {
        isRejectedAtLowerLevel = true;
        break;
      }
    }

    // Determine if action can be taken
    final bool canApprove =
        !isTerminalState &&
            !isRejectedAtLowerLevel &&
            currentLevelStatus == 'pending' &&
            currentLevelStatus != 'bypassed' &&
            level > 0 &&
            level <= 3;

    final isEmployee = AppState().userId == widget.employeeId && widget.managerLevel < 1;
    final status = (regularization['status'] ?? 'pending').toString().toLowerCase();
    final canCancel = isEmployee && !['rejected', 'cancelled', 'withdrawn', 'approved'].contains(status);


    // Get attendance date from requested_punch_in
    final attendanceDate = regularization['requested_punch_in'] != null
        ? _formatDate(regularization['requested_punch_in'])
        : _formatDate(regularization['created_at']);

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Draggable handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with date and status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Regularization Details',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            (regularization['status'] ?? 'pending').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Type indicator
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getTypeIcon(regularization['regularization_type']),
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          regularization['regularization_type']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'Regularization',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            textAlign: TextAlign.right,
                            'Date: $attendanceDate',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Basic Information
                    _buildDetailSection('Basic Information', [
                      // _buildDetailRow('Type', regularization['regularization_type'] ?? 'N/A'),
                      _buildDetailRow('Applied On', _formatDateTime(regularization['created_at'])),
                      _buildDetailRow(
                        'Reason',
                        (regularization['reason'] != null && regularization['reason'].isNotEmpty)
                            ? regularization['reason']
                            : 'N/A',
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // Time Comparison
                    _buildDetailSection('Time Details', [
                      // Punch In row
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Original Punch In
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Original Punch In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    regularization['original_punch_in'] != null
                                        ? _formatTime(regularization['original_punch_in'])
                                        : 'N/A',
                                    style: const TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Original Punch Out
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Original Punch Out',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    regularization['original_punch_out'] != null
                                        ? _formatTime(regularization['original_punch_out'])
                                        : 'N/A',
                                    style: const TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    ]),

                    const SizedBox(height: 16),

                    // Approval History
                    if (totalLevels > 0) ...[
                      Text(
                        'Approval History',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (int i = 1; i <= totalLevels; i++)
                        _buildApprovalLevel(regularization, i),
                    ],
                  ],
                ),
              ),
            ),
            if (canApprove || canCancel)  // Add this condition
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (canApprove)  // Existing approval button
                      ElevatedButton.icon(
                        onPressed: () {
                          _showApprovalDialog(regularization);
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: Text('Take Action: Level $level'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),

                    if (canCancel)  // NEW CANCEL BUTTON
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelRegularization(regularization['id']),
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('Cancel Request', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],

        ),
      ),
    )
    );
  }

  // Existing _buildDetailSection and _buildDetailRow methods remain unchanged
  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Status filter
          DropdownButton<String>(
            value: _selectedStatus,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Status')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'approved', child: Text('Approved')),
              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
            onChanged: (value) => setState(() => _selectedStatus = value!),
          ),
          const SizedBox(width: 16),
          // Type filter
          DropdownButton<String>(
            value: _selectedType,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Types')),
              DropdownMenuItem(value: 'late_arrival', child: Text('Late Arrival')),
              DropdownMenuItem(value: 'missed_swipe', child: Text('Missed Punch')),
              DropdownMenuItem(value: 'outdoor_client_visit', child: Text('Out Door')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _selectedType = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildRegularizationCard(Map<String, dynamic> regularization) {
    final employeeName = widget.employeeName;
    final status = regularization['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final totalLevels = regularization['approval_levels'] ?? 0;

    int approvedLevels = 0;
    bool needsAction = false;

    // Determine needsAction
    if (status == 'pending' && totalLevels > 0) {
      final currentManagerLevel = widget.managerLevel;

      if (currentManagerLevel <= totalLevels) {
        bool allPreviousApproved = true;

        for (int i = 1; i < currentManagerLevel; i++) {
          final s = regularization['level_${i}_status'];
          if (s != 'approved' && s != 'bypassed') {
            allPreviousApproved = false;
            break;
          }
        }

        final currentStatus = regularization['level_${currentManagerLevel}_status'];
        final isPending = currentStatus == 'pending' || currentStatus == null || currentStatus.toString().isEmpty;

        needsAction = allPreviousApproved && isPending && currentManagerLevel > 0;
      }

      for (int i = 1; i <= totalLevels; i++) {
        if (regularization['level_${i}_status'] == 'approved' || regularization['level_${i}_status'] == 'bypassed') {
          approvedLevels++;
        }
      }
    }

    final attendanceDate = regularization['requested_punch_in'] != null
        ? _formatDate(regularization['requested_punch_in'])
        : _formatDate(regularization['created_at']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedBuilder(
        animation: needsAction ? _zoomAnimation : AlwaysStoppedAnimation(1.0),
        builder: (context, child) {
          return Transform.scale(
            scale: needsAction ? _zoomAnimation.value : 1.0,
            child: Material(
              elevation: needsAction ? 8 : 4,
              shadowColor: needsAction
                  ? Colors.orange.withOpacity(0.4)
                  : Colors.black.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => _showRegularizationDetails(regularization),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: needsAction
                          ? [Colors.orange.shade50, Colors.white]
                          : [Colors.white, Colors.grey.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: needsAction
                          ? Colors.orange.withOpacity(0.5)
                          : statusColor.withOpacity(0.2),
                      width: needsAction ? 2.0 : 1.2,
                    ),
                    boxShadow: needsAction
                        ? [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (needsAction)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.priority_high,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: needsAction
                                      ? Colors.orange.shade100
                                      : Colors.teal.shade50,
                                  child: Text(
                                    employeeName != null && employeeName.isNotEmpty
                                        ? employeeName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: needsAction
                                          ? Colors.orange.shade700
                                          : Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  employeeName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: needsAction ? FontWeight.w900 : FontWeight.bold,
                                    color: needsAction ? Colors.orange.shade900 : Colors.black87,
                                  ),
                                ),
                                // const SizedBox(width: 8),
                                // Text(
                                //   '($employeeCode)',
                                //   style: TextStyle(
                                //     fontSize: 11,
                                //     color: Colors.grey[600],
                                //   ),
                                // ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: needsAction
                                        ? Colors.orange.shade50
                                        : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: needsAction
                                          ? Colors.orange.shade200
                                          : Colors.blue.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    _getTypeIcon(regularization['regularization_type']),
                                    color: needsAction
                                        ? Colors.orange.shade600
                                        : Colors.blue.shade600,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        attendanceDate,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: needsAction
                                              ? Colors.orange.shade900
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        regularization['regularization_type']
                                            ?.toString()
                                            .replaceAll('_', ' ')
                                            .toUpperCase() ??
                                            'REGULARIZATION',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (needsAction)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.touch_app, color: Colors.orange.shade700, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ACTION REQUIRED - Your approval needed',
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (needsAction) const SizedBox(height: 8),

                            if (regularization['reason'] != null && regularization['reason'].toString().isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: needsAction
                                      ? Colors.orange.shade50
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: needsAction
                                        ? Colors.orange.shade200
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  regularization['reason'],
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 8),

                            if (status == 'pending' && totalLevels > 0)
                              Row(
                                children: [
                                  Text(
                                    'APPROVAL: ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: approvedLevels / totalLevels,
                                      backgroundColor: Colors.grey[200],
                                      color: needsAction ? Colors.green : Colors.green,
                                      minHeight: 6,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$approvedLevels/$totalLevels',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: needsAction ? Colors.green : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Applied: ${_formatDate(regularization['created_at'])}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }


// Compact time chip version
  Widget _buildCompactTimeChip(String label, String time, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


}