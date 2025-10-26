import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/app_state.dart';

class LeaveHistoryPage extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String managerId;
  final int managerLevel;

  const LeaveHistoryPage({super.key,
    required this.employeeId,
    required this.employeeName,
    required this.managerId,
    required this.managerLevel,
  });

  @override
  State<LeaveHistoryPage> createState() => _LeaveHistoryPageState();
}

class _LeaveHistoryPageState extends State<LeaveHistoryPage>
    with TickerProviderStateMixin  {

  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;

  List<Map<String, dynamic>> _leaveApplications = [];
  List<Map<String, dynamic>> _leaveTypes = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedLeaveType = 'all';
  final TextEditingController _searchController = TextEditingController();

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

    _fetchLeaveData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaveData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch leave applications with leave type details
      final leaveResponse = await supabase
          .from('leave_applications')
          .select('''
            *,
            leave_types!inner(
              leave_name,
              leave_code
            )
          ''')
          .eq('employee_id', widget.employeeId)
          .order('created_at', ascending: false);

      // Fetch leave types for filter
      final leaveTypesResponse = await supabase
          .from('leave_types')
          .select('*')
          .eq('is_active', true);

      setState(() {
        _leaveApplications = List<Map<String, dynamic>>.from(leaveResponse);
        _leaveTypes = List<Map<String, dynamic>>.from(leaveTypesResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load leave history: ${e.toString()}');
    }
  }

  List<Map<String, dynamic>> get _filteredLeaveApplications {
    return _leaveApplications.where((leave) {
      // Status filter
      if (_selectedStatus != 'all' && leave['status'] != _selectedStatus) {
        return false;
      }

      // Leave type filter
      if (_selectedLeaveType != 'all' && leave['leave_type_id'].toString() != _selectedLeaveType) {
        return false;
      }

      // Search filter
      if (_searchController.text.isNotEmpty) {
        final searchTerm = _searchController.text.toLowerCase();
        final reason = (leave['reason'] ?? '').toString().toLowerCase();
        final leaveTypeName = (leave['leave_types']?['leave_name'] ?? '').toString().toLowerCase();
        if (!reason.contains(searchTerm) && !leaveTypeName.contains(searchTerm)) {
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

  IconData _getLeaveTypeIcon(String? leaveCode) {
    switch (leaveCode?.toLowerCase()) {
      case 'cl':
      case 'casual':
        return Icons.beach_access;
      case 'sl':
      case 'sick':
        return Icons.medical_services;
      case 'comp':
      case 'earned':
        return Icons.work_off;
      case 'special':
      case 'special_leave':
        return Icons.money_off;
      case 'ml':
      case 'maternity':
        return Icons.child_care;
      case 'pl':
      case 'privilege':
        return Icons.star;
      case 'lwp':
      case 'loss_of_pay':
        return Icons.money_off;
      default:
        return Icons.calendar_today;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid date';
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

  String _formatFinalApprovalDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _calculateDuration(String startDate, String endDate) {
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final duration = end.difference(start).inDays + 1;
      return '$duration day${duration != 1 ? 's' : ''}';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildApprovalLevel(Map<String, dynamic> leaveApplication, int level) {
    final statusKey = 'level_${level}_status';
    final actionAtKey = 'level_${level}_action_at';
    final commentsKey = 'level_${level}_comments';

    // final status = leaveApplication[statusKey];
    final String? rawStatus = leaveApplication[statusKey] as String?;
    final String status = (rawStatus != null && rawStatus.isNotEmpty)
        ? rawStatus
        : 'pending';

    final actionAt = leaveApplication[actionAtKey];
    final comments = leaveApplication[commentsKey];

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

  void _showLeaveDetails(Map<String, dynamic> leaveApplication) {
    final statusColor = _getStatusColor(leaveApplication['status'] ?? 'pending');
    final totalLevels = leaveApplication['approval_levels'] ?? 0;
    final level = widget.managerLevel;
    final leaveType = leaveApplication['leave_types'];

    // Get current status and check if request is in terminal state
    final String? overallStatus = leaveApplication['status'] as String?;
    final bool isTerminalState = ['rejected', 'cancelled', 'withdrawn', 'approved']
        .contains(overallStatus?.toLowerCase());

    // Get status at current manager level
    final String? levelStatus = leaveApplication['level_${level}_status'] as String?;
    final String currentLevelStatus = (levelStatus != null && levelStatus.isNotEmpty)
        ? levelStatus
        : 'pending';

    // Check if any lower level has rejected
    bool isRejectedAtLowerLevel = false;
    for (int i = 1; i < level; i++) {
      final String? lowerLevelStatus = leaveApplication['level_${i}_status'] as String?;
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
    final status = (leaveApplication['status'] ?? 'pending').toString().toLowerCase();
    final canCancel = isEmployee && !['rejected', 'cancelled', 'withdrawn', 'approved'].contains(status);


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
                      // Header with leave type and status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Leave Application Details',
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
                              (leaveApplication['status'] ?? 'pending').toUpperCase(),
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

                      // Leave type indicator
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getLeaveTypeIcon(leaveType?['leave_code']),
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  leaveType?['leave_name'] ?? 'Leave',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${_formatDate(leaveApplication['start_date'])} - ${_formatDate(leaveApplication['end_date'])}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Basic Information
                      _buildDetailSection('Leave Information', [
                        _buildDetailRow('Leave Type', leaveType?['leave_name'] ?? 'N/A'),
                        _buildDetailRow('Start Date', _formatDate(leaveApplication['start_date'])),
                        _buildDetailRow('End Date', _formatDate(leaveApplication['end_date'])),
                        _buildDetailRow('Total Days', leaveApplication['total_days']?.toString() ?? 'N/A'),
                        _buildDetailRow('Applied On', _formatDateTime(leaveApplication['created_at'])),
                        _buildDetailRow('Reason', leaveApplication['reason'] ?? 'No reason provided'),
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
                          _buildApprovalLevel(leaveApplication, i),
                      ],

                      // Final approval info
                      // if (leaveApplication['final_approved_at'] != null) ...[
                      //   const SizedBox(height: 16),
                      //   _buildDetailSection('Final Approval', [
                      //     _buildDetailRow('Approved At', _formatFinalApprovalDateTime(leaveApplication['final_approved_at'])),
                      //   ]),
                      // ],
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
                            _showLeaveApprovalDialog(leaveApplication);
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: Text('Take Action: Level ${widget.managerLevel}'),
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
                            onPressed: () => _cancelLeaveApplication(leaveApplication['id']),
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
      ),
    );
  }

  // Add these methods to your _LeaveHistoryPageState class

  void _showLeaveApprovalDialog(Map<String, dynamic> leaveApplication) {
    final TextEditingController commentsController = TextEditingController();
    final leaveType = leaveApplication['leave_types'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take Action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leave Type: ${leaveType?['leave_name'] ?? 'N/A'}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Duration: ${_formatDate(leaveApplication['start_date'])} - ${_formatDate(leaveApplication['end_date'])}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Days: ${leaveApplication['total_days']?.toString() ?? 'N/A'}',
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
                  (leaveApplication['reason'] != null && leaveApplication['reason'].toString().isNotEmpty)
                      ? leaveApplication['reason']
                      : 'No reason provided'
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
              Navigator.pop(context); // Close the details modal too
              _handleLeaveApprovalAction(
                leaveApplication,
                'rejected',
                commentsController.text.trim(),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close the details modal too
              _handleLeaveApprovalAction(
                leaveApplication,
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

  Future<void> _handleLeaveApprovalAction(
      Map<String, dynamic> leaveApplication,
      String action,
      String comments,
      ) async {
    try {

      final now = await AppState().getCurrentTime(); // Assumes device is in IST
      final startTime = DateTime(now.year, now.month, now.day, 6, 0);     // 6:00 AM
      final endTime = DateTime(now.year, now.month, now.day, 23, 30);     // 11:30 PM

      if (now.isBefore(startTime) || now.isAfter(endTime)) {
        _showErrorSnackBar('Leave approvals are allowed only between 6:00 AM and 11:30 PM');
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

      // Call the RPC function to handle leave approval
      final response = await supabase.rpc('handle_leave_approval', params: {
        'leave_application_id': leaveApplication['id'],
        'manager_id': widget.managerId,
        'action': action,
        'comments': comments,
        'current_level': widget.managerLevel,
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

        if (statusCode >= 200 && statusCode < 300) {
          _showMessage(message);
        } else if (statusCode == 409) {
          _showMessage(message, isError: true);
        } else {
          _showErrorSnackBar(message);
        }
      } else {
        _showMessage('Leave $action successfully');
      }

      // Refresh the leave data
      await _fetchLeaveData();

    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
      _showErrorSnackBar('Approval failed: ${e.toString()}');
    }
  }

  Future<void> _cancelLeaveApplication(int leaveAppId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Cancellation'),
        content: const Text('Are you sure you want to cancel this leave application?'),
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
        _showErrorSnackBar('Leave cancellation are allowed only between 6:00 AM and 11:30 PM');
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

      final response = await supabase.rpc('cancel_leave_application', params: {
        'leave_application_id': leaveAppId,
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
          await _fetchLeaveData();
        } else {
          _showErrorSnackBar(message);
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorSnackBar('Cancellation failed: ${e.toString()}');
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min, // Ensures the Column takes minimum vertical space
          children: [
            const Text(
              'Leave History',
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
        //     onPressed: _fetchLeaveData,
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
            //       hintText: 'Search by reason or leave type...',
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
                  : _filteredLeaveApplications.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No leave applications found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your leave applications will appear here',
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
                onRefresh: _fetchLeaveData,
                child: ListView.builder(
                  itemCount: _filteredLeaveApplications.length,
                  itemBuilder: (context, index) {
                    return _buildLeaveCard(_filteredLeaveApplications[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// You'll also need this helper method to build detail rows (if not already present)
  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 8),
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
          // Leave type filter
          DropdownButton<String>(
            value: _selectedLeaveType,
            underline: const SizedBox(),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Types')),
              ..._leaveTypes.map((type) => DropdownMenuItem(
                value: type['id'].toString(),
                child: Text(type['leave_name']),
              )),
            ],
            onChanged: (value) => setState(() => _selectedLeaveType = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leaveApplication) {
    final employeeName = widget.employeeName;
    final status = leaveApplication['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final totalLevels = leaveApplication['approval_levels'] ?? 0;
    final leaveType = leaveApplication['leave_types'];

    int approvedLevels = 0;
    bool needsAction = false;

    // Calculate approval progress and check if action is needed
    if (status == 'pending' && totalLevels > 0) {
      final currentManagerLevel = widget.managerLevel;

      // Don't show action needed if manager level is above approval levels
      if (currentManagerLevel <= totalLevels) {
        bool allPreviousLevelsCompleted = true;

        // Check if all previous levels are approved/bypassed
        for (int i = 1; i < currentManagerLevel; i++) {
          final levelStatus = leaveApplication['level_${i}_status'];
          if (levelStatus != 'approved' && levelStatus != 'bypassed') {
            allPreviousLevelsCompleted = false;
            break;
          }
        }

        // Check if current manager's level is pending
        final currentLevelStatus = leaveApplication['level_${currentManagerLevel}_status'];
        final isCurrentLevelPending = currentLevelStatus == 'pending' ||
            currentLevelStatus == null ||
            currentLevelStatus.toString().isEmpty;

        needsAction = allPreviousLevelsCompleted && isCurrentLevelPending && currentManagerLevel > 0;
      }

      // Calculate approved levels for progress bar
      for (int i = 1; i <= totalLevels; i++) {
        if (leaveApplication['level_${i}_status'] == 'approved' ||
            leaveApplication['level_${i}_status'] == 'bypassed') {
          approvedLevels++;
        }
      }
    }

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
                onTap: () => _showLeaveDetails(leaveApplication),
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
                    boxShadow: needsAction ? [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                  child: Stack( // This is the Stack
                    children: [ // These are the children of the Stack
                      // Action required indicator
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

                      Padding( // This Padding is the second child of the Stack
                        padding: const EdgeInsets.all(16),
                        child: Column(
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
                            // Header Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon
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
                                    _getLeaveTypeIcon(leaveType?['leave_code']),
                                    color: needsAction
                                        ? Colors.orange.shade600
                                        : Colors.blue.shade600,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Title and dates
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        leaveType?['leave_name'] ?? 'Leave',
                                        style: TextStyle(
                                          fontWeight: needsAction ? FontWeight.w900 : FontWeight.bold,
                                          fontSize: 14,
                                          color: needsAction ? Colors.orange.shade900 : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_formatDate(leaveApplication['start_date'])} - ${_formatDate(leaveApplication['end_date'])}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Status badge
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

                            // Action required banner
                            if (needsAction) ...[
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
                                    Icon(
                                      Icons.touch_app,
                                      color: Colors.orange.shade700,
                                      size: 16,
                                    ),
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
                              const SizedBox(height: 8),
                            ],

                            // Reason Section
                            if (leaveApplication['reason'] != null && leaveApplication['reason'].toString().isNotEmpty) ...[
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
                                          : Colors.grey.shade200
                                  ),
                                ),
                                child: Text(
                                  leaveApplication['reason'],
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
                            ],

                            // Approval progress bar - Only for pending
                            if (status == 'pending' && totalLevels > 0) ...[
                              const SizedBox(height: 6),
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
                            ],

                            // Footer
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildCompactInfoChip(
                                  'Duration',
                                  leaveApplication['total_days']?.toString() ?? '0',
                                  needsAction ? Colors.green : Colors.green,
                                  Icons.calendar_month,
                                ),
                                Text(
                                  'Applied: ${_formatDate(leaveApplication['created_at'])}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            )
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

  Widget _buildCompactInfoChip(String label, String value, Color color, IconData icon) {
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
            '$value ${value == '1' ? 'day' : 'days'}',
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