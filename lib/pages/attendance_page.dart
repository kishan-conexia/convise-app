import 'dart:io';
import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mnr/pages/attendance_summary_page.dart';
import 'package:mnr/pages/leave_application_page.dart';
import 'package:safe_device/safe_device.dart';

import '../main.dart';
import '../models/app_state.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with TickerProviderStateMixin {
  bool loading = true;
  bool processingPunch = false;
  String? currentLocation;
  DateTime? lastPunchIn;
  DateTime? lastPunchOut;
  DateTime currentTime = DateTime.now();
  // String deviceTime = '';
  bool canPunchIn = false;
  bool canPunchOut = false;
  int attendanceId = 0;

  // Work Schedule Data
  Map<String, dynamic>? workSchedule;
  Map<String, dynamic>? attendance;
  Map<String, dynamic>? yesterday;
  TimeOfDay? scheduleStartTime;
  TimeOfDay? scheduleEndTime;
  int graceMinutes = 0;
  bool isWorkingDay = true;
  bool isWeekend = false;
  bool isHoliday = false;
  bool isOnLeave = false;
  bool isLate = false;
  int lateMinutes = 0;
  double minWorkHours = 8.0;
  double maxWorkHours = 12.0;
  double compOffValue = 0.0;

  // Employee data
  Map<String, dynamic>? employeeProfile = AppState().employeeProfile;
  List<Map<String, dynamic>> leaveBalances = [];
  List<Map<String, dynamic>> holidays = [];

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  bool isLocationVerified = false;
  String locationVerificationMessage = 'Location not verified';
  Color locationStatusColor = Colors.grey;

  Map<String, dynamic>? leaveBalance;

  @override
  void initState() {
    super.initState();
    fetchAttendanceAndSchedule();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _slideController.forward();
  }

  Future<void> fetchAttendanceAndSchedule() async {
    try {
      final String profileId = AppState().userId ?? '';
      if (profileId.isEmpty) {
        setState(() {
          loading = false;
        });
        return;
      }

      await _fetchWorkSchedule(profileId);
      // Parallel data fetching for better performance
      await Future.wait([
        _fetchTodayAttendance(profileId),
        // _fetchLeaveBalances(profileId),
        // _fetchHolidays(),
        _checkDayStatus(profileId),
      ]);

      // Check day type (working day, weekend, holiday)
      _checkDayType();

    } catch (e) {
      print("Error fetching data: $e");
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> _fetchWorkSchedule(String profileId) async {
    try {
      currentTime = await AppState().getCurrentTime();
      if (AppState().workSchedule == null || AppState().workSchedule!.isEmpty) {
        final scheduleData = await supabase
            .from('work_schedules')
            .select('*')
            .eq('employee_id', profileId)
            .maybeSingle();

        if (scheduleData != null) {
          AppState().workSchedule = scheduleData;
          workSchedule = scheduleData;
        }
      } else {
        workSchedule = AppState().workSchedule;
      }

      if (workSchedule != null && workSchedule!.isNotEmpty) {

        // Parse start and end times
        if (workSchedule?['start_time'] != null) {
          final startTimeParts = workSchedule!['start_time'].toString().split(':');
          scheduleStartTime = TimeOfDay(
            hour: int.parse(startTimeParts[0]),
            minute: int.parse(startTimeParts[1]),
          );
        }

        if (workSchedule?['end_time'] != null) {
          final endTimeParts = workSchedule!['end_time'].toString().split(':');
          scheduleEndTime = TimeOfDay(
            hour: int.parse(endTimeParts[0]),
            minute: int.parse(endTimeParts[1]),
          );
        }

        graceMinutes = workSchedule?['punch_in_grace'] ?? 0;
        minWorkHours = (workSchedule?['min_work_hours'] ?? 8.0).toDouble();
        maxWorkHours = (workSchedule?['max_work_hours'] ?? 12.0).toDouble();
      }
    } catch (e) {
      print("Error fetching work schedule: $e");
    }
  }

  Future<void> _fetchTodayAttendance(String profileId) async {
    try {
      // currentTime = await AppState().getCurrentTime();
      final String todayDateString = currentTime.toIso8601String().substring(0, 10);
      final String yesterdayDateString =
      currentTime.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

      Map<String, dynamic>? record;

      // 1. Check today's attendance
      record = await supabase
          .from('attendance')
          .select('*')
          .eq('employee_id', profileId)
          .eq('date', todayDateString)
          .maybeSingle();

      // 2. If not eligible punch out, check previous day if schedule is flexible
      if (record == null && workSchedule?['schedule_type'] == 'flexible') {
        final yesterdayRecord = await supabase
            .from('attendance')
            .select('*')
            .eq('employee_id', profileId)
            .eq('date', yesterdayDateString)
            .maybeSingle();

        if (yesterdayRecord != null &&
            yesterdayRecord['punch_in'] != null &&
            yesterdayRecord['punch_out'] == null) {
          final punchInTime = DateTime.parse(yesterdayRecord['punch_in']);
          final diff = currentTime!.difference(punchInTime).inHours;

          if (diff <= 15) {
            yesterday = yesterdayRecord;
            record = yesterdayRecord;
          }
        }
      }

      if (record != null) {
        setState(() {
          lastPunchIn = record?['punch_in'] != null ? DateTime.parse(record?['punch_in']) : null;
          lastPunchOut = record?['punch_out'] != null ? DateTime.parse(record?['punch_out']) : null;
          isLate = record?['is_late'] ?? false;
          lateMinutes = record?['late_minutes'] ?? 0;
          attendanceId = record?['id'];
          attendance = record;
        });
      }

    } catch (e) {
      print("Error fetching attendance: $e");
    }
  }


  Future<void> _fetchLeaveBalances(String profileId) async {
    try {
      // DateTime currentTime = await AppState().getCurrentTime();
      int? currentYear = currentTime.year;
      final balances = await supabase
          .from('employee_leave_balances')
          .select('*, leave_types!inner(leave_code)')
          .eq('employee_id', profileId)
          .eq('calendar_year', currentYear);

      leaveBalances = List<Map<String, dynamic>>.from(balances);
    } catch (e) {
      print("Error fetching leave balances: $e");
    }
  }

  // Future<void> _checkIfUserOnLeaveOrOptionalHoliday(String profileId) async {
  //   final today = currentTime ?? await AppState().getCurrentTime();
  //   final todayStr = today.toIso8601String().substring(0, 10);
  //
  //   // Check approved leave
  //   final leave = await supabase
  //       .from('leave_applications')
  //       .select('id')
  //       .eq('employee_id', profileId)
  //       .eq('status', 'approved')
  //       .lte('start_date', todayStr)
  //       .gte('end_date', todayStr)
  //       .maybeSingle();
  //
  //   if (leave != null) {
  //     setState(() {
  //       isOnLeave = true;
  //     });
  //     return;
  //   }
  //
  //   // Check approved optional holiday
  //   final optionalHoliday = await supabase
  //       .from('employee_holiday_selections')
  //       .select('id')
  //       .eq('employee_id', profileId)
  //       .eq('selected_date', todayStr)
  //       .eq('status', 'approved')
  //       .maybeSingle();
  //
  //   if (optionalHoliday != null) {
  //     setState(() {
  //       isOnLeave = true;
  //     });
  //   }
  // }

  Future<void> _checkDayStatus(String profileId) async {
    final today = currentTime;
    final todayStr = today.toIso8601String().substring(0, 10);

    /// 🔹 Check Leave (priority 1)
    final leave = await supabase
        .from('leave_applications')
        .select('id')
        .eq('employee_id', profileId)
        .eq('status', 'approved')
        .lte('start_date', todayStr)
        .gte('end_date', todayStr)
        .maybeSingle();

    if (leave != null) {
      isOnLeave = true;
      return;
    }

    /// 🔹 Check Approved Optional Holiday (priority 2)
    final optionalHoliday = await supabase
        .from('employee_holiday_selections')
        .select('id')
        .eq('employee_id', profileId)
        .eq('selected_date', todayStr)
        .eq('status', 'approved')
        .maybeSingle();

    if (optionalHoliday != null) {
      isOnLeave = true;
      return;
    }

    /// 🔹 Check Mandatory Holiday (priority 3)
    final department = employeeProfile?['department'];
    final holiday = await supabase
        .from('holidays')
        .select('id, applicable_departments')
        .eq('holiday_date', todayStr)
        .eq('is_active', true)
        .eq('is_optional', false)
        .eq('calendar_year', today.year)
        .maybeSingle();

    if (holiday != null) {
      final applicableDepts = holiday['applicable_departments'];
      if (applicableDepts == null || (department != null && applicableDepts.contains(department))) {
        isHoliday = true;
      }
    }
  }



  void _checkDayType() {
    if (workSchedule == null) return;

    final today = currentTime;
    final weekdayName = DateFormat('EEEE').format(today).toLowerCase();

    final weekdays = workSchedule?['weekdays'] ?? ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'] as List<dynamic>?;
    if (weekdays != null) {
      isWorkingDay = weekdays.any((day) => day.toString().toLowerCase() == weekdayName);
      isWeekend = !isWorkingDay;
    }
  }


  // Determine attendance status and type based on various conditions
  Map<String, dynamic> _determineAttendanceStatus(bool isPunchIn, DateTime currentTime, double workedHours, String scheduleType) {
    String status = 'present';
    String? attendanceType = 'regular';
    bool shouldAddCompOff = false;
    String message = '';

    if (isOnLeave) {
      return {
        'status': 'leave',
        'attendance_type': null,
        'should_add_comp_off': false,
        'message': isPunchIn ? 'You are on approved leave. Punch recorded as leave.' : 'Leave day recorded.',
      };
    }

    // Holiday work
    if (isHoliday) {
      status = 'comp-w';
      attendanceType = 'comp-off-earned';

      if (!isPunchIn) {
        if (workedHours >= minWorkHours) {
          compOffValue = 1.0;
          shouldAddCompOff = true;
          message = 'Punch out successfully';
          // message = 'Holiday work completed - Full Comp Off credited!';
        } else if (workedHours >= minWorkHours / 2) {
          compOffValue = 0.5;
          shouldAddCompOff = true;
          message = 'Punch out successfully';
          // message = 'Holiday work completed - Half Comp Off credited!';
        } else {
          status = 'holiday';
          attendanceType = null;
          message = 'Punch out successfully';
          // message = 'Holiday work too short for Comp Off (${workedHours.toStringAsFixed(1)} hrs)';
        }
      } else {
        status = 'holiday';
        attendanceType = null;
        // message = 'Working on holiday - Comp Off (pending completion)';
        message = 'Punch in successfully';
      }
    }
    // Weekend work
    else if (isWeekend) {
      status = 'comp-w';
      attendanceType = 'comp-off-earned';

      if (!isPunchIn) {
        if (workedHours >= minWorkHours) {
          compOffValue = 1.0;
          shouldAddCompOff = true;
          message = 'Punch out successfully';
          // message = 'Weekend work completed - Full Comp Off credited!';
        } else if (workedHours >= minWorkHours / 2) {
          compOffValue = 0.5;
          shouldAddCompOff = true;
          message = 'Punch out successfully';
          // message = 'Weekend work completed - Half Comp Off credited!';
        } else {
          status = 'weekend';
          attendanceType = null;
          // message = 'Weekend work too short for Comp Off (${workedHours.toStringAsFixed(1)} hrs)';
          message = 'Punch out successfully';
        }
      } else {
        status = 'weekend';
        attendanceType = null;
        message = 'Punch in successfully';
        // message = 'Working on weekend - Comp Off (pending completion)';
      }
    }
    // Regular working day
    else if (isWorkingDay) {
      if (isPunchIn) {

        // FLEXIBLE SCHEDULES: NO LATE ARRIVAL CHECKS
        if (scheduleType == 'flexible') {
          status = 'half-day';
          message = 'Punch in successfully';

        } else if (_isLateArrival(currentTime)) {
          final lateMin = _calculateLateMinutes(currentTime);
          if (lateMin > 120) { // More than 2 hours late
            status = 'half-day';
            message = 'Punch in successfully';
          } else {
            // status = 'late';
            // message = 'Late arrival ($lateMin minutes)';
            status = 'half-day';
            message = 'Punch in successfully';
          }
        } else {
          status = 'half-day';
          message = 'Punch in successfully';
          // status = 'present';
          // message = 'On time!';
        }
        attendanceType = 'regular';
      } else if (scheduleType == 'fixed' && workSchedule?['punch_in'] != null) {
        // Punch out logic
        // Adjust lastPunchIn if it's before scheduleStartTime
        DateTime effectivePunchIn = lastPunchIn!;

        if (scheduleStartTime != null) {
          final scheduleStartDateTime = DateTime(
            lastPunchIn!.year,
            lastPunchIn!.month,
            lastPunchIn!.day,
            scheduleStartTime!.hour,
            scheduleStartTime!.minute,
          );

          if (lastPunchIn!.isBefore(scheduleStartDateTime)) {
            effectivePunchIn = scheduleStartDateTime;
          }
        }

        final workedHours = currentTime.difference(effectivePunchIn).inMinutes / 60.0;

        if (workedHours < minWorkHours / 2) {
          status = 'absent';
          attendanceType = 'regular';
          message = 'Punch out successfully.';

        } else if (workedHours < minWorkHours) {
          status = 'half-day';
          attendanceType = 'regular';
          // message = 'Less than full-day work. Marked as Half Day.';
          message = 'Punch out successfully';

        } else if (_isFieldEarlyDeparture(currentTime)) {
          final earlyMin = _calculateFieldEarlyDepartureMinutes(currentTime);
          if (earlyMin > 120) { // Left 2+ hours early
            status = 'half-day';
            message = 'Punch out successfully';
          } else {
            // status = 'early-departure';
            // message = 'Early departure ($earlyMin minutes short)';
            status = 'half-day';
            message = 'Punch out successfully';
          }
        } else {
          // Check for overtime
          if (workedHours > minWorkHours && attendance?['is_late'] == true) {
            // status = 'half-day';
            // attendanceType = 'regular';
            // message = 'Overtime work completed (${(workedHours - maxWorkHours).toStringAsFixed(1)} hours extra)';
            status = 'half-day';
            message = 'Punch out successfully';
          } else {
            status = 'present';
            message = 'Punch out successfully';
          }
        }
      } else {
        // Punch out logic
        final workedHours = currentTime.difference(lastPunchIn!).inMinutes / 60.0;

        if (workedHours < minWorkHours / 2) {
          status = 'absent';
          attendanceType = 'regular';
          message = 'Punch out successfully.';

        } else if (workedHours < minWorkHours) {
          status = 'half-day';
          attendanceType = 'regular';
          // message = 'Less than full-day work. Marked as Half Day.';
          message = 'Punch out successfully';

        } else if (_isEarlyDeparture(currentTime)) {
          final earlyMin = _calculateEarlyDepartureMinutes(currentTime);
          if (earlyMin > 120) { // Left 2+ hours early
            status = 'half-day';
            message = 'Punch out successfully';
          } else {
            // status = 'early-departure';
            // message = 'Early departure ($earlyMin minutes short)';
            status = 'half-day';
            message = 'Punch out successfully';
          }
        } else {
          // Check min work hour completed but also late
          if (workedHours > minWorkHours && attendance?['is_late'] == true) {
            // status = 'half-day';
            // attendanceType = 'regular';
            // message = 'Overtime work completed (${(workedHours - maxWorkHours).toStringAsFixed(1)} hours extra)';
            status = 'half-day';
            message = 'Punch out successfully';
          } else {
            status = 'present';
            message = 'Punch out successfully';
          }
        }
      }
    }

    return {
      'status': status,
      'attendance_type': attendanceType,
      'should_add_comp_off': shouldAddCompOff,
      'message': message,
    };
  }

  Future<void> _updateCompOffBalance(String profileId, DateTime currentTime) async {
    try {

      await _fetchLeaveBalances(profileId);

      // Find compensatory off leave type
      final compOffBalance = leaveBalances.firstWhere(
            (balance) => balance['leave_types']['leave_code'] == 'COMP',
        orElse: () => <String, dynamic>{},
      );


      if (compOffBalance.isNotEmpty) {
        final double currentAllocated = (compOffBalance['allocated_days'] as num).toDouble();
        final double currentAvailable = (compOffBalance['available_days'] as num).toDouble();
        final double currentExpired = (compOffBalance['expired_days'] as num).toDouble();

        // If there's already an available comp off, move it to expired
        double newExpired = currentExpired;
        if (currentAvailable > 0) {
          newExpired = currentExpired + currentAvailable;
        }

        final newAllocated = currentAllocated + compOffValue;

        await supabase
            .from('employee_leave_balances')
            .update({
          'allocated_days': newAllocated,
          'expired_days': newExpired,
          'updated_at': currentTime.toIso8601String(),
        }).eq('id', compOffBalance['id']);

        // Refresh leave balances
        // await _fetchLeaveBalances(profileId);
      }
    } catch (e) {
      print("Error updating comp off balance: $e");
    }
  }

  Future<void> _fetchCurrentLocation(bool isPunchIn) async {

    final cutoffDate = DateTime(2025, 7, 1);

    // Check if the current date is before July 1, 2025
    if (currentTime.isBefore(cutoffDate)) {
      _showMessage('Punch In/Out will be enabled from July 1, 2025.'); // Or true if you want it to look like an error
      return; // Stop execution if the condition is met
    }

    if (workSchedule == null || workSchedule!.isEmpty) {
      _showMessage('Schedule not found', isError: true);
      return;
    }

    // Check if geofencing is enabled
    if (AppState().geofencing != true) {
      await handleAttendance(isPunchIn, 'regular');
      return;
    }

    setState(() {
      processingPunch = true;
    });


    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage("Location services are disabled.", isError: true);
      setState(() {
        processingPunch = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showMessage("Location permission denied.", isError: true);
        setState(() {
          processingPunch = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDialog();
      setState(() {
        processingPunch = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: Platform.isAndroid
            ? AndroidSettings(accuracy: LocationAccuracy.high)
            : AppleSettings(accuracy: LocationAccuracy.high),
      );

      // 1️⃣  Simple mock-location detection (Android≥18)
      if (Platform.isAndroid && (position.isMocked)) {
        _showMessage('Fake location detected. Punch aborted.', isError: true);
        setState(() => processingPunch = false);
        return;
      }

      // 2️⃣  Extra check with `safe_device`
      bool isMockLocation = false;
      bool isRealDevice = true;

      try {
        isMockLocation = await SafeDevice.isMockLocation;
        isRealDevice = await SafeDevice.isRealDevice;
      } catch (e) {
        print('SafeDevice check failed: $e');
      }

      if (isMockLocation) {
        _showMessage('Fake location detected. Punch aborted.', isError: true);
        setState(() => processingPunch = false);
        return;
      }

      if (!isRealDevice) {
        _showMessage('Please use a real device for attendance.', isError: true);
        setState(() => processingPunch = false);
        return;
      }

      if (position.accuracy > 100) {
        _showApproximateDialog();
        setState(() {
          processingPunch = false;
        });
        return;
      }

      setState(() {
        currentLocation = '${position.latitude}, ${position.longitude}';
      });

      await _checkGeofence(position, isPunchIn);

    } catch (e) {
      _showMessage("Failed to get location: $e", isError: true);
    }

    setState(() {
      processingPunch = false;
    });
  }

  Future<void> _checkGeofence(Position position, bool isPunchIn) async {
    setState(() {
      isLocationVerified = false;
      locationVerificationMessage = 'Verifying location...';
      locationStatusColor = Colors.grey;
    });

    final currentLat = position.latitude;
    final currentLng = position.longitude;
    final bool wfmAllowed = workSchedule?['wfm_allowed'] ?? false;

    // 1. Check office location first
    final officeLocation = workSchedule?['office_location']?.toString() ?? '28.560247, 77.199301';
    final officeRadius = workSchedule?['office_radius'] ?? 100;

    if (await _isWithinLocation(currentLat, currentLng, officeLocation, officeRadius)) {
      setState(() {
        isLocationVerified = true;
        locationVerificationMessage = 'Office location verified';
        locationStatusColor = Colors.green;
      });
      await handleAttendance(isPunchIn, 'regular');
      return;
    }

    // 2. If outside office but WFM is allowed
    if (wfmAllowed) {
      // Check home location
      final homeLocation = workSchedule?['home_location']?.toString();
      final homeRadius = workSchedule?['home_radius'] ?? 100;

      if (homeLocation != null &&
          await _isWithinLocation(currentLat, currentLng, homeLocation, homeRadius)) {
        setState(() {
          isLocationVerified = true;
          locationVerificationMessage = 'Home location verified';
          locationStatusColor = Colors.green;
        });
        await handleAttendance(isPunchIn, 'wfm');
        return;
      }

      // Check named work locations
      final locationNames = workSchedule?['work_location_names']?.toString();
      final locationRadius = workSchedule?['work_location_radius'] ?? 100;

      if (locationNames != null && locationNames.isNotEmpty) {
        if (await _isNearNamedLocation(currentLat, currentLng, locationNames, locationRadius)) {
          setState(() {
            isLocationVerified = true;
            locationVerificationMessage = 'Work location verified';
            locationStatusColor = Colors.green;
          });
          await handleAttendance(isPunchIn, 'field');
          return;
        }
      }
    }
    // Location verification failed
    setState(() {
      isLocationVerified = false;
      locationVerificationMessage = 'Outside allowed work area';
      locationStatusColor = Colors.red;
    });
    // If none of the locations match
    _showMessage("You are outside the allowed work area", isError: true);
  }


  Future<void> handleAttendance(bool isPunchIn, String? locationType) async {
    try {
      final DateTime currentTime = await AppState().getCurrentTime();
      final String? location = currentLocation;
      final String profileId = AppState().userId ?? '';
      final scheduleType = workSchedule?['schedule_type'] ?? 'fixed';

      if (profileId.isEmpty) {
        _showMessage("User not logged in", isError: true);
        return;
      }

      final String dateString = currentTime.toIso8601String().substring(0, 10);

      final workHours = lastPunchIn != null
          ? currentTime.difference(lastPunchIn!).inMinutes / 60.0
          : 0.0;

      // Determine attendance status and type
      final attendanceInfo = _determineAttendanceStatus(isPunchIn, currentTime, workHours, scheduleType);

      if (isPunchIn && canPunchIn) {
        // Enforce minimum 2-hour gap for flexible schedule
        if (scheduleType == 'flexible') {
          final DateTime yesterday = currentTime.subtract(const Duration(days: 1));
          final String yesterdayDate = yesterday.toIso8601String().substring(0, 10);

          final previousAttendance = await supabase
              .from('attendance')
              .select('punch_out')
              .eq('employee_id', profileId)
              .eq('date', yesterdayDate)
              .maybeSingle();

          if (previousAttendance != null && previousAttendance['punch_out'] != null) {
            final DateTime lastPunchOutTime = DateTime.parse(previousAttendance['punch_out']);
            final Duration diff = currentTime.difference(lastPunchOutTime);

            if (diff.inMinutes < 60) {
              _showMessage(
                "Time required before next punch-in",
                isError: true,
              );
              return;
            }
          }
        }

        final scheduledTime = DateTime(
          currentTime.year,
          currentTime.month,
          currentTime.day,
          scheduleStartTime!.hour,
          scheduleStartTime!.minute,
        );

        final earliestAllowedPunchIn = scheduledTime.subtract(const Duration(hours: 4));
        final latestAllowedPunchIn = scheduledTime.add(Duration(hours: minWorkHours.toInt()));

        // Validate punch-in time for regular working days
        if (isWorkingDay && scheduleStartTime != null && scheduleType == 'fixed') {

          if (currentTime.isBefore(earliestAllowedPunchIn)) {
            _showMessage("Too early to punch in.", isError: true);
            return;
          }

          if (currentTime.isAfter(latestAllowedPunchIn)) {
            _showMessage("Too late to punch in.", isError: true);
            return;
          }
        } else if (!isWorkingDay && scheduleStartTime != null && scheduleType == 'fixed') {

          if (currentTime.isBefore(earliestAllowedPunchIn)) {
            _showMessage("Too early to punch in.", isError: true);
            return;
          }

        }

        // Late arrival only applies to fixed schedules
        final isLateArrival = (scheduleType == 'fixed' && isWorkingDay)
            ? _isLateArrival(currentTime)
            : false;

        final lateMinutesCalc = (scheduleType == 'fixed' && isWorkingDay)
            ? _calculateLateMinutes(currentTime)
            : 0;

        final punchId = await supabase.from('attendance').insert({
          'employee_id': profileId,
          'punch_in': currentTime.toIso8601String(),
          'punch_in_location': location,
          'date': dateString,
          'status': attendanceInfo['status'],
          'attendance_type': attendanceInfo['attendance_type'],
          'is_late': isLateArrival,
          'late_minutes': lateMinutesCalc,
          'is_weekend': isWeekend,
          'is_holiday': isHoliday,
        }).select('id');

        setState(() {
          lastPunchIn = currentTime;
          isLate = isLateArrival;
          lateMinutes = lateMinutesCalc;
          attendanceId = punchId[0]['id'];
        });

        _showMessage(attendanceInfo['message'], isError: isLateArrival);

      } else if (canPunchOut) {
        if (scheduleType == 'fixed') {
          // Create cutoff time: today at 11:30 PM
          final DateTime punchOutCutoff = DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            23,
            30,
          );

          if (currentTime.isAfter(punchOutCutoff)) {
            _showMessage("Punch-out not allowed beyond work schedule.", isError: true);
            return;
          }
        }

        // Calculate early departure and work hours
        final isEarlyDep = isWorkingDay
            ? _isEarlyDeparture(currentTime)
            : false;

        final earlyDepMinutes = isWorkingDay
            ? _calculateEarlyDepartureMinutes(currentTime)
            : 0;

        final double finalWorkHours = lastPunchIn != null
            ? double.parse((currentTime.difference(lastPunchIn!).inMinutes / 60.0).toStringAsFixed(2))
            : 0.0;


        if (workSchedule?['schedule_type'] == 'flexible' && yesterday != null) {

          if (yesterday != null &&
              yesterday?['punch_in'] != null &&
              yesterday?['punch_out'] == null) {

            final DateTime punchInTime = DateTime.parse(yesterday?['punch_in']);
            final double prevWorkHours = double.parse((currentTime.difference(punchInTime).inMinutes / 60.0).toStringAsFixed(2));

            String compStatus = '';
            String attendanceType = '';
            double compOffVal = 0.0;
            bool isWeekendPrev = yesterday?['is_weekend'] == true;
            bool isHolidayPrev = yesterday?['is_holiday'] == true;

            if (isWeekendPrev || isHolidayPrev) {
              if (prevWorkHours >= minWorkHours) {
                compOffVal = 1.0;
              } else if (prevWorkHours >= minWorkHours / 2) {
                compOffVal = 0.5;
              }

              compStatus = isHolidayPrev || isWeekendPrev ? 'comp-w' : 'present';
              attendanceType = isHolidayPrev || isWeekendPrev ? 'comp-off-earned' : 'regular';

              await supabase.from('attendance').update({
                'punch_out': currentTime.toIso8601String(),
                'punch_out_location': location,
                'status': compStatus,
                'attendance_type': attendanceType,
                'work_hours': prevWorkHours,
              }).eq('id', yesterday?['id']);

              if (compOffVal > 0) {
                compOffValue = compOffVal;
                await _updateCompOffBalance(profileId, currentTime);
              }

              setState(() {
                lastPunchOut = currentTime;
              });

              _showMessage('Punch out successfully', isError: false);
              return;
            }
          }
        }


        if (attendanceInfo['status'] == 'absent') {
          final shouldProceed = await showPunchOutConfirmationDialog(context, attendanceInfo['status']);
          if (!shouldProceed) return;
        }

        await supabase.from('attendance').update({
          'punch_out': currentTime.toIso8601String(),
          'punch_out_location': location,
          'status': attendanceInfo['status'],
          'attendance_type': attendanceInfo['attendance_type'],
          'is_early_departure': isEarlyDep,
          'early_departure_minutes': earlyDepMinutes,
          'work_hours': finalWorkHours,
        }).eq('id', attendanceId);

        setState(() {
          lastPunchOut = currentTime;
        });

        // Add comp off if applicable
        if (attendanceInfo['should_add_comp_off'] && compOffValue > 0) {
          await _updateCompOffBalance(profileId, currentTime);
        }

        _showMessage(attendanceInfo['message'],
            isError: isEarlyDep || attendanceInfo['status'] == 'half-day');
      }
    } catch (e) {
      _showMessage("Failed to mark attendance: $e", isError: true);
    }
  }

  Future<bool> showPunchOutConfirmationDialog(
      BuildContext context,
      String status,
      ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Punch Out"),
        content: Text(
          "You're about to punch out with status: ${status.toUpperCase()}.\n\nAre you sure you want to continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes, Punch Out"),
          ),
        ],
      ),
    ) ??
        false; // Default to false if dialog is dismissed
  }


  bool _isLateArrival(DateTime punchInTime) {
    if (scheduleStartTime == null) return false;

    final scheduledTime = DateTime(
      punchInTime.year,
      punchInTime.month,
      punchInTime.day,
      scheduleStartTime!.hour,
      scheduleStartTime!.minute,
    );

    final graceTime = scheduledTime.add(Duration(minutes: graceMinutes));
    return punchInTime.isAfter(graceTime);
  }

  int _calculateLateMinutes(DateTime punchInTime) {
    if (scheduleStartTime == null) return 0;

    final scheduledTime = DateTime(
      punchInTime.year,
      punchInTime.month,
      punchInTime.day,
      scheduleStartTime!.hour,
      scheduleStartTime!.minute,
    );

    final graceTime = scheduledTime.add(Duration(minutes: graceMinutes));

    if (punchInTime.isAfter(graceTime)) {
      return punchInTime.difference(scheduledTime).inMinutes;
    }

    return 0;
  }

  bool _isEarlyDeparture(DateTime punchOutTime) {
    if (scheduleEndTime == null || lastPunchIn == null) return false;

    final scheduledEndTime = DateTime(
      punchOutTime.year,
      punchOutTime.month,
      punchOutTime.day,
      scheduleEndTime!.hour,
      scheduleEndTime!.minute,
    );

    // Check if leaving before scheduled end time
    if (punchOutTime.isBefore(scheduledEndTime)) {
      // Also check if minimum work hours are completed
      final workedHours = punchOutTime.difference(lastPunchIn!).inMinutes / 60.0;
      return workedHours < minWorkHours;
    }

    return false;
  }

  bool _isFieldEarlyDeparture(DateTime punchOutTime) {
    if (scheduleEndTime == null || lastPunchIn == null) return false;

    DateTime effectivePunchIn = lastPunchIn!;

    if (scheduleStartTime != null) {
      final scheduleStartDateTime = DateTime(
        lastPunchIn!.year,
        lastPunchIn!.month,
        lastPunchIn!.day,
        scheduleStartTime!.hour,
        scheduleStartTime!.minute,
      );

      if (lastPunchIn!.isBefore(scheduleStartDateTime)) {
        effectivePunchIn = scheduleStartDateTime;
      }
    }

    final scheduledEndTime = DateTime(
      punchOutTime.year,
      punchOutTime.month,
      punchOutTime.day,
      scheduleEndTime!.hour,
      scheduleEndTime!.minute,
    );

    // Check if leaving before scheduled end time
    if (punchOutTime.isBefore(scheduledEndTime)) {
      // Also check if minimum work hours are completed
      final workedHours = punchOutTime.difference(effectivePunchIn).inMinutes / 60.0;
      return workedHours < minWorkHours;
    }

    return false;
  }

  int _calculateEarlyDepartureMinutes(DateTime punchOutTime) {
    if (scheduleEndTime == null || lastPunchIn == null) return 0;

    final workedHours = punchOutTime.difference(lastPunchIn!).inMinutes / 60.0;
    if (workedHours < minWorkHours) {
      final requiredWorkMinutes = (minWorkHours * 60).toInt();
      final actualWorkMinutes = punchOutTime.difference(lastPunchIn!).inMinutes;
      return requiredWorkMinutes - actualWorkMinutes;
    }

    return 0;
  }

  int _calculateFieldEarlyDepartureMinutes(DateTime punchOutTime) {
    if (scheduleEndTime == null || lastPunchIn == null) return 0;

    // Adjust lastPunchIn if it's before scheduleStartTime
    DateTime effectivePunchIn = lastPunchIn!;

    if (scheduleStartTime != null) {
      final scheduleStartDateTime = DateTime(
        lastPunchIn!.year,
        lastPunchIn!.month,
        lastPunchIn!.day,
        scheduleStartTime!.hour,
        scheduleStartTime!.minute,
      );

      if (lastPunchIn!.isBefore(scheduleStartDateTime)) {
        effectivePunchIn = scheduleStartDateTime;
      }
    }

    final workedHours = punchOutTime.difference(effectivePunchIn).inMinutes / 60.0;
    if (workedHours < minWorkHours) {
      final requiredWorkMinutes = (minWorkHours * 60).toInt();
      final actualWorkMinutes = punchOutTime.difference(effectivePunchIn).inMinutes;
      return requiredWorkMinutes - actualWorkMinutes;
    }

    return 0;
  }

  String _getWorkingHours() {
    if (lastPunchIn == null) return '0h 0m';

    final endTime = lastPunchOut ?? currentTime;
    final duration = endTime!.difference(lastPunchIn!);

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return '${hours}h ${minutes}m';
  }

  // Helper function to check coordinate-based locations
  Future<bool> _isWithinLocation(
      double currentLat,
      double currentLng,
      String locationStr,
      int radius
      ) async {
    try {
      final coords = locationStr.split(',');
      if (coords.length != 2) return false;

      final locationLat = double.tryParse(coords[0].trim()) ?? 0.0;
      final locationLng = double.tryParse(coords[1].trim()) ?? 0.0;

      final distance = Geolocator.distanceBetween(
          currentLat, currentLng, locationLat, locationLng
      );

      return distance <= radius;
    } catch (e) {
      print("Location check error: $e");
      return false;
    }
  }

// Helper function to check named locations using placemarks
  Future<bool> _isNearNamedLocation(
      double currentLat,
      double currentLng,
      String locationNames,
      int radius
      ) async {
    try {
      // Split location names (comma or newline separated)
      final names = locationNames.split(RegExp(r'[,|\n]')).map((n) => n.trim().toLowerCase()).toList();

      // Get current placemark
      final placemarks = await placemarkFromCoordinates(28.500745, 77.290862);
      if (placemarks.isEmpty) return false;

      final placemark = placemarks.first;
      String currentAddress = "${placemark.locality}, ${placemark.subLocality}, ${placemark.administrativeArea}, ${placemark.subAdministrativeArea}, ${placemark.postalCode}".toLowerCase();

      if (names.any((name) => currentAddress.contains(name))) {
        return true;
      }

      // Check nearby locations in all directions
      final List<double> directions = [0, 45, 90, 135, 180, 225, 270, 315];

      for (double bearing in directions) {
        final offset = _computeOffset(currentLat, currentLng, radius.toDouble(), bearing);
        final nearbyPlacemarks = await placemarkFromCoordinates(offset.latitude, offset.longitude);

        if (nearbyPlacemarks.isNotEmpty) {
          final nearbyPlacemark = nearbyPlacemarks.first;
          String nearbyAddress = "${nearbyPlacemark.locality}, ${placemark.subLocality}, ${nearbyPlacemark.administrativeArea}, ${nearbyPlacemark.subAdministrativeArea}, ${nearbyPlacemark.postalCode}".toLowerCase();

          if (names.any((name) => nearbyAddress.contains(name))) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      print("Named location check error: $e");
      return false;
    }
  }

  LatLng _computeOffset(double lat, double lng, double distanceInMeters, double bearingInDegrees) {
    const double earthRadius = 6371000;
    final double bearingRad = bearingInDegrees * pi / 180;
    final double latRad = lat * pi / 180;
    final double lngRad = lng * pi / 180;
    final double distanceRatio = distanceInMeters / earthRadius;

    final double newLatRad = asin(
      sin(latRad) * cos(distanceRatio) +
          cos(latRad) * sin(distanceRatio) * cos(bearingRad),
    );

    final double newLngRad = lngRad +
        atan2(
          sin(bearingRad) * sin(distanceRatio) * cos(latRad),
          cos(distanceRatio) - sin(latRad) * sin(newLatRad),
        );

    return LatLng(newLatRad * 180 / pi, newLngRad * 180 / pi);
  }


  @override
  Widget build(BuildContext context) {
    canPunchIn = lastPunchIn == null;
    canPunchOut = lastPunchIn != null && lastPunchOut == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Attendance',
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
      ),
      body: loading
          ? Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      )
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column( // Use a Column as the top-level child of SafeArea
            children: [
              Expanded( // Wrap your scrollable content in an Expanded widget
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTodayStatusCard(),
                        const SizedBox(height: 30),
                        _buildActionButtons(),
                        const SizedBox(height: 20),
                        if (processingPunch) _buildProcessingIndicator(),
                        if (currentLocation != null) ...[
                          const SizedBox(height: 20),
                          _buildLocationInfo(),
                        ],
                        // Remove the SizedBox(height: 80) here
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: _buildQuickActionsSection(),
              ),
            ],
          ),
        ),
      ),

    );
  }

  Widget _buildTodayStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Status",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  'Punch In',
                  lastPunchIn != null
                      ? DateFormat('hh:mm a').format(lastPunchIn!)
                      : 'Not marked',
                  Icons.login,
                  lastPunchIn != null ? Colors.green : Colors.grey,
                  subtitle: isLate && lateMinutes > 0
                      ? lateMinutes < 60
                      ? '${lateMinutes}m late'
                      : '${lateMinutes ~/ 60}h ${lateMinutes % 60}m late'
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusItem(
                  'Punch Out',
                  lastPunchOut != null
                      ? DateFormat('hh:mm a').format(lastPunchOut!)
                      : 'Not marked',
                  Icons.logout,
                  lastPunchOut != null ? Colors.orange : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: canPunchIn ? _pulseAnimation.value : 1.0,
                child: _buildActionButton(
                  'Punch In',
                  Icons.login,
                  Colors.green,
                  canPunchIn && !processingPunch,
                      () => _fetchCurrentLocation(true),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: canPunchOut ? _pulseAnimation.value : 1.0,
                child: _buildActionButton(
                  'Punch Out',
                  Icons.logout,
                  Colors.orange,
                  canPunchOut && !processingPunch,
                      () => _fetchCurrentLocation(false),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Processing...',
            style: TextStyle(
              color: Colors.blue.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: locationStatusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: locationStatusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isLocationVerified ? Icons.location_on : Icons.location_off,
            color: locationStatusColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              locationVerificationMessage,
              style: TextStyle(
                color: locationStatusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatusItem(
      String title,
      String value,
      IconData icon,
      Color color, {
        String? subtitle,
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          // Conditionally add subtitle if exists
          // if (subtitle != null && subtitle.isNotEmpty && workSchedule?['schedule_type'] != 'flexible') ...[
          //   const SizedBox(height: 2),
          //   Text(
          //     subtitle,
          //     style: TextStyle(
          //       fontSize: 10,
          //       color: Colors.red.shade700,
          //       fontWeight: FontWeight.w500,
          //     ),
          //   ),
          // ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, bool enabled, VoidCallback onPressed) {
    return SizedBox(
      height: 120,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.shade300,
          foregroundColor: Colors.white,
          elevation: enabled ? 8 : 2,
          shadowColor: color.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: enabled ? Colors.white : Colors.grey.shade500,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: enabled ? Colors.white : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // const Text(
        //   'Quick Actions',
        //   style: TextStyle(
        //     fontSize: 20,
        //     fontWeight: FontWeight.bold,
        //     color: Colors.black87,
        //   ),
        // ),
        // const SizedBox(height: 16),
        Row(
          children: [
            // Attendance Card
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.beach_access, // More relevant than `Icons.speed`
                title: 'Leave Request',
                subtitle: 'Submit Application',
                color: Colors.indigo, // Professional and distinct
                // onTap: () => (),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LeaveApplicationPage(userProfile: AppState().employeeProfile)),
                ).then((_) => fetchAttendanceAndSchedule()),
              ),
            ),
            const SizedBox(width: 12),

            // Network Monitoring Card
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.bar_chart, // Ideal for connectivity/monitoring
                title: 'Summary',
                subtitle: 'Monthly reports',
                color: Colors.teal, // Clean and tech-oriented
                // onTap: () => (),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AttendanceSummaryPage(employeeId: AppState().userId, employeeName: AppState().userName, managerLevel: 0, managerId: '')),
                  // MaterialPageRoute(builder: (_) => AttendanceSummaryPage(employeeId: AppState().userId)),
                ),
              ),
            ),
          ],

        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryNavigationCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.blueAccent.shade200, Colors.blueAccent.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade800.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    // AttendanceSummaryPage(employeeId: AppState().userId, approverLevel: 0,),
                    AttendanceSummaryPage(employeeId: AppState().userId, employeeName: AppState().userName, managerLevel: 0, managerId: '',),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bar_chart, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attendance Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View detailed monthly reports & analytics',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text("Permission Required"),
          ],
        ),
        content: const Text("Location permission is permanently denied. Please enable it from settings to mark attendance."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              AppSettings.openAppSettings();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Open Settings", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showApproximateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.gps_not_fixed, color: Colors.amber.shade600),
            const SizedBox(width: 8),
            const Expanded(child: Text("Precise Location Required")),
          ],
        ),
        content: const Text(
          "Your device is providing approximate location. Please allow precise location access for accurate attendance tracking.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              AppSettings.openAppSettings();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Open Settings", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

}

class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}