import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/app_state.dart';
import 'leave_history_page.dart';

class LeaveApplicationPage extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const LeaveApplicationPage({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<LeaveApplicationPage> createState() => _LeaveApplicationPageState();
}

class _LeaveApplicationPageState extends State<LeaveApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  int? selectedLeaveTypeId;
  DateTime? startDate;
  DateTime? endDate;
  DateTime currentTime = DateTime.now();
  int totalDays = 0;

  List<Map<String, dynamic>> leaveTypes = [];
  Map<String, dynamic>? selectedBalance;
  bool isLoading = true;
  bool isSubmitting = false;

  // Map to store leave balances by leave type ID
  Map<int, Map<String, dynamic>> leaveBalancesMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      currentTime = await AppState().getCurrentTime();
      final balances = await supabase
          .from('employee_leave_balances')
          .select('*, leave_types(*)')
          .eq('employee_id', widget.userProfile['id'])
          .eq('calendar_year', currentTime.year);

      final List<Map<String, dynamic>> validLeaveTypes = [];

      for (var balance in balances) {
        final leaveType = balance['leave_types'];
        if (leaveType != null && (leaveType['is_active'] ?? false)) {
          final leaveTypeId = balance['leave_type_id'] as int;
          leaveBalancesMap[leaveTypeId] = balance;
          validLeaveTypes.add(leaveType);
        }
      }

      setState(() {
        leaveTypes = validLeaveTypes;
        isLoading = false;
      });
    } catch (e) {
      _showMessage('Failed to load data', isError: true);
      setState(() => isLoading = false);
    }
  }


  void _onLeaveTypeChanged(int? leaveTypeId) {
    setState(() {
      selectedLeaveTypeId = leaveTypeId;
      if (leaveTypeId != null) {
        selectedBalance = leaveBalancesMap[leaveTypeId];
      } else {
        selectedBalance = null;
      }
    });
  }

  void _calculateDays() {
    if (startDate != null && endDate != null) {
      setState(() {
        totalDays = endDate!.difference(startDate!).inDays + 1;
      });
    } else {
      setState(() => totalDays = 0);
    }
  }

  Future<void> _selectDate(bool isStart) async {
    final ThemeData datePickerTheme = Theme.of(context).copyWith(
      colorScheme: const ColorScheme.light(
        primary: Colors.deepPurple, // Header background
        onPrimary: Colors.white,    // Header text color
        onSurface: Colors.black,    // Default text color
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.deepPurple, // Button text color
        ),
      ),
      dialogBackgroundColor: Colors.white,
      datePickerTheme: const DatePickerThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );

    final DateTime initial = isStart
        ? currentTime.add(const Duration(days: 1))
        : startDate ?? currentTime;

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: currentTime,
      lastDate: currentTime.add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(data: datePickerTheme, child: child!);
      },
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          startDate = date;
          if (endDate != null && endDate!.isBefore(date)) {
            endDate = null;
          }
        } else {
          endDate = date;
        }
      });
      _calculateDays();
    }
  }


  String? _validateForm() {
    if (selectedLeaveTypeId == null) return 'Please select leave type';
    if (startDate == null || endDate == null) return 'Please select dates';
    if (endDate!.isBefore(startDate!)) return 'End date cannot be before start date';
    if (_reasonController.text.trim().isEmpty) return 'Please provide reason';

    // Check balance
    if (selectedBalance != null) {
      final available = selectedBalance!['available_days'] ?? 0;
      if (totalDays > available) {
        return 'Insufficient balance (Available: $available days)';
      }
    }

    try {
      final leaveType = leaveTypes.firstWhere((t) => t['id'] == selectedLeaveTypeId);
      final maxDays = leaveType['max_consecutive_days'];
      if (maxDays != null && totalDays > maxDays) {
        return 'Maximum $maxDays consecutive days allowed';
      }

      // Fixed notice period validation
      final noticeDays = leaveType['notice_period_days'] ?? 1;
      if (noticeDays > 0) { // Only validate if notice period is required
        final requiredDate = currentTime.add(Duration(days: noticeDays));
        final startDateOnly = DateTime(startDate!.year, startDate!.month, startDate!.day);
        final requiredDateOnly = DateTime(requiredDate.year, requiredDate.month, requiredDate.day);

        if (startDateOnly.isBefore(requiredDateOnly)) {
          return '$noticeDays days notice required';
        }
      }
    } catch (e) {
      return 'Error validating leave type constraints';
    }

    return null;
  }




  Future<void> _submitApplication() async {
    final error = _validateForm();
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    setState(() => isSubmitting = true);

    try {

      if (AppState().workSchedule == null || AppState().workSchedule!.isEmpty) {
        _showMessage('Schedule not found', isError: true);
        return;
      }

      final now = await AppState().getCurrentTime(); // Assumes device is in IST
      // final startTime = DateTime(now.year, now.month, now.day, 6, 0);     // 6:00 AM
      // final endTime = DateTime(now.year, now.month, now.day, 23, 30);     // 11:30 PM
      //
      // if (now.isBefore(startTime) || now.isAfter(endTime)) {
      //   _showMessage('Leave submissions are allowed only between 6:00 AM and 11:30 PM', isError: true);
      //   return;
      // }

      final calendarYear = now.year; // Or use startDate!.year if different

      final response = await supabase.rpc('submit_leave_application', params: {
        'p_employee_id': widget.userProfile['id'],
        'p_leave_type_id': selectedLeaveTypeId,
        'p_start_date': DateFormat('yyyy-MM-dd').format(startDate!),
        'p_end_date': DateFormat('yyyy-MM-dd').format(endDate!),
        'p_total_days': totalDays,
        'p_reason': _reasonController.text.trim(),
        'p_applied_by': supabase.auth.currentUser!.id,
        'p_approval_levels': widget.userProfile['approval_levels'] ?? 2,
        'p_calendar_year': calendarYear,
        'p_current_time': now.toIso8601String(), // ISO 8601 format
      });

      if (response['success'] as bool) {
        _showMessage('Leave application submitted successfully!');
        if (mounted) Navigator.pop(context);
      } else {
        _showMessage(response['message'] as String, isError: true);
      }
    } catch (e) {
      _showMessage('Failed to submit application: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<bool> _checkForDateClash() async {
    if (startDate == null || endDate == null) return false;

    try {
      final response = await supabase.rpc('check_leave_overlap', params: {
        'p_employee_id': widget.userProfile['id'],
        'p_start_date': DateFormat('yyyy-MM-dd').format(startDate!),
        'p_end_date': DateFormat('yyyy-MM-dd').format(endDate!),
      });

      return response as bool;
    } catch (e) {
      _showMessage('Error checking date availability', isError: true);
      return true; // Prevent submission on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Request for Leave',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // Use Navigator.push to go to the AttendanceHistoryPage
              Navigator.push(
                context, // 'context' is required here, make sure this code is within a Widget's build method or has access to a BuildContext.
                MaterialPageRoute(
                  builder: (context) => LeaveHistoryPage(
                    employeeId: widget.userProfile['id'],
                    employeeName: widget.userProfile['full_name'],
                    managerId: '',
                    managerLevel: 0,
                  ),
                ),
              );
            },
          ),
        ],

      ),
      body: isLoading
          ? Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ) : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Employee Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: widget.userProfile['avatar_url'] != null
                          ? NetworkImage(widget.userProfile['avatar_url'])
                          : null,
                      child: widget.userProfile['avatar_url'] == null
                          ? Text((widget.userProfile['full_name'] ?? 'U')[0])
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.userProfile['full_name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          Text(
                            widget.userProfile['employee_code'] ?? '',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Leave Type Dropdown
              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: 'Leave Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.event_note),
                ),
                value: selectedLeaveTypeId,
                items: leaveTypes.map((type) => DropdownMenuItem(
                  value: type['id'] as int,
                  child: Text(type['leave_name'] ?? ''),
                )).toList(),
                onChanged: _onLeaveTypeChanged,
              ),

              // Balance Info
              if (selectedBalance != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // _buildBalanceItem('Available', selectedBalance!['available_days'] ?? 0, Colors.green),
                      _buildBalanceItem('Used', selectedBalance!['used_days'] ?? 0, Colors.orange),
                      _buildBalanceItem('Pending', selectedBalance!['pending_days'] ?? 0, Colors.blue),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Date Selection
              // Date Selection
              Row(
                children: [
                  Expanded(
                    child: _buildInputCard( // Wrap in helper
                      child: InkWell(
                        onTap: () => _selectDate(true),
                        child: Padding( // Add padding for content
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 6), // Slightly more vertical space
                              Text(
                                startDate != null
                                    ? DateFormat('dd MMM, yyyy').format(startDate!) // Full year for clarity
                                    : 'Select date',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4), // Add space for icon
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Icon(Icons.calendar_today, size: 20, color: Colors.blue.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInputCard( // Wrap in helper
                      child: InkWell(
                        onTap: startDate != null ? () => _selectDate(false) : null,
                        child: Padding( // Add padding for content
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('End Date', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 6),
                              Text(
                                endDate != null
                                    ? DateFormat('dd MMM, yyyy').format(endDate!) // Full year for clarity
                                    : 'Select date',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Icon(Icons.calendar_today, size: 20, color: Colors.blue.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Row(
              //   children: [
              //     Expanded(
              //       child: InkWell(
              //         onTap: () => _selectDate(true),
              //         child: Container(
              //           padding: EdgeInsets.all(16),
              //           decoration: BoxDecoration(
              //             border: Border.all(color: Colors.grey.shade300),
              //             borderRadius: BorderRadius.circular(12),
              //           ),
              //           child: Column(
              //             crossAxisAlignment: CrossAxisAlignment.start,
              //             children: [
              //               Text('Start Date', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              //               SizedBox(height: 4),
              //               Text(
              //                 startDate != null
              //                     ? DateFormat('dd MMM yyyy').format(startDate!)
              //                     : 'Select date',
              //                 style: TextStyle(fontSize: 16),
              //               ),
              //             ],
              //           ),
              //         ),
              //       ),
              //     ),
              //     SizedBox(width: 16),
              //     Expanded(
              //       child: InkWell(
              //         onTap: startDate != null ? () => _selectDate(false) : null,
              //         child: Container(
              //           padding: EdgeInsets.all(16),
              //           decoration: BoxDecoration(
              //             border: Border.all(color: Colors.grey.shade300),
              //             borderRadius: BorderRadius.circular(12),
              //           ),
              //           child: Column(
              //             crossAxisAlignment: CrossAxisAlignment.start,
              //             children: [
              //               Text('End Date', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              //               SizedBox(height: 4),
              //               Text(
              //                 endDate != null
              //                     ? DateFormat('dd MMM yyyy').format(endDate!)
              //                     : 'Select date',
              //                 style: TextStyle(fontSize: 16),
              //               ),
              //             ],
              //           ),
              //         ),
              //       ),
              //     ),
              //   ],
              // ),

              // Total Days
              if (totalDays > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Total Days: $totalDays',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Reason Field
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason for Leave',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description),
                  hintText: 'Enter your reason...',
                  // counterText: _reasonController.text.isNotEmpty
                  //     ? '${_reasonController.text.length}/100' // Display current count/max
                  //     : null, // Don't show counter if empty
                ),
                maxLines: 3,
                maxLength: 100,
                keyboardType: TextInputType.multiline,
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submitApplication,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Submit Request', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to wrap input fields in a consistent card-like styling
  Widget _buildInputCard({required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.zero,
      child: child, // The actual input field goes here
    );
  }

  Widget _buildBalanceItem(String label, dynamic value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}