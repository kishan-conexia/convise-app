import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../models/app_state.dart';

class DetailedAttendancePage extends StatefulWidget {
  const DetailedAttendancePage({super.key});

  @override
  _DetailedAttendancePageState createState() => _DetailedAttendancePageState();
}

class _DetailedAttendancePageState extends State<DetailedAttendancePage> {
  late DateTime _selectedDate;
  late DateTime _focusedDay;
  late DateTime _currentDate;
  late Future<List<Map<String, dynamic>>> attendanceDataFuture;
  bool isLoading = false;
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeData();

  }

  @override
  void dispose() {
    searchController.dispose();

    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final currentTime = await AppState().getCurrentTime();
      setState(() {
        _currentDate = currentTime;
        _selectedDate = currentTime;
        _focusedDay = currentTime;
        attendanceDataFuture = fetchAttendanceDetails(_selectedDate);
        isLoading = false; // Set to false when done
      });

    } catch (e) {
      // Handle error case
      setState(() {
        _currentDate = DateTime.now(); // Fallback to device time
        _selectedDate = _currentDate;
        _focusedDay = _currentDate;
        attendanceDataFuture = fetchAttendanceDetails(_selectedDate);
        isLoading = false; // Set to false even on error
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchAttendanceDetails(DateTime date) async {
    try {
      final response = await supabase.rpc('get_attendance_details', params: {
        'attendance_date': date.toIso8601String().substring(0, 10),
      });

      if (response == null) {
        throw Exception('No data received');
      }

      final List<dynamic> data = response as List<dynamic>;
      return List<Map<String, dynamic>>.from(
          data.map((item) => Map<String, dynamic>.from(item))
      );
    } catch (e) {
      throw Exception('Failed to load attendance details: $e');
    }
  }

  Future<void> _shareFilteredData() async {
    try {
      // Get filtered data
      final data = await attendanceDataFuture;
      final filteredData = _getFilteredData(data);

      if (filteredData.isEmpty) {
        _showMessage('No data to share', true);
        return;
      }

      // Create CSV headers
      List<String> headers = [
        'Name',
        'Department',
        'Date',
        'Status',
        'Punch In',
        'Punch Out',
        'Punch In Location',
        'Punch Out Location'
      ];

      List<List<String>> rows = [headers];

      // Add data rows
      for (var row in filteredData) {
        rows.add([
          row['Name']?.toString() ?? '',
          row['Department']?.toString() ?? '',
          row['Date']?.toString() ?? '',
          row['Status']?.toString() ?? '',
          row['Punch In']?.toString() ?? '',
          row['Punch Out']?.toString() ?? '',
          row['Punch In Location']?.toString() ?? '',
          row['Punch Out Location']?.toString() ?? '',
        ]);
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(rows);

      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'attendance_${_selectedDate.toIso8601String().substring(0, 10)}.csv';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      // Write CSV content to file
      await file.writeAsString(csvString);

      // Share the CSV file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: 'Attendance details for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
          subject: 'Attendance Report - ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
        ),
      );

    } catch (e) {
      _showMessage('Failed to share CSV: $e', true);
    }
  }




  void _showMessage(String message, bool isError) {
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

  void _filterEmployees(String query) {
    setState(() {
      searchQuery = query.trim().toLowerCase();
    });
  }

  List<Map<String, dynamic>> _getFilteredData(List<Map<String, dynamic>> data) {
    if (searchQuery.isEmpty) return data;

    return data.where((employee) {
      final name = employee['Name']?.toString().toLowerCase() ?? '';
      final department = employee['Department']?.toString().toLowerCase() ?? '';
      final status = employee['Status']?.toString().toLowerCase() ?? '';

      return name.contains(searchQuery) ||
          department.contains(searchQuery) ||
          status.contains(searchQuery);
    }).toList();
  }

  void _showEmployeeDetails(Map<String, dynamic> employee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag indicator
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Employee details content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            employee['Name']?.toString().substring(0, 1).toUpperCase() ?? '?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee['Name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                employee['Department'] ?? 'No Department',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(employee['Status']),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            employee['Status']?.toString().toUpperCase() ?? 'N/A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Attendance Details
                    _buildDetailSection('Attendance Details', [
                      _buildDetailRow('Date', employee['Date']?.toString() ?? 'N/A'),
                      _buildDetailRow('Punch In', _formatTime(employee['Punch In']?.toString())),
                      _buildDetailRow('Punch Out', _formatTime(employee['Punch Out']?.toString())),
                      _buildClickableLocationRow('Punch In Location', employee['Punch In Location']?.toString() ?? 'N/A'),
                      _buildClickableLocationRow('Punch Out Location', employee['Punch Out Location']?.toString() ?? 'N/A'),
                    ]),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen when isLoading is true
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AppState().appBarGradient,
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
                SizedBox(height: 20),
                Text(
                  'Loading Attendance Details...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dateString = DateFormat('MMM dd, yyyy').format(_selectedDate);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: AppBar(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Attendance Details',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  dateString,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white70,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _showCalendarDialog,
                tooltip: 'Select Date',
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareFilteredData,
                tooltip: 'Share CSV',
              ),
            ],

          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: AppState().bodyGradient
          ),
          child: SafeArea(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: attendanceDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading attendance data...',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              attendanceDataFuture = fetchAttendanceDetails(_selectedDate);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No attendance data found for this date.',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final attendanceData = snapshot.data!;
                final filteredData = _getFilteredData(attendanceData);

                return Column(
                  children: [
                    // FIXED Summary Card - Always visible at top
                    Card(
                      margin: const EdgeInsets.all(16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.blue.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildStatItem(
                                'Total',
                                '${filteredData.length}',
                                Icons.people,
                                Colors.blue,
                              ),
                              const SizedBox(width: 16),
                              _buildStatItem(
                                'Present',
                                '${filteredData.where((e) => e['Status']?.toString().toLowerCase() == 'present').length}',
                                Icons.check_circle,
                                Colors.green,
                              ),
                              const SizedBox(width: 16),
                              _buildStatItem(
                                'Absent',
                                '${filteredData.where((e) => e['Status']?.toString().toLowerCase() == 'absent').length}',
                                Icons.cancel,
                                Colors.red,
                              ),
                              const SizedBox(width: 16),
                              _buildStatItem(
                                'Half-Day',
                                '${filteredData.where((e) => e['Status']?.toString().toLowerCase() == 'half-day').length}',
                                Icons.timelapse,
                                Colors.orange,
                              ),
                              const SizedBox(width: 16),
                              _buildStatItem(
                                'Leave',
                                '${filteredData.where((e) => e['Status']?.toString().toLowerCase() == 'leave').length}',
                                Icons.beach_access,
                                Colors.blue,
                              ),
                              const SizedBox(width: 16),
                              _buildStatItem(
                                'Weekend',
                                '${filteredData.where((e) => e['Status']?.toString().toLowerCase() == 'weekend').length}',
                                Icons.weekend,
                                Colors.grey,
                              ),
                              const SizedBox(width: 16),
                              _buildStatItem(
                                'Comp Working',
                                '${filteredData.where((e) => e['Status']?.toString().toLowerCase() == 'comp-w').length}',
                                Icons.work,
                                Colors.teal,
                              ),
                              const SizedBox(width: 16),
                              _buildStatItem(
                                'Comp Off',
                                '${filteredData.where((e) => e['Status']?.toString().toLowerCase() == 'comp-off').length}',
                                Icons.offline_pin,
                                Colors.indigo,
                              ),
                              const SizedBox(width: 16),
                              _buildStatItem(
                                'Holiday',
                                '${filteredData.where((e) => e['Status']?.toString().toLowerCase() == 'holiday').length}',
                                Icons.celebration,
                                Colors.purple,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // FIXED Search Bar - Always visible below summary
                    Container(
                      margin: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchController,
                        onChanged: _filterEmployees,
                        decoration: InputDecoration(
                          hintText: 'Search employees...',
                          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              _filterEmployees('');
                            },
                          )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                          ),
                        ),
                      ),
                    ),

                    // SCROLLABLE Employee List - Takes remaining space
                    Expanded(
                      child: filteredData.isEmpty
                          ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No employees found matching your search.',
                              style: TextStyle(fontSize: 16, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Try adjusting your search criteria.',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                          : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredData.length,
                        itemBuilder: (context, index) {
                          return _buildEmployeeCard(filteredData[index]);
                        },
                      ),
                    ),

                    // Bottom padding
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showCalendarDialog() {
    print(_currentDate);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.blue.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dialog Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Date',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Calendar with normalized date comparisons
                    TableCalendar<dynamic>(
                      firstDay: DateTime(2025, 7, 1),
                      // FIX: Use normalized date (ignore time component)
                      lastDay: DateTime(_currentDate!.year, _currentDate!.month, _currentDate!.day),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDate, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        // FIX: Normalize both dates to ignore time component
                        final selectedDayNormalized = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                        final currentDateNormalized = DateTime(_currentDate!.year, _currentDate!.month, _currentDate!.day);

                        if (selectedDayNormalized.isAfter(currentDateNormalized)) {
                          _showMessage('Cannot select future dates', true);
                          return;
                        }

                        // Update the selected date
                        setState(() {
                          _selectedDate = selectedDay;
                          _focusedDay = focusedDay;
                          attendanceDataFuture = fetchAttendanceDetails(_selectedDate);
                        });

                        // Close the dialog
                        Navigator.of(context).pop();
                      },
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.sunday,
                      enabledDayPredicate: (day) {
                        // FIX: Normalize dates for comparison
                        final dayNormalized = DateTime(day.year, day.month, day.day);
                        final currentDateNormalized = DateTime(_currentDate!.year, _currentDate!.month, _currentDate!.day);
                        return !dayNormalized.isAfter(currentDateNormalized);
                      },
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        selectedDecoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Colors.orange.shade400,
                          shape: BoxShape.circle,
                        ),
                        disabledDecoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        disabledTextStyle: TextStyle(
                          color: Colors.grey.shade500,
                        ),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }




  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha((255 * 0.1).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
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
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> employee) {
    final status = employee['Status']?.toString() ?? 'N/A';
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEmployeeDetails(employee),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  employee['Name']?.toString().isNotEmpty == true
                      ? employee['Name'].toString().substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee['Name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employee['Department'] ?? 'No Department',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'present':
      case 'comp-w':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'half-day':
        return Colors.orange;
      case 'leave':
      case 'comp-off':
        return Colors.blue;
      case 'weekend':
        return Colors.blueGrey;
      case 'holiday':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Format timestamp to readable time
  String _formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'N/A';

    try {
      final datePart = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final fullDateTimeString = '$datePart $timestamp'; // e.g., "2025-08-17 12:11:05.249375"
      final dateTime = DateTime.parse(fullDateTimeString);
      return DateFormat('h:mm a').format(dateTime); // e.g., "12:11 PM"
    } catch (e) {
      // Return the original string as a fallback.
      print('Error parsing time: $e');
      return timestamp;
    }
  }


// Build clickable location row
  Widget _buildClickableLocationRow(String label, String location) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: location == 'N/A' || location.isEmpty
                ? const Text(
              'N/A',
              style: TextStyle(fontWeight: FontWeight.w400),
            )
                : GestureDetector(
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
      ),
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


}
