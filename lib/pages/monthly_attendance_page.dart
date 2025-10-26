import 'dart:io';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_state.dart';

class MonthlyAttendancePage extends StatefulWidget {
  const MonthlyAttendancePage({super.key});

  @override
  State<MonthlyAttendancePage> createState() => _MonthlyAttendancePageState();
}

class _MonthlyAttendancePageState extends State<MonthlyAttendancePage> {
  final supabase = Supabase.instance.client;
  DateTime _selectedMonth = DateTime.now();
  DateTime currentTime = DateTime.now();
  List<Map<String, dynamic>> _attendanceData = [];
  bool _loading = false;
  int _daysInMonth = 0;
  List<String> _dayHeaders = [];
  final Map<String, Map<String, dynamic>> _departmentCache = {};
  final Map<String, Map<String, dynamic>> _employeeCache = {}; // Cache for all employees

  @override
  void initState() {
    super.initState();
    _fetchMonthlyAttendance();
  }

  Future<void> _fetchMonthlyAttendance() async {
    setState(() => _loading = true);

    try {
      // Calculate month range - only up to previous date
      currentTime = await AppState().getCurrentTime();
      final now = currentTime;
      final yesterday = now.subtract(const Duration(days: 1));
      final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);

      // End date is either last day of selected month or yesterday, whichever is earlier
      final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      final actualEndDate = yesterday.isBefore(monthEnd) ? yesterday : monthEnd;

      _daysInMonth = monthEnd.day;
      _dayHeaders = List.generate(_daysInMonth, (i) {
        final day = i + 1;
        final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
        final weekday = DateFormat('E').format(date); // Mon, Tue, Wed, etc.
        return '$day\n$weekday';
      });

      // Fetch ALL employees (both active and inactive) to ensure we have manager data
      final allEmployeesResponse = await supabase
          .from('profiles')
          .select('id, full_name, employee_code, department, is_active');

      // Convert to list of maps and cache all employees
      final allEmployees = List<Map<String, dynamic>>.from(allEmployeesResponse);
      _employeeCache.clear();
      for (final emp in allEmployees) {
        _employeeCache[emp['id'].toString()] = emp;
      }

      // Filter active employees for attendance display
      final activeEmployees = allEmployees.where((emp) => emp['is_active'] == true).toList();

      // Extract unique department IDs from active employees
      final departmentIds = <int>{};
      for (final emp in activeEmployees) {
        if (emp['department'] != null) {
          departmentIds.add(emp['department'] as int);
        }
      }

      // Pre-fetch departments
      await _prefetchDepartments(departmentIds.toList());

      // Fetch attendance for the month - only up to previous date
      final attendanceResponse = await supabase
          .from('attendance')
          .select('employee_id, date, status')
          .gte('date', monthStart.toIso8601String())
          .lte('date', actualEndDate.toIso8601String());

      // Process all data
      _processData(
        employees: activeEmployees,
        attendance: List<Map<String, dynamic>>.from(attendanceResponse),
        monthStart: monthStart,
        actualEndDate: actualEndDate,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _prefetchDepartments(List<int> departmentIds) async {
    if (departmentIds.isEmpty) return;

    final response = await supabase
        .from('departments')
        .select('id, name, manager_id, parent_id')
        .inFilter('id', departmentIds);

    for (final dept in response) {
      _departmentCache[dept['id'].toString()] = {
        'id': dept['id'],
        'name': dept['name'] ?? 'N/A',
        'manager_id': dept['manager_id']?.toString(),
        'parent_id': dept['parent_id'],
      };
    }

    // Also fetch parent departments if they exist
    final parentIds = _departmentCache.values
        .where((dept) => dept['parent_id'] != null)
        .map((dept) => dept['parent_id'] as int)
        .where((id) => !_departmentCache.containsKey(id.toString()))
        .toList();

    if (parentIds.isNotEmpty) {
      await _prefetchParentDepartments(parentIds);
    }
  }

  Future<void> _prefetchParentDepartments(List<int> parentIds) async {
    if (parentIds.isEmpty) return;

    final response = await supabase
        .from('departments')
        .select('id, name, manager_id, parent_id')
        .inFilter('id', parentIds);

    for (final dept in response) {
      _departmentCache[dept['id'].toString()] = {
        'id': dept['id'],
        'name': dept['name'] ?? 'N/A',
        'manager_id': dept['manager_id']?.toString(),
        'parent_id': dept['parent_id'],
      };
    }

    // Recursively fetch more parent departments if needed (up to 5 levels)
    final nextParentIds = _departmentCache.values
        .where((dept) => dept['parent_id'] != null)
        .map((dept) => dept['parent_id'] as int)
        .where((id) => !_departmentCache.containsKey(id.toString()))
        .toList();

    if (nextParentIds.isNotEmpty && _departmentCache.length < 100) { // Safety limit
      await _prefetchParentDepartments(nextParentIds);
    }
  }

  // Helper method to get manager name from cached employee data
  String _getManagerName(String? managerId) {
    if (managerId == null) return 'N/A';
    final manager = _employeeCache[managerId];
    return manager?['full_name'] ?? 'N/A';
  }

  void _processData({
    required List<Map<String, dynamic>> employees,
    required List<Map<String, dynamic>> attendance,
    required DateTime monthStart,
    required DateTime actualEndDate,
  }) {
    final Map<String, Map<String, dynamic>> employeeMap = {};

    // Initialize all employees with empty data
    for (final employee in employees) {
      final empId = employee['id'].toString();
      final deptId = employee['department'] as int?;

      // Get department name
      final deptName = deptId != null && _departmentCache.containsKey(deptId.toString())
          ? _departmentCache[deptId.toString()]!['name'] as String
          : 'N/A';

      // Find reporting manager using hierarchy logic
      final reportingManagerId = _findReportingManager(empId, deptId);
      final reportingManagerName = _getManagerName(reportingManagerId);

      employeeMap[empId] = {
        'id': empId,
        'full_name': employee['full_name'] ?? 'Unknown',
        'employee_code': employee['employee_code'] ?? '',
        'department': deptName,
        'reporting_manager': reportingManagerName,
        'total_present': 0,
        'total_absent': 0,
        'total_leave': 0,
        'total_half_day': 0,
        'total_weekend': 0,
        'total_comp_w': 0,
        'total_comp_off': 0,
        'days': { for (var day in List.generate(_daysInMonth, (i) => i + 1)) day : '' },
      };
    }

    // Process attendance records
    for (final record in attendance) {
      final empId = record['employee_id']?.toString();
      if (empId == null || !employeeMap.containsKey(empId)) continue;

      final dateStr = record['date'] as String?;
      if (dateStr == null) continue;

      final date = DateTime.parse(dateStr);
      final day = date.day;
      final status = record['status'] as String? ?? 'absent';

      // Update day status - use status from table as-is
      employeeMap[empId]!['days'][day] = status;

      // Update totals
      _updateStatusTotals(employeeMap[empId]!, status);
    }

    // Handle days without attendance records - only for days up to actualEndDate
    for (final employee in employeeMap.values) {
      final days = employee['days'] as Map<int, String>;
      for (int day = 1; day <= _daysInMonth; day++) {
        final currentDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);

        // Only process days up to actualEndDate
        if (currentDate.isAfter(actualEndDate)) {
          // Leave future days empty
          continue;
        }

        if (days[day]!.isEmpty) {
          // No attendance record for this day - mark as absent
          days[day] = 'absent';
          employee['total_absent']++;
        }
      }
    }

    // Sort by department name, then by employee name
    final sortedData = employeeMap.values.toList()
      ..sort((a, b) {
        final deptComparison = a['department'].toString().compareTo(b['department'].toString());
        if (deptComparison != 0) return deptComparison;
        return a['full_name'].toString().compareTo(b['full_name'].toString());
      });

    setState(() => _attendanceData = sortedData);
  }

  String? _findReportingManager(String employeeId, int? employeeDeptId) {
    if (employeeDeptId == null) return null;

    int traversalCount = 0;
    int? currentDeptId = employeeDeptId;

    while (currentDeptId != null && traversalCount < 5) {
      final deptInfo = _departmentCache[currentDeptId.toString()];
      if (deptInfo == null) break;

      final managerId = deptInfo['manager_id'] as String?;

      // If current department has a manager and it's not the employee themselves
      if (managerId != null && managerId != employeeId) {
        return managerId;
      }

      // If employee is the manager of this department, look at parent department
      if (managerId == employeeId) {
        currentDeptId = deptInfo['parent_id'] as int?;
        traversalCount++;
        continue;
      }

      // If no manager for this department, look at parent department
      currentDeptId = deptInfo['parent_id'] as int?;
      traversalCount++;
    }

    return null;
  }

  void _updateStatusTotals(Map<String, dynamic> employee, String status) {
    switch (status.toLowerCase()) {
      case 'present':
        employee['total_present']++;
        break;
      case 'leave':
        employee['total_leave']++;
        break;
      case 'half-day':
      case 'half':
        employee['total_half_day']++;
        break;
      case 'weekend':
        employee['total_weekend']++;
        break;
      case 'comp-w':
        employee['total_comp_w']++;
        break;
      case 'comp-off':
        employee['total_comp_off']++;
        break;
      default:
        employee['total_absent']++;
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final now = currentTime;
    final firstDate = DateTime(2025, 7); // July 2025
    final lastDate = DateTime(now.year, now.month, now.day); // Current date

    // Ensure initialDate is within the valid range
    DateTime initialDate = _selectedMonth;
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
      _fetchMonthlyAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Monthly Attendance',
              style: TextStyle(color: Colors.white),
            ),
            Text(
              DateFormat('MMMM yyyy').format(_selectedMonth),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'calendar':
                  _selectMonth(context);
                  break;
                case 'export':
                  _exportToCSV();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'calendar',
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Change Month'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Share as CSV'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _attendanceData.isEmpty
            ? const Center(child: Text('No attendance data available'))
            : Column(
          children: [
            // Legend
            Container(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildLegendItem('P', 'Present', Colors.green.shade100),
                  _buildLegendItem('A', 'Absent', Colors.red.shade100),
                  _buildLegendItem('L', 'Leave', Colors.blue.shade100),
                  _buildLegendItem('½', 'Half Day', Colors.orange.shade100),
                  _buildLegendItem('W', 'Weekend', Colors.grey.shade100),
                  _buildLegendItem('CW', 'Comp-W', Colors.teal.shade100),
                  _buildLegendItem('CO', 'Comp-Off', Colors.indigo.shade100),
                  _buildLegendItem('H', 'Holiday', Colors.purple.shade100),
                ],
              ),
            ),
            // Data Table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columnSpacing: 12,
                    headingRowHeight: 50,
                    dataRowMinHeight: 40,
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                    columns: [
                      const DataColumn(label: Text('Employee', overflow: TextOverflow.ellipsis)),
                      const DataColumn(label: Text('Code'), numeric: true),
                      const DataColumn(label: Text('Department')),
                      const DataColumn(label: Text('Reporting Manager')),
                      ..._dayHeaders.map((day) => DataColumn(
                        label: SizedBox(
                          width: 30,
                          child: Text(day, textAlign: TextAlign.center),
                        ),
                        numeric: true,
                      )),
                      const DataColumn(label: Text('P'), numeric: true),
                      const DataColumn(label: Text('A'), numeric: true),
                      const DataColumn(label: Text('L'), numeric: true),
                      const DataColumn(label: Text('½'), numeric: true),
                      const DataColumn(label: Text('W'), numeric: true),
                      const DataColumn(label: Text('CW'), numeric: true),
                      const DataColumn(label: Text('CO'), numeric: true),
                    ],
                    rows: _attendanceData.map((employee) {
                      final days = employee['days'] as Map<int, String>;

                      return DataRow(cells: [
                        DataCell(Text(
                          employee['full_name'],
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        )),
                        DataCell(Center(child: Text(employee['employee_code']))),
                        DataCell(Text(employee['department'])),
                        DataCell(Text(employee['reporting_manager'])),
                        ...List.generate(_daysInMonth, (index) {
                          final day = index + 1;
                          final status = days[day] ?? '';
                          final currentDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                          final now = currentTime;
                          final yesterday = now.subtract(const Duration(days: 1));

                          // Only show status for days up to yesterday
                          if (currentDate.isAfter(yesterday)) {
                            return DataCell(
                              Container(
                                width: 35,
                                alignment: Alignment.center,
                                child: const Text('-', style: TextStyle(color: Colors.grey)),
                              ),
                            );
                          }

                          return DataCell(
                            Tooltip(
                              message: '${_getStatusDisplayName(status)} - ${_selectedMonth.month}/$day',
                              child: Container(
                                width: 35,
                                alignment: Alignment.center,
                                child: _getStatusIndicator(status),
                              ),
                            ),
                          );
                        }),
                        DataCell(Center(child: Text(employee['total_present'].toString()))),
                        DataCell(Center(child: Text(employee['total_absent'].toString()))),
                        DataCell(Center(child: Text(employee['total_leave'].toString()))),
                        DataCell(Center(child: Text(employee['total_half_day'].toString()))),
                        DataCell(Center(child: Text(employee['total_weekend'].toString()))),
                        DataCell(Center(child: Text(employee['total_comp_w'].toString()))),
                        DataCell(Center(child: Text(employee['total_comp_off'].toString()))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String symbol, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            symbol,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'leave':
        return 'Leave';
      case 'half-day':
      case 'half':
        return 'Half Day';
      case 'weekend':
        return 'Weekend';
      case 'comp-w':
        return 'Comp Working';
      case 'comp-off':
        return 'Comp Off';
      case 'holiday':
        return 'Holiday';
      default:
        return status;
    }
  }

  Widget _getStatusIndicator(String status) {
    final statusLower = status.toLowerCase();
    Color bgColor;
    String symbol;

    switch (statusLower) {
      case 'present':
        bgColor = Colors.green.shade100;
        symbol = 'P';
        break;
      case 'leave':
        bgColor = Colors.blue.shade100;
        symbol = 'L';
        break;
      case 'half-day':
      case 'half':
        bgColor = Colors.orange.shade100;
        symbol = '½';
        break;
      case 'weekend':
        bgColor = Colors.grey.shade100;
        symbol = 'W';
        break;
      case 'comp-w':
        bgColor = Colors.teal.shade100;
        symbol = 'CW';
        break;
      case 'comp-off':
        bgColor = Colors.indigo.shade100;
        symbol = 'CO';
        break;
      case 'holiday':
        bgColor = Colors.purple.shade100;
        symbol = 'H';
        break;
      default:
        bgColor = Colors.red.shade100;
        symbol = 'A';
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        symbol,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
          fontSize: symbol.length > 1 ? 8 : 12,
        ),
      ),
    );
  }



  Future<void> _exportToCSV() async {
    try {
      // Create CSV content
      final StringBuffer csvBuffer = StringBuffer();

      // Add header
      csvBuffer.write('Employee,Code,Department,Reporting Manager,');

      // Add day headers
      for (final dayHeader in _dayHeaders) {
        csvBuffer.write('"${dayHeader.replaceAll('\n', ' - ')}",');
      }

      // Add summary columns
      csvBuffer.write('Present,Absent,Leave,Half Day,Weekend,Comp-W,Comp-Off\n');

      // Add data rows
      for (final employee in _attendanceData) {
        final days = employee['days'] as Map<int, String>;

        // Employee info
        csvBuffer.write('"${employee['full_name']}",');
        csvBuffer.write('"${employee['employee_code']}",');
        csvBuffer.write('"${employee['department']}",');
        csvBuffer.write('"${employee['reporting_manager']}",');

        // Daily attendance
        for (int day = 1; day <= _daysInMonth; day++) {
          final status = days[day] ?? '';
          final currentDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
          final now = currentTime;
          final yesterday = now.subtract(const Duration(days: 1));

          if (currentDate.isAfter(yesterday)) {
            csvBuffer.write('-,');
          } else {
            csvBuffer.write('${_getStatusAbbreviation(status)},');
          }
        }

        // Summary totals
        csvBuffer.write('${employee['total_present']},');
        csvBuffer.write('${employee['total_absent']},');
        csvBuffer.write('${employee['total_leave']},');
        csvBuffer.write('${employee['total_half_day']},');
        csvBuffer.write('${employee['total_weekend']},');
        csvBuffer.write('${employee['total_comp_w']},');
        csvBuffer.write('${employee['total_comp_off']}\n');
      }

      // Get the CSV string
      final String csvString = csvBuffer.toString();

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final monthName = DateFormat('MMMM_yyyy').format(_selectedMonth);
      final fileName = 'Monthly_Attendance_$monthName.csv';
      final file = File('${directory.path}/$fileName');

      // --- CRUCIAL CHANGE HERE: Prepend BOM and specify UTF-8 encoding ---
      // The '\uFEFF' character is the Unicode BOM.
      await file.writeAsString('\uFEFF$csvString', encoding: utf8);

      // Share the file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Monthly Attendance Report - $monthName',
          text: 'Monthly attendance report for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting CSV: ${e.toString()}')),
      );
    }
  }

  String _getStatusAbbreviation(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'present':
        return 'P';
      case 'absent':
        return 'A';
      case 'leave':
        return 'L';
      case 'half-day':
      case 'half':
        return '½';
      case 'weekend':
        return 'W';
      case 'comp-w':
        return 'CW';
      case 'comp-off':
        return 'CO';
      case 'holiday':
        return 'H';
      default:
        return ''; // Or 'N/A' or some other placeholder for unknown statuses
    }
  }


}