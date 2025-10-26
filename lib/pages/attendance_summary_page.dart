import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mnr/pages/attendance_regularization_page.dart';
import 'package:mnr/pages/leave_history_page.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/app_state.dart';
import 'leave_application_page.dart';

class AttendanceSummaryPage extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final int managerLevel;
  final String managerId;

  const AttendanceSummaryPage({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.managerLevel,
    required this.managerId,
  });

  @override
  _AttendanceSummaryPageState createState() => _AttendanceSummaryPageState();
}

class _AttendanceSummaryPageState extends State<AttendanceSummaryPage> {
  bool loading = false;
  bool isSubmitting = false;

  late DateTime _focusedDay;
  late DateTime _selectedDay;

  late DateTime currentTime;

  // Summary data
  Map<String, int> summaryData = {
    'present': 0,
    'absent': 0,
    'halfDay': 0,
    'onLeave': 0,
    'totalWorkingDays': 0,
  };

  // Calendar data
  Map<DateTime, AttendanceStatus> attendanceMap = {};
  List<AttendanceRecord> attendanceRecords = [];
  List<Holiday> holidays = [];

  double minWorkHours = 8.0;
  double maxWorkHours = 12.0;

  Map<String, dynamic>? workSchedule;
  // Map to store leave balances by leave type ID
  Map<int, Map<String, dynamic>> leaveBalancesMap = {};
  List<Map<String, dynamic>> leaveTypes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);

    try {

      currentTime = await AppState().getCurrentTime();
      _focusedDay = currentTime;
      _selectedDay = currentTime;

      await Future.wait([
        _loadAttendanceData(currentTime),
        _loadHolidays(currentTime),
      ]);

      await _loadSummaryData(currentTime);


    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _loadAttendanceData(DateTime month) async {

    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);


    final response = await supabase
        .from('attendance')
        .select('*')
        .eq('employee_id', widget.employeeId)
        .gte('date', startOfMonth.toIso8601String().split('T')[0])
        .lte('date', endOfMonth.toIso8601String().split('T')[0]);

    attendanceRecords = (response as List)
        .map((record) => AttendanceRecord.fromJson(record))
        .toList();

    final yesterday = currentTime.subtract(const Duration(days: 1));
    final normalizedYesterday = _normalizeDate(yesterday);
    // Build attendance map for calendar
    attendanceMap.clear();
    for (final record in attendanceRecords) {
      if (_normalizeDate(record.date).isAfter(normalizedYesterday)) {
        // Skip today and future days
        continue;
      }
      attendanceMap[_normalizeDate(record.date)] = _getAttendanceStatus(record);
    }

  }

  Future<void> _loadHolidays(DateTime month) async {
    final response = await supabase
        .from('holidays')
        .select('*')
        .eq('calendar_year', month.year)
        .eq('is_active', true);

    holidays = (response as List)
        .map((holiday) => Holiday.fromJson(holiday))
        .toList();
  }

  Future<void> _loadSummaryData(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    Map<String, dynamic>? employeeWorkSchedule = AppState().workSchedule;

    if (AppState().workSchedule == null || AppState().workSchedule!.isEmpty) {
      // Get work schedule for the employee
      final workScheduleResponse = await supabase
          .from('work_schedules')
          .select('*')
          .eq('employee_id', widget.employeeId)
          .maybeSingle();

      if (workScheduleResponse != null) {
        AppState().workSchedule = workScheduleResponse;
        employeeWorkSchedule = workScheduleResponse; // Update local reference
      }
    }

    minWorkHours = (employeeWorkSchedule?['min_work_hours'] ?? 8.0).toDouble();
    maxWorkHours = (employeeWorkSchedule?['max_work_hours'] ?? 12.0).toDouble();


    List<String> workingWeekdays = List<String>.from(employeeWorkSchedule?['weekdays'] ??
        ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday']);

    // Get leave applications for the month
    final leaveResponse = await supabase
        .from('leave_applications')
        .select('start_date, end_date, status')
        .eq('employee_id', widget.employeeId)
        .eq('status', 'approved')
        .or('start_date.lte.${endOfMonth.toIso8601String().split('T')[0]},end_date.gte.${startOfMonth.toIso8601String().split('T')[0]}');

    List<DateTime> leaveDates = [];
    for (var leave in leaveResponse) {
      DateTime startDate = DateTime.parse(leave['start_date']);
      DateTime endDate = DateTime.parse(leave['end_date']);

      for (DateTime date = startDate;
      date.isBefore(endDate.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))) {
        leaveDates.add(date);
      }
    }

    List<DateTime> optionalHolidayDates = [];

    final optionalHolidayResponse = await supabase
        .from('employee_holiday_selections')
        .select('selected_date')
        .eq('employee_id', widget.employeeId)
        .eq('status', 'approved');

    optionalHolidayDates = List<DateTime>.from(
        optionalHolidayResponse.map((e) => DateTime.parse(e['selected_date']))
    );


    // Calculate working days and attendance summary
    int workingDays = 0;
    int present = 0;
    int absent = 0;
    int halfDay = 0;
    int onLeave = 0;

    final today = _normalizeDate(currentTime);

    for (DateTime day = startOfMonth;
    day.isBefore(endOfMonth.add(const Duration(days: 1)));
    day = day.add(const Duration(days: 1))) {

      final normalizedDay = _normalizeDate(day);

      // Check if it's a working day
      String weekdayName = _getWeekdayName(day.weekday);


      // === Priority: 1. Leave ===
      if (leaveDates.contains(normalizedDay)) {
        onLeave++;
        attendanceMap[normalizedDay] = AttendanceStatus.leave;
        continue;
      }

      // === Priority: 2. Optional Holiday ===
      if (optionalHolidayDates.contains(normalizedDay)) {
        attendanceMap[normalizedDay] = AttendanceStatus.holiday;
        continue;
      }

      // Check if it's a holiday
      final isHoliday = holidays.any((h) =>
      _normalizeDate(h.holidayDate) == normalizedDay);
      if (isHoliday) {
        // attendanceMap[normalizedDay] = AttendanceStatus.holiday;
        if (!attendanceMap.containsKey(normalizedDay)) {
          attendanceMap[normalizedDay] = AttendanceStatus.holiday;
          continue;
        }
      }

      if (workingWeekdays.contains(weekdayName) && !isHoliday) {
        workingDays++;
      }


      if (!attendanceMap.containsKey(normalizedDay) &&
          normalizedDay.isBefore(_normalizeDate(currentTime)) &&
          workingWeekdays.contains(weekdayName)) {
        attendanceMap[normalizedDay] = AttendanceStatus.absent;

        // Add to records if needed elsewhere
        attendanceRecords.add(
          AttendanceRecord.empty(normalizedDay),
        );
      }

      // Find attendance record
      final record = attendanceRecords.where((r) =>
      r.date.year == day.year &&
          r.date.month == day.month &&
          r.date.day == day.day).isEmpty ? null : attendanceRecords.where((r) =>
      r.date.year == day.year &&
          r.date.month == day.month &&
          r.date.day == day.day).first;


      // Check if weekend (non-working day)
      if (!workingWeekdays.contains(weekdayName) && record?.status == 'comp-w' || record?.status == 'present') {
        attendanceMap[normalizedDay] = AttendanceStatus.present;
        // continue;
      }
      else if (!workingWeekdays.contains(weekdayName) && (record?.status == 'leave' || record?.status == 'comp-off')) {
        attendanceMap[normalizedDay] = AttendanceStatus.leave;
      }
      else if (!workingWeekdays.contains(weekdayName) && normalizedDay.isBefore(today) && record?.status != 'absent') {
        attendanceMap[normalizedDay] = AttendanceStatus.weekend;
      }

      if (normalizedDay.isAtSameMomentAs(today) || normalizedDay.isAfter(today)) continue;

      if (record == null) {
        // No attendance record
        if (day.isBefore(currentTime.subtract(const Duration(days: 1))) && workingWeekdays.contains(weekdayName)) {
          absent++;
        }
      }
      else {
        // Handle compensatory work as present
        if (record.status == 'comp-w') {
          present++;
        }
        // Handle other statuses
        else if (record.status == 'present') {
          present++;
        } else if (record.status == 'half-day') {
          halfDay++;
        } else if (record.status == 'absent') {
          absent++;
        } else if (record.status == 'leave' || record.status == 'comp-off') {
          onLeave++;
        }

      }
    }

    summaryData = {
      'present': present,
      'absent': absent,
      'halfDay': halfDay,
      'onLeave': onLeave,
      'totalWorkingDays': workingDays,
    };
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'monday';
      case DateTime.tuesday: return 'tuesday';
      case DateTime.wednesday: return 'wednesday';
      case DateTime.thursday: return 'thursday';
      case DateTime.friday: return 'friday';
      case DateTime.saturday: return 'saturday';
      case DateTime.sunday: return 'sunday';
      default: return 'monday';
    }
  }

  AttendanceStatus _getAttendanceStatus(AttendanceRecord record) {
    // Check if it's a leave day first
    // if (_isLeaveDay(record.date) || record.status == 'comp-off') return AttendanceStatus.leave;
    if (record.status == 'leave' || record.status == 'comp-off') return AttendanceStatus.leave;

    if (record.status == 'absent' || record.isEmpty) return AttendanceStatus.absent;
    if (record.status == 'present' || record.status == 'comp-w') return AttendanceStatus.present;
    if (record.status == 'half-day') return AttendanceStatus.halfDay;
    if (record.status == 'weekend') return AttendanceStatus.weekend;
    if (record.status == 'holiday') return AttendanceStatus.holiday;


    return AttendanceStatus.absent;
  }

  Future<void> _loadDataForMonth(DateTime month) async {
    setState(() => loading = true);
    try {
      await Future.wait([
        _loadAttendanceData(month),
        _loadHolidays(month),
      ]);
      // await _loadLeaveData(month);
      await _loadSummaryData(month);
    } catch (e) {
      // Error handling
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _loadAvailableLeaveTypes() async {
    try {
      final balances = await supabase
          .from('employee_leave_balances')
          .select('*, leave_types(*)')
          .eq('employee_id', widget.employeeId)
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
      });
    } catch (e) {
      print('Failed to load data $e');
    }
  }


  void _showAttendanceDetails(DateTime selectedDate) {
    final Set<int> allowedMonthlyAttendanceDepartments = {1};
    final bool canAccessMonthlyAttendance = AppState().managedDepartmentIds.any(
          (deptId) => allowedMonthlyAttendanceDepartments.contains(deptId),
    );

    // Find the attendance record from the already fetched data
    final attendanceRecord = attendanceRecords.firstWhere(
          (record) => _normalizeDate(record.date) == _normalizeDate(selectedDate),
      orElse: () => AttendanceRecord.empty(selectedDate),
    );

    // Normalize the current date for comparison
    final today = _normalizeDate(currentTime);
    final isSelectedDateToday = _normalizeDate(selectedDate) == today;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Attendance Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow('Date', DateFormat('dd MMM yyyy').format(selectedDate)),
                    const SizedBox(height: 8),

                    if (!attendanceRecord.isEmpty) ...[
                      if (!isSelectedDateToday)
                        _buildDetailRow('Status', _getStatusDisplay(attendanceRecord.status, attendanceRecord.isLate)),
                      const SizedBox(height: 8),

                      _buildDetailRow('Punch In', _formatTime(attendanceRecord.punchIn.toString())),
                      const SizedBox(height: 8),

                      _buildDetailRow('Punch Out', _formatTime(attendanceRecord.punchOut.toString())),
                      const SizedBox(height: 8),

                      if (attendanceRecord.workHours != null && attendanceRecord.workHours! > 0 && widget.managerLevel > 0) ...[
                        _buildDetailRow('Work Hours', '${attendanceRecord.workHours?.truncate()} hours ${((attendanceRecord.workHours! % 1) * 60).round()} minutes'),
                        const SizedBox(height: 8),
                      ],

                      if (attendanceRecord.isLate == true && widget.managerLevel > 0) ...[
                        _buildDetailRow('Late', 'Yes (${attendanceRecord.lateMinutes} minutes)'),
                        const SizedBox(height: 8),
                      ],

                      if (attendanceRecord.isEarlyDeparture == true && widget.managerLevel > 0) ...[
                        _buildDetailRow('Early Departure', 'Yes (${attendanceRecord.earlyDepartureMinutes} minutes)'),
                        const SizedBox(height: 8),
                      ],

                      if (attendanceRecord.punchInLocation != null && attendanceRecord.punchInLocation!.isNotEmpty && widget.managerLevel > 0) ...[
                        _buildClickableLocationRow('Punch In Location', attendanceRecord.punchInLocation!),
                        const SizedBox(height: 8),
                      ],

                      if (attendanceRecord.punchOutLocation != null && attendanceRecord.punchOutLocation!.isNotEmpty && widget.managerLevel > 0) ...[
                        _buildClickableLocationRow('Punch Out Location', attendanceRecord.punchOutLocation!),
                        const SizedBox(height: 8),
                      ],

                      if (attendanceRecord.isRegularized == true) ...[
                        _buildDetailRow('Regularized', 'Yes'),
                        const SizedBox(height: 8),
                      ],

                      if (attendanceRecord.isWeekend == true && widget.managerLevel > 0) ...[
                        _buildDetailRow('Weekend', 'Yes'),
                        const SizedBox(height: 8),
                      ],

                      if (attendanceRecord.isHoliday == true && widget.managerLevel > 0) ...[
                        _buildDetailRow('Holiday', 'Yes'),
                        const SizedBox(height: 8),
                      ],

                      if (attendanceRecord.remarks != null && attendanceRecord.remarks!.isNotEmpty && widget.managerLevel > 0) ...[
                        _buildDetailRow('Remarks', attendanceRecord.remarks!),
                        const SizedBox(height: 8),
                      ],

                      // Comment Section
                      if (canAccessMonthlyAttendance && !attendanceRecord.isEmpty)
                        _buildCommentSection(attendanceRecord, setState),
                    ] else ...[
                      // Check if it's a weekend, holiday, or leave day
                      if (widget.managerLevel > 0) _buildNoRecordInfo(selectedDate),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCommentSection(AttendanceRecord attendanceRecord, StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Comment',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            if (attendanceRecord.comment != null && attendanceRecord.comment!.isNotEmpty) ...[
              // Dropdown menu for Edit/Delete when comment exists
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showCommentDialog(attendanceRecord, setState);
                  } else if (value == 'delete') {
                    _showDeleteCommentDialog(attendanceRecord, setState);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert, size: 20),
              ),
            ] else ...[
              // Show Add Comment button when no comment exists
              TextButton.icon(
                onPressed: () => _showCommentDialog(attendanceRecord, setState),
                icon: const Icon(Icons.add_comment, size: 16),
                label: const Text('Add Comment', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        if (attendanceRecord.comment != null && attendanceRecord.comment!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              attendanceRecord.comment!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
        ] else ...[
          Text(
            'No comment added',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }


  void _showDeleteCommentDialog(AttendanceRecord attendanceRecord, StateSetter parentSetState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Delete Comment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to delete this comment?'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  attendanceRecord.comment!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${DateFormat('dd MMM yyyy').format(attendanceRecord.date)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _deleteComment(attendanceRecord.id, parentSetState);
                if (mounted){
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteComment(String attendanceId, StateSetter setState) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(width: 16),
              Text('Deleting comment...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Update in Supabase - set comment to null
      await supabase
          .from('attendance')
          .update({'comment': null})
          .eq('id', attendanceId);

      // Update the local attendanceRecords list
      final recordIndex = attendanceRecords.indexWhere((record) => record.id == attendanceId);
      if (recordIndex != -1) {
        final updatedRecord = AttendanceRecord(
          id: attendanceRecords[recordIndex].id,
          employeeId: attendanceRecords[recordIndex].employeeId,
          date: attendanceRecords[recordIndex].date,
          punchIn: attendanceRecords[recordIndex].punchIn,
          punchOut: attendanceRecords[recordIndex].punchOut,
          status: attendanceRecords[recordIndex].status,
          workHours: attendanceRecords[recordIndex].workHours,
          isLate: attendanceRecords[recordIndex].isLate,
          lateMinutes: attendanceRecords[recordIndex].lateMinutes,
          isEarlyDeparture: attendanceRecords[recordIndex].isEarlyDeparture,
          earlyDepartureMinutes: attendanceRecords[recordIndex].earlyDepartureMinutes,
          isEmpty: attendanceRecords[recordIndex].isEmpty,
          remarks: attendanceRecords[recordIndex].remarks,
          comment: null, // Set comment to null
          punchInLocation: attendanceRecords[recordIndex].punchInLocation,
          punchOutLocation: attendanceRecords[recordIndex].punchOutLocation,
          isWeekend: attendanceRecords[recordIndex].isWeekend,
          isHoliday: attendanceRecords[recordIndex].isHoliday,
          isRegularized: attendanceRecords[recordIndex].isRegularized,
          attendanceType: attendanceRecords[recordIndex].attendanceType,
        );

        attendanceRecords[recordIndex] = updatedRecord;

        // Update the dialog state
        setState(() {});

        // Update the main widget state
        if (mounted) {
          this.setState(() {});
        }
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (error) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting comment: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }




  void _showCommentDialog(AttendanceRecord attendanceRecord, StateSetter parentSetState) {
    final TextEditingController commentController = TextEditingController();

    // Pre-fill with existing comment if available
    if (attendanceRecord.comment != null && attendanceRecord.comment!.isNotEmpty) {
      commentController.text = attendanceRecord.comment!;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            attendanceRecord.comment != null && attendanceRecord.comment!.isNotEmpty
                ? 'Edit Comment'
                : 'Add Comment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: commentController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter your comment here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${DateFormat('dd MMM yyyy').format(attendanceRecord.date)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final comment = commentController.text.trim();
                if (comment.isNotEmpty) {
                  await _updateComment(attendanceRecord.id, comment, parentSetState);
                  if (mounted){
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a comment'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateComment(String attendanceId, String comment, StateSetter setState) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(width: 16),
              Text('Updating comment...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Update in Supabase
      await supabase
          .from('attendance')
          .update({'comment': comment})
          .eq('id', attendanceId);

      // Update the local attendanceRecords list
      final recordIndex = attendanceRecords.indexWhere((record) => record.id == attendanceId);
      if (recordIndex != -1) {
        final updatedRecord = AttendanceRecord(
          id: attendanceRecords[recordIndex].id,
          employeeId: attendanceRecords[recordIndex].employeeId,
          date: attendanceRecords[recordIndex].date,
          punchIn: attendanceRecords[recordIndex].punchIn,
          punchOut: attendanceRecords[recordIndex].punchOut,
          status: attendanceRecords[recordIndex].status,
          workHours: attendanceRecords[recordIndex].workHours,
          isLate: attendanceRecords[recordIndex].isLate,
          lateMinutes: attendanceRecords[recordIndex].lateMinutes,
          isEarlyDeparture: attendanceRecords[recordIndex].isEarlyDeparture,
          earlyDepartureMinutes: attendanceRecords[recordIndex].earlyDepartureMinutes,
          isEmpty: attendanceRecords[recordIndex].isEmpty,
          remarks: attendanceRecords[recordIndex].remarks,
          comment: comment, // Updated comment
          punchInLocation: attendanceRecords[recordIndex].punchInLocation,
          punchOutLocation: attendanceRecords[recordIndex].punchOutLocation,
          isWeekend: attendanceRecords[recordIndex].isWeekend,
          isHoliday: attendanceRecords[recordIndex].isHoliday,
          isRegularized: attendanceRecords[recordIndex].isRegularized,
          attendanceType: attendanceRecords[recordIndex].attendanceType,
        );

        attendanceRecords[recordIndex] = updatedRecord;

        // Update the dialog state
        setState(() {});

        // Update the main widget state
        if (mounted) {
          this.setState(() {});
        }
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (error) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating comment: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }




  Widget _buildClickableLocationRow(String label, String location) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _openLocationOnMap(location),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: Colors.blue.shade600,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

// Method to open location on map
  Future<void> _openLocationOnMap(String location) async {
    try {
      // Check if location contains coordinates (lat,lng format)
      if (location.contains(',')) {
        final coordinates = location.split(',');
        if (coordinates.length == 2) {
          final lat = double.tryParse(coordinates[0].trim());
          final lng = double.tryParse(coordinates[1].trim());

          if (lat != null && lng != null) {
            await _openCoordinatesOnMap(lat, lng);
            return;
          }
        }
      }

      // If not coordinates, treat as address and search
      await _openAddressOnMap(location);
    } catch (e) {
      _showLocationError();
    }
  }

// Open coordinates on map
  Future<void> _openCoordinatesOnMap(double lat, double lng) async {
    List<String> urls;

    if (Platform.isIOS) {
      // iOS: Prioritize Apple Maps
      urls = [
        'maps://maps.apple.com/?q=$lat,$lng', // Apple Maps (iOS native)
        'https://maps.apple.com/?q=$lat,$lng', // Apple Maps (web fallback)
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng', // Google Maps
      ];
    } else {
      // Android: Prioritize Google Maps
      urls = [
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng', // Google Maps
        'geo:$lat,$lng', // Generic geo URI (Android)
        'https://maps.apple.com/?q=$lat,$lng', // Apple Maps (web fallback)
      ];
    }

    for (String url in urls) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    _showLocationError();
  }

// Open address on map
  Future<void> _openAddressOnMap(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    List<String> urls;

    if (Platform.isIOS) {
      // iOS: Prioritize Apple Maps
      urls = [
        'maps://maps.apple.com/?q=$encodedAddress', // Apple Maps (iOS native)
        'https://maps.apple.com/?q=$encodedAddress', // Apple Maps (web fallback)
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress', // Google Maps
      ];
    } else {
      // Android: Prioritize Google Maps
      urls = [
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress', // Google Maps
        'geo:0,0?q=$encodedAddress', // Generic geo URI (Android)
        'https://maps.apple.com/?q=$encodedAddress', // Apple Maps (web fallback)
      ];
    }

    for (String url in urls) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    _showLocationError();
  }

// Show error when location cannot be opened
  void _showLocationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open location on map'),
        duration: Duration(seconds: 2),
      ),
    );
  }


  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoRecordInfo(DateTime selectedDate) {
    final normalizedDate = _normalizeDate(selectedDate);
    final status = attendanceMap[normalizedDate];

    String statusText = 'No Record';
    String description = 'No attendance record found for this date.';

    if (status != null) {
      switch (status) {
        case AttendanceStatus.weekend:
          statusText = 'Weekend';
          description = 'This is a weekend day.';
          break;
        case AttendanceStatus.holiday:
          statusText = 'Holiday';
          description = 'This is a holiday.';
          break;
        case AttendanceStatus.leave:
          statusText = 'On Leave';
          description = '${widget.employeeName} was on leave on this day.';
          break;
        case AttendanceStatus.absent:
          statusText = 'Absent';
          description = '${widget.employeeName} marked absent on this day.';
          break;
        default:
          break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Status', statusText),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min, // Ensures the Column takes minimum vertical space
            children: [
              const Text(
                'Attendance Summary',
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
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white70,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),

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
            if (widget.managerId.isEmpty)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                // Use Navigator.push to go to the AttendanceHistoryPage
                Navigator.push(
                  context, // 'context' is required here, make sure this code is within a Widget's build method or has access to a BuildContext.
                  MaterialPageRoute(
                    builder: (context) => AttendanceRegularizationPage(
                      employeeId: widget.employeeId,
                      employeeName: widget.employeeName,
                      managerId: widget.managerId,
                      managerLevel: widget.managerLevel,
                    ),
                  ),
                );
              },
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
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
              children: [
                const SizedBox(height: 8),
                _buildSummaryTab(),
                if (currentTime.isAfter(DateTime(2025, 7, 1)))_buildCalendarTab(),
                widget.managerId.isEmpty ? _buildOptionsTab() : _buildManagerOptionsTab(),
                const SizedBox(height: 16),
              ],
            ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedDay),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Absent',
                  summaryData['absent'].toString(),
                  Colors.red,
                  Icons.cancel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Half Day',
                  summaryData['halfDay'].toString(),
                  Colors.orange,
                  Icons.timelapse,
                ),
              ),

              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'On Leave',
                  summaryData['onLeave'].toString(),
                  Colors.blue,
                  Icons.beach_access,
                ),
              ),
            ],
          ),
          // const SizedBox(height: 12),
          // Row(
          //   children: [
          //     Expanded(
          //       child: _buildSummaryCard(
          //         'Half Day',
          //         summaryData['halfDay'].toString(),
          //         Colors.orange,
          //         Icons.access_time,
          //       ),
          //     ),
          //     const SizedBox(width: 12),
          //     Expanded(
          //       child: _buildSummaryCard(
          //         'On Leave',
          //         summaryData['onLeave'].toString(),
          //         Colors.blue,
          //         Icons.beach_access,
          //       ),
          //     ),
          //   ],
          // ),
          // const SizedBox(height: 16),
          // Container(
          //   padding: const EdgeInsets.all(12),
          //   decoration: BoxDecoration(
          //     color: Colors.grey[50],
          //     borderRadius: BorderRadius.circular(8),
          //   ),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //     children: [
          //       Text(
          //         'Total Working Days',
          //         style: TextStyle(
          //           fontSize: 14,
          //           fontWeight: FontWeight.w500,
          //           color: Colors.grey[700],
          //         ),
          //       ),
          //       Text(
          //         summaryData['totalWorkingDays'].toString(),
          //         style: TextStyle(
          //           fontSize: 16,
          //           fontWeight: FontWeight.bold,
          //           color: Colors.grey[800],
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Calendar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          TableCalendar<AttendanceStatus>(
            firstDay: DateTime(2025, 7, 1), // Previous month
            lastDay: DateTime(currentTime.year, currentTime.month + 3, 0), // Next 2 months
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            availableGestures: AvailableGestures.horizontalSwipe,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(color: Colors.grey[600]),
              holidayTextStyle: const TextStyle(color: Colors.red),
            ),
            eventLoader: (day) {
              final normalizedDay = _normalizeDate(day);
              final status = attendanceMap[normalizedDay];
              return status != null ? [status] : [];
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;

                // Find the actual attendance record for this day
                final normalizedDay = _normalizeDate(day);
                final record = attendanceRecords.firstWhere(
                      (r) => _normalizeDate(r.date) == normalizedDay,
                  orElse: () => AttendanceRecord.empty(normalizedDay),
                );

                final status = events.first;
                Color markerColor;

                // Priority 1: Check if regularized - show light green
                if (record.isRegularized) {
                  markerColor = Colors.greenAccent;
                } else {
                  // Priority 2: Use normal status colors
                  switch (status) {
                    case AttendanceStatus.present:
                      markerColor = Colors.green;
                      break;
                    case AttendanceStatus.absent:
                      markerColor = Colors.red;
                      break;
                    case AttendanceStatus.halfDay:
                      markerColor = Colors.orange;
                      break;
                    case AttendanceStatus.leave:
                      markerColor = Colors.blue;
                      break;
                    case AttendanceStatus.weekend:
                      markerColor = Colors.blueGrey;
                      break;
                    case AttendanceStatus.holiday:
                      markerColor = Colors.purple;
                      break;
                  }
                }

                return Positioned(
                  top: 1,  // Changed from bottom: 4
                  child: Container(
                    width: 10,  // Increased from 6
                    height: 10, // Increased from 6
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),

            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onDayLongPressed: (selectedDay, focusedDay) {
              // This is the key addition - handle long press
              _showAttendanceDetails(selectedDay);
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              _loadDataForMonth(focusedDay);
            },
          ),
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
    );
  }


  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLegendItem('Present', Colors.green),
        _buildLegendItem('Absent', Colors.red),
        _buildLegendItem('Half Day', Colors.orange),
        _buildLegendItem('Leave', Colors.blue),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsTab() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   'Quick Actions',
          //   style: TextStyle(
          //     fontSize: 18,
          //     fontWeight: FontWeight.bold,
          //     color: Colors.grey[800],
          //   ),
          // ),
          // const SizedBox(height: 16),
          _buildOptionCard(
            'Regularize Attendance',
            'Request to regularize absent/half-day records',
            Icons.edit_calendar,
            Colors.green,
                () async => await _showRegularizeDialog(),
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            'Leave Regularization',
            'Request to regularize absent/half-day records as leave',
            Icons.beach_access,
            Colors.blue,
                () => _showLeaveRegularizeDialog(),
          ),
          // const SizedBox(height: 12),
          // _buildOptionCard(
          //   'Export Report',
          //   'Download attendance report',
          //   Icons.download,
          //   Colors.orange,
          //       () => _exportReport(),
          // ),
        ],
      ),
    );
  }

  Widget _buildManagerOptionsTab() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   'Quick Actions',
          //   style: TextStyle(
          //     fontSize: 18,
          //     fontWeight: FontWeight.bold,
          //     color: Colors.grey[800],
          //   ),
          // ),
          // const SizedBox(height: 16),
          _buildOptionCard(
            'Regularizations',
            'View regularization request & history',
            Icons.edit_calendar,
            Colors.green,
                () => // Use Navigator.push to go to the AttendanceHistoryPage
                Navigator.push(
                  context, // 'context' is required here, make sure this code is within a Widget's build method or has access to a BuildContext.
                  MaterialPageRoute(
                    builder: (context) => AttendanceRegularizationPage(
                      employeeId: widget.employeeId,
                      employeeName: widget.employeeName,
                      managerId: widget.managerId,
                      managerLevel: widget.managerLevel,
                    ),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            'Leave Requests',
            'View leave request & history',
            Icons.beach_access,
            Colors.blue,
                () => Navigator.push(
                  context, // 'context' is required here, make sure this code is within a Widget's build method or has access to a BuildContext.
                  MaterialPageRoute(
                    builder: (context) => LeaveHistoryPage(
                      employeeId: widget.employeeId,
                      employeeName: widget.employeeName,
                      managerId: widget.managerId,
                      managerLevel: widget.managerLevel,
                    ),
                  ),
                ),
          ),
          // const SizedBox(height: 12),
          // _buildOptionCard(
          //   'Export Report',
          //   'Download attendance report',
          //   Icons.download,
          //   Colors.orange,
          //       () => _exportReport(),
          // ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }


  bool _canApplyRegularization(DateTime selectedDate, DateTime currentTime) {
    final today = DateTime(currentTime.year, currentTime.month, currentTime.day);
    final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    final isSameMonthBeforeToday = selected.month == currentTime.month &&
        selected.year == currentTime.year &&
        selected.isBefore(today);

    final isLastMonthAndTodayIsEarly = selected.month == (currentTime.month - 1) &&
        selected.year == currentTime.year &&
        currentTime.day <= 2;

    return isSameMonthBeforeToday || isLastMonthAndTodayIsEarly;
  }

  Future<void> _showLeaveRegularizeDialog() async {
    // Step 1: Check eligibility based on attendance status
    final selectedDateStatus = attendanceMap[_normalizeDate(_selectedDay)];

    // Check if the selected date is eligible for regularization
    if (selectedDateStatus != AttendanceStatus.absent &&
        selectedDateStatus != AttendanceStatus.halfDay) {

      // Show error message if date is not eligible
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Leave regularization is only allowed for absent or half-day records. '
                  'Please select a date with absent or half-day status.'
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // 2. Get server-based current time
    // final currentTime = await AppState().getCurrentTime();

    // 3. Validate date eligibility
    if (!_canApplyRegularization(_selectedDay, currentTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Regularization period ended for this date.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _leaveRegularizeDialog(),
    );
  }

  Widget _leaveRegularizeDialog() {
    DateTime? selectedDate = _selectedDay;
    int? selectedLeaveTypeId;
    String description = '';
    bool isLoadingLeaveTypes = false;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        // Load leave types if empty
        if (leaveTypes.isEmpty && !isLoadingLeaveTypes) {
          isLoadingLeaveTypes = true;
          _loadAvailableLeaveTypes().then((_) {
            if (mounted) {
              setDialogState(() {
                isLoadingLeaveTypes = false;
              });
            }
          }).catchError((error) {
            if (mounted) {
              setDialogState(() {
                isLoadingLeaveTypes = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load leave types: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
        }

        return AlertDialog(
          title: const Text('Leave Regularization'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show current selected date status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Selected: ${DateFormat('dd MMM, yyyy').format(selectedDate)} - ${_getStatusText(attendanceMap[_normalizeDate(selectedDate)])}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Leave Type Selection
                const Text(
                  'Select Leave Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Leave Type Cards
                if (isLoadingLeaveTypes)
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Loading leave types...'),
                      ],
                    ),
                  )
                else if (leaveTypes.where((leaveType) {
                  final leaveTypeId = leaveType['id'] as int;
                  final balance = leaveBalancesMap[leaveTypeId];
                  final availableDays = balance?['available_days'] ?? 0.0;
                  return availableDays >= 1.0;
                }).isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange.shade600),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'No leave types with sufficient balance available for regularization',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (leaveTypes.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange.shade600),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'No leave types available for regularization',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...leaveTypes.where((leaveType) {
                      final leaveTypeId = leaveType['id'] as int;
                      final balance = leaveBalancesMap[leaveTypeId];
                      final availableDays = balance?['available_days'] ?? 0.0;
                      return availableDays >= 1.0; // Only show leave types with at least 1 day
                    }).map((leaveType) {
                      final leaveTypeId = leaveType['id'] as int;
                      final balance = leaveBalancesMap[leaveTypeId];

                      return _buildLeaveTypeCard(
                        leaveType,
                        balance,
                        selectedLeaveTypeId,
                            (leaveTypeId) => setDialogState(() => selectedLeaveTypeId = leaveTypeId),
                      );
                    }),

                const SizedBox(height: 16),

                // Description TextField
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Reason for Leave Regularization',
                    border: const OutlineInputBorder(),
                    hintText: 'Provide reason for leave regularization...',
                    prefixIcon: const Icon(Icons.description, color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    description = value;
                    setDialogState(() {}); // Trigger rebuild to update button state
                  },
                ),

                const SizedBox(height: 8),

                // Info text
                Text(
                  'Note: This will create a leave application for the selected date and deduct from your leave balance.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (selectedLeaveTypeId != null && description.trim().isNotEmpty && !isSubmitting && !isLoadingLeaveTypes)
                  ? () => _submitLeaveRegularization(selectedDate, selectedLeaveTypeId!, description.trim(), setDialogState)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text('Submit Leave Application'),
            ),
          ],
        );
      },
    );
  }

// Helper method to build leave type cards
  Widget _buildLeaveTypeCard(
      Map<String, dynamic> leaveType,
      Map<String, dynamic>? balance,
      int? selectedLeaveTypeId,
      Function(int) onSelect,
      ) {
    final leaveTypeId = leaveType['id'] as int;
    final isSelected = selectedLeaveTypeId == leaveTypeId;
    final leaveName = leaveType['leave_name'] ?? 'Unknown';
    final leaveCode = leaveType['leave_code'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onSelect(leaveTypeId),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.green : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? Colors.green.withOpacity(0.1) : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.beach_access,
                  color: isSelected ? Colors.white : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leaveName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.green : Colors.grey[800],
                      ),
                    ),
                    if (leaveCode.isNotEmpty)
                      Text(
                        '($leaveCode)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

// Submit leave regularization
  Future<void> _submitLeaveRegularization(
      DateTime? selectedDate,
      int leaveTypeId,
      String description,
      StateSetter setDialogState,
      ) async {
    if (selectedDate == null) return;

    setDialogState(() => isSubmitting = true);

    try {

      final currentTime = await AppState().getCurrentTime();
      final allowedStartTime = DateTime(currentTime.year, currentTime.month, currentTime.day, 6);  // 6 AM
      final allowedEndTime = DateTime(currentTime.year, currentTime.month, currentTime.day, 23);   // 11 PM
      final calendarYear = currentTime.year;

      if (currentTime.isBefore(allowedStartTime) || currentTime.isAfter(allowedEndTime)) {
        Navigator.pop(context);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.access_time, color: Colors.red),
                SizedBox(width: 8),
                Text('Outside Allowed Time'),
              ],
            ),
            content: const Text('You can submit a regularization request only between 6:00 AM and 11:00 PM.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Check for existing regularization request
      List<dynamic> existingRegularizations = [];
      final dateString = selectedDate.toIso8601String().split('T')[0];

      existingRegularizations = await supabase
          .from('attendance_regularizations')
          .select('id, status, regularization_type, created_at, requested_punch_in')
          .eq('employee_id', widget.employeeId)
          .filter('status', 'in', ['pending', 'approved'])
          .gte('requested_punch_in', '${dateString}T00:00:00')
          .lt('requested_punch_in', '${dateString}T23:59:59');

      // If there's an existing pending or approved regularization, show error
      if (existingRegularizations.isNotEmpty) {
        final existingRequest = existingRegularizations.first;
        final createdAt = DateTime.parse(existingRequest['created_at']);
        final formattedDate = DateFormat('MMM dd, yyyy hh:mm a').format(createdAt);

        Navigator.pop(context);

        // Show detailed error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text('Duplicate Request'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A regularization request already exists for this date.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Existing Request Details:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}'),
                      Text('Type: ${_getRegularizationTypeDisplay(existingRequest['regularization_type'])}'),
                      Text('Status: ${existingRequest['status'].toString().toUpperCase()}'),
                      Text('Applied: $formattedDate'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please wait for the current request to be processed or contact your manager.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final response = await supabase.rpc('submit_leave_application', params: {
        'p_employee_id': widget.employeeId,
        'p_leave_type_id': leaveTypeId,
        'p_start_date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'p_end_date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'p_total_days': 1,
        'p_reason': 'Leave Regularization: $description',
        'p_applied_by': supabase.auth.currentUser!.id,
        'p_approval_levels': AppState().employeeProfile['approval_levels'] ?? 2, // Default approval levels for regularization
        'p_calendar_year': calendarYear,
        'p_current_time': currentTime.toIso8601String(),
      });

      if (response['success'] as bool) {
        // Update the attendance status in local map
        // setState(() {
        //   attendanceMap[_normalizeDate(selectedDate)] = AttendanceStatus.leave;
        // });

        // Refresh leave balances to reflect the new application
        await _loadAvailableLeaveTypes();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave regularization application submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Close dialog
        Navigator.pop(context);
      } else {
        // Show error message from RPC response
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] as String),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        // Close dialog
        Navigator.pop(context);
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit leave regularization: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setDialogState(() => isSubmitting = false);
    }
  }


  Future<void> _showRegularizeDialog() async {
    // Step 1: Check eligibility based on attendance status
    final selectedDateStatus = attendanceMap[_normalizeDate(_selectedDay)];

    // Check if the selected date is eligible for regularization
    if (selectedDateStatus != AttendanceStatus.absent &&
        selectedDateStatus != AttendanceStatus.halfDay) {

      // Show error message if date is not eligible
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Regularization is only allowed for absent or half-day records. '
                  'Please select a date with absent or half-day status.'
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // 2. Get server-based current time
    // final currentTime = await AppState().getCurrentTime();

    // 3. Validate date eligibility
    if (!_canApplyRegularization(_selectedDay, currentTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Regularization period ended for this date.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _regularizeDialog(),
    );
  }

// Add this as a private method inside _AttendanceSummaryPageState class
  Widget _regularizeDialog() {
    DateTime? selectedDate = _selectedDay; // Start with the selected date from calendar
    String? selectedRegularizationType;
    String description = '';

    final List<Map<String, dynamic>> regularizationOptions = [
      {
        'value': 'late_arrival',
        'title': 'Late Arrival',
        'icon': Icons.schedule,
        'color': Colors.orange,
      },
      {
        'value': 'missed_swipe',
        'title': 'Missed Swipe',
        'icon': Icons.touch_app,
        'color': Colors.blue,
      },
      {
        'value': 'outdoor_client_visit',
        'title': 'Outdoor/Client Visit',
        'icon': Icons.business,
        'color': Colors.green,
      },
      {
        'value': 'other',
        'title': 'Other',
        'icon': Icons.more_horiz,
        'color': Colors.grey,
      },
    ];

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Regularize Attendance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show current selected date status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Selected: ${DateFormat('dd MMM, yyyy').format(selectedDate)} - ${_getStatusText(attendanceMap[_normalizeDate(selectedDate)])}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Regularization Type Selection
                const Text(
                  'Regularization Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Option Cards
                ...regularizationOptions.map((option) => _buildRegularizeOptionCard(
                    option,
                    selectedRegularizationType,
                        (value) => setDialogState(() => selectedRegularizationType = value)
                )),

                const SizedBox(height: 16),

                // Description TextField
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    border: const OutlineInputBorder(),
                    hintText: 'Provide additional details...',
                    prefixIcon: const Icon(Icons.description, color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                  maxLines: 3,
                  maxLength: 100,
                  onChanged: (value) => description = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (selectedRegularizationType != null && !isSubmitting)
                  ? () => _submitRegularization(selectedDate, selectedRegularizationType!, description.trim(), setDialogState)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

// Add this helper method for option cards
  Widget _buildRegularizeOptionCard(Map<String, dynamic> option, String? selectedType, Function(String) onSelect) {
    final isSelected = selectedType == option['value'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onSelect(option['value']),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? option['color'] : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? option['color'].withOpacity(0.1) : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? option['color']
                      : option['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  option['icon'],
                  color: isSelected ? Colors.white : option['color'],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option['title'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? option['color'] : Colors.grey[800],
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: option['color'],
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get status text (if not already exists)
  String _getStatusText(AttendanceStatus? status) {
    switch (status) {
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.leave:
        return 'On Leave';
      case AttendanceStatus.weekend:
        return 'Weekend';
      case AttendanceStatus.holiday:
        return 'Holiday';
      default:
        return 'Unknown';
    }
  }

  String _getStatusDisplay(String? status, bool isLate) {
    switch (status) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'half-day':
        return 'Half Day';
      case 'leave':
        return 'On Leave';
      case 'comp-off':
        return 'Comp Off';
      case 'comp-w':
        return 'Compensatory Work';
      case 'weekend':
        return 'Weekend';
      case 'holiday':
        return 'Holiday';
      default:
        return status ?? 'Unknown';
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('h:mm a').format(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  // Updated method to handle regularization submission with duplicate check
  Future<void> _submitRegularization(DateTime selectedDate, String regularizationType, String description, StateSetter setDialogState) async {
    setDialogState(() => isSubmitting = true);

    final currentTime = await AppState().getCurrentTime();
    final allowedStartTime = DateTime(currentTime.year, currentTime.month, currentTime.day, 6);  // 6 AM
    final allowedEndTime = DateTime(currentTime.year, currentTime.month, currentTime.day, 23);   // 11 PM

    if (currentTime.isBefore(allowedStartTime) || currentTime.isAfter(allowedEndTime)) {
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.access_time, color: Colors.red),
              SizedBox(width: 8),
              Text('Outside Allowed Time'),
            ],
          ),
          content: const Text('You can submit a regularization request only between 6:00 AM and 11:00 PM.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      // Create requested punch in/out times using the selected date and work schedule
      final workStartTime = workSchedule?['start_time'] ?? '10:00:00';
      final workEndTime = workSchedule?['end_time'] ?? '19:00:00';

      // Parse time strings and create DateTime objects
      final startTimeParts = workStartTime.split(':');
      final endTimeParts = workEndTime.split(':');

      final requestedPunchIn = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        int.parse(startTimeParts[0]),
        int.parse(startTimeParts[1]),
        0,
      );

      final requestedPunchOut = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        int.parse(endTimeParts[0]),
        int.parse(endTimeParts[1]),
        0,
      );

      // Check if attendance record exists for this date
      final existingAttendance = await supabase
          .from('attendance')
          .select('id, punch_in, punch_out')
          .eq('employee_id', widget.employeeId)
          .eq('date', selectedDate.toIso8601String().split('T')[0])
          .maybeSingle();

      // Check for existing regularization request
      List<dynamic> existingRegularizations = [];

      if (existingAttendance != null && existingAttendance['id'] != null) {
        // Check by attendance_id if attendance record exists
        existingRegularizations = await supabase
            .from('attendance_regularizations')
            .select('id, status, regularization_type, created_at')
            .eq('attendance_id', existingAttendance['id'])
            .eq('employee_id', widget.employeeId)
            .filter('status', 'in', ['pending', 'approved']); // Only check for active requests
      } else {
        // If no attendance record exists, check by employee_id and date
        // We need to check requests for the same date even if no attendance record exists
        final dateString = selectedDate.toIso8601String().split('T')[0];

        existingRegularizations = await supabase
            .from('attendance_regularizations')
            .select('id, status, regularization_type, created_at, requested_punch_in')
            .eq('employee_id', widget.employeeId)
            .filter('status', 'in', ['pending', 'approved'])
            .gte('requested_punch_in', '${dateString}T00:00:00')
            .lt('requested_punch_in', '${dateString}T23:59:59');
      }

      // If there's an existing pending or approved regularization, show error
      if (existingRegularizations.isNotEmpty) {
        final existingRequest = existingRegularizations.first;
        final createdAt = DateTime.parse(existingRequest['created_at']);
        final formattedDate = DateFormat('MMM dd, yyyy hh:mm a').format(createdAt);

        Navigator.pop(context);

        // Show detailed error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text('Duplicate Request'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A regularization request already exists for this date.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Existing Request Details:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}'),
                      Text('Type: ${_getRegularizationTypeDisplay(existingRequest['regularization_type'])}'),
                      Text('Status: ${existingRequest['status'].toString().toUpperCase()}'),
                      Text('Applied: $formattedDate'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please wait for the current request to be processed or contact your manager.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Create regularization request if no duplicate exists
      final regularizationData = {
        'employee_id': widget.employeeId,
        'attendance_id': existingAttendance?['id'],
        'regularization_type': regularizationType,
        'original_punch_in': existingAttendance?['punch_in'],
        'original_punch_out': existingAttendance?['punch_out'],
        'requested_punch_in': requestedPunchIn.toIso8601String(),
        'requested_punch_out': requestedPunchOut.toIso8601String(),
        // 'reason': description,
        'applied_by': AppState().userId,
        'created_at': currentTime.toIso8601String(),
        'status': 'pending',
        'approval_levels': AppState().employeeProfile['approval_levels'] ?? 2,
        'level_1_status': 'pending',
      };

      // Only add 'reason' if it's not empty or null
      if (description.trim().isNotEmpty) {
        regularizationData['reason'] = description;
      }

      await supabase.from('attendance_regularizations').insert(regularizationData);

      Navigator.pop(context);
      _loadData(); // Refresh data after regularization

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Regularization request submitted successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

    } catch (e) {
      Navigator.pop(context);
      print('Error submitting regularization: $e'); // For debugging

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Error submitting request: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally{
      setDialogState(() => isSubmitting = false);
    }
  }

// Helper method to display regularization type in a user-friendly format
  String _getRegularizationTypeDisplay(String type) {
    switch (type) {
      case 'late_arrival':
        return 'Late Arrival';
      case 'missed_swipe':
        return 'Missed Swipe';
      case 'outdoor_client_visit':
        return 'Outdoor/Client Visit';
      case 'other':
        return 'Other';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }


  void _navigateToLeaveApplication() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaveApplicationPage(userProfile: AppState().employeeProfile),
        // builder: (context) => const LeaveApplicationPage(),
      ),
    ).then((_) => _loadData()); // Refresh data when coming back
  }

  void _exportReport() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate report data
      final reportData = await _generateReportData();

      // Close loading dialog
      Navigator.pop(context);

      // Show export options
      _showExportOptions(reportData);

    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _generateReportData() async {
    final startOfMonth = DateTime(currentTime.year, currentTime.month, 1);
    final endOfMonth = DateTime(currentTime.year, currentTime.month + 1, 0);

    // Get employee details
    final employeeResponse = await supabase
        .from('profiles')
        .select('full_name, employee_code, email')
        .eq('id', widget.employeeId)
        .single();

    return {
      'employee': employeeResponse,
      'period': {
        'from': DateFormat('yyyy-MM-dd').format(startOfMonth),
        'to': DateFormat('yyyy-MM-dd').format(endOfMonth),
        'month': DateFormat('MMMM yyyy').format(currentTime),
      },
      'summary': summaryData,
      'attendance_records': attendanceRecords.map((record) => {
        'date': DateFormat('yyyy-MM-dd').format(record.date),
        'punch_in': record.punchIn?.toString(),
        'punch_out': record.punchOut?.toString(),
        'status': record.status,
        'work_hours': record.workHours,
        'is_late': record.isLate,
        'late_minutes': record.lateMinutes,
      }).toList(),
    };
  }

  void _showExportOptions(Map<String, dynamic> reportData) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Export Report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text('Email Report'),
              subtitle: const Text('Send report to your email'),
              onTap: () {
                Navigator.pop(context);
                _emailReport(reportData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text('Share Report'),
              subtitle: const Text('Share via other apps'),
              onTap: () {
                Navigator.pop(context);
                _shareReport(reportData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.orange),
              title: const Text('Download CSV'),
              subtitle: const Text('Download as CSV file'),
              onTap: () {
                Navigator.pop(context);
                _downloadCSV(reportData);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _emailReport(Map<String, dynamic> reportData) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email functionality will be implemented'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _shareReport(Map<String, dynamic> reportData) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality will be implemented'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _downloadCSV(Map<String, dynamic> reportData) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV download functionality will be implemented'),
        backgroundColor: Colors.orange,
      ),
    );
  }



}

// Data Models
class AttendanceRecord {
  final String id;
  final String employeeId;
  final DateTime date;
  final DateTime? punchIn;
  final DateTime? punchOut;
  final String status;
  final double? workHours;
  final bool isLate;
  final int lateMinutes;
  final bool isEarlyDeparture;
  final int earlyDepartureMinutes;
  final bool isEmpty;

  // Additional fields from your database schema
  final String? remarks;
  final String? comment;
  final String? punchInLocation;
  final String? punchOutLocation;
  final bool isWeekend;
  final bool isHoliday;
  final bool isRegularized;
  final String? attendanceType;

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    this.punchIn,
    this.punchOut,
    required this.status,
    this.workHours,
    required this.isLate,
    required this.lateMinutes,
    required this.isEarlyDeparture,
    required this.earlyDepartureMinutes,
    this.isEmpty = false,
    this.remarks,
    this.comment,
    this.punchInLocation,
    this.punchOutLocation,
    required this.isWeekend,
    required this.isHoliday,
    required this.isRegularized,
    this.attendanceType,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'].toString(),
      employeeId: json['employee_id'],
      date: DateTime.parse(json['date']),
      punchIn: json['punch_in'] != null ? DateTime.parse(json['punch_in']) : null,
      punchOut: json['punch_out'] != null ? DateTime.parse(json['punch_out']) : null,
      status: json['status'] ?? 'absent',
      workHours: json['work_hours'] != null ? (json['work_hours'] as num).toDouble() : null,
      isLate: json['is_late'] ?? false,
      lateMinutes: json['late_minutes'] ?? 0,
      isEarlyDeparture: json['is_early_departure'] ?? false,
      earlyDepartureMinutes: json['early_departure_minutes'] ?? 0,
      remarks: json['remarks'],
      comment: json['comment'],
      punchInLocation: json['punch_in_location'],
      punchOutLocation: json['punch_out_location'],
      isWeekend: json['is_weekend'] ?? false,
      isHoliday: json['is_holiday'] ?? false,
      isRegularized: json['is_regularized'] ?? false,
      attendanceType: json['attendance_type'],
    );
  }

  factory AttendanceRecord.empty(DateTime date) {
    return AttendanceRecord(
      id: '',
      employeeId: AppState().userId,
      date: date,
      status: 'absent',
      workHours: 0,
      isLate: false,
      lateMinutes: 0,
      isEarlyDeparture: false,
      earlyDepartureMinutes: 0,
      isEmpty: true,
      remarks: null,
      comment: null,
      punchInLocation: null,
      punchOutLocation: null,
      isWeekend: false,
      isHoliday: false,
      isRegularized: false,
      attendanceType: null,
    );
  }
}
class Holiday {
  final int id;
  final DateTime holidayDate;
  final String title;
  final String description;
  final String holidayType;
  final bool isNational;
  final bool isOptional;

  Holiday({
    required this.id,
    required this.holidayDate,
    required this.title,
    required this.description,
    required this.holidayType,
    required this.isNational,
    required this.isOptional,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      id: json['id'],
      holidayDate: DateTime.parse(json['holiday_date']),
      title: json['title'],
      description: json['description'] ?? '',
      holidayType: json['holiday_type'] ?? 'national',
      isNational: json['is_national'] ?? false,
      isOptional: json['is_optional'] ?? false,
    );
  }
}

enum AttendanceStatus {
  present,
  absent,
  halfDay,
  leave,
  weekend,
  holiday,
}
