import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../models/app_state.dart';
import 'attendance_summary_page.dart';

class DepartmentPage extends StatefulWidget {
  const DepartmentPage({Key? key}) : super(key: key);

  @override
  State<DepartmentPage> createState() => _DepartmentPageState();
}

class _DepartmentPageState extends State<DepartmentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> managedDepartments = [];
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> subDepartments = [];

  // Cache for department hierarchy data only
  Map<int, Map<String, dynamic>> departmentMap = {};

  bool isLoading = true;
  String selectedDepartmentId = '';
  Map<String, dynamic>? selectedDepartment;
  Map<int, List<Map<String, dynamic>>> allSubDepartments = {};
  Set<int> expandedDepartments = {};
  String searchQuery = '';
  List<Map<String, dynamic>> filteredEmployees = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDepartmentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartmentData() async {
    try {
      setState(() => isLoading = true);

      // Reset data
      managedDepartments = [];
      employees = [];
      subDepartments = [];
      allSubDepartments = {};
      departmentMap = {};

      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Load department hierarchy data first
      await _loadDepartmentHierarchy();

      // Get departments managed by current user from cached data
      managedDepartments = departmentMap.values
          .where((dept) => dept['manager_id'] == currentUser.id && dept['is_active'] == true)
          .toList();

      // Sort managed departments
      managedDepartments.sort((a, b) {
        final levelCompare = (a['level'] as int).compareTo(b['level'] as int);
        if (levelCompare != 0) return levelCompare;
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      if (managedDepartments.isNotEmpty) {
        // Set first department as selected by default
        selectedDepartmentId = managedDepartments.first['id'].toString();
        selectedDepartment = managedDepartments.first;

        await _loadDepartmentDetails();
      }
    } catch (error) {
      print('Error loading department data: $error');
      _showErrorSnackBar('Failed to load department data');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Load all department hierarchy data once
  Future<void> _loadDepartmentHierarchy() async {
    try {
      final allDepts = await supabase
          .from('departments')
          .select('''
            id, name, code, description, level, parent_id, path,
            department_type, service_area, shift_type, cost_center,
            annual_budget, max_headcount, is_active, manager_id
          ''')
          .eq('is_active', true);

      // Cache all departments for quick lookup
      for (var dept in allDepts) {
        departmentMap[dept['id'] as int] = dept;
      }
    } catch (e) {
      print('Error loading department hierarchy: $e');
    }
  }

  // this is the previous method which was working but unable to identify noc team status after 12am
  // Future<void> _loadDepartmentDetails() async {
  //   if (selectedDepartmentId.isEmpty) return;
  //
  //   try {
  //     setState(() {
  //       employees = [];
  //       subDepartments = [];
  //       allSubDepartments = {};
  //     });
  //
  //     final selectedDeptId = int.parse(selectedDepartmentId);
  //
  //     // Get entire department subtree using cached data
  //     final subtree = _getDepartmentSubtreeFromCache(selectedDeptId);
  //     final subtreeIds = subtree.map((d) => d['id'] as int).toList();
  //
  //     // Get employees in all departments in the subtree
  //     final employeesResponse = await supabase
  //         .from('profiles')
  //         .select('''
  //           id, full_name, employee_code, email, phone, avatar_url,
  //           employment_type, date_of_joining, is_active, department, position
  //         ''')
  //         .inFilter('department', subtreeIds)
  //         .eq('is_active', true)
  //         .order('department', ascending: true);
  //
  //     // Get unique position IDs from employees
  //     final positionIds = (employeesResponse as List<dynamic>)
  //         .where((emp) => emp['position'] != null)
  //         .map((emp) => emp['position'])
  //         .toSet()
  //         .toList();
  //
  //     List<Map<String, dynamic>> positions = [];
  //     if (positionIds.isNotEmpty) {
  //       final positionsResponse = await supabase
  //           .from('positions')
  //           .select('id, designation, level')
  //           .inFilter('id', positionIds);
  //       positions = List<Map<String, dynamic>>.from(positionsResponse);
  //     }
  //
  //     // Get employee IDs for attendance check
  //     final employeeIds = (employeesResponse as List<dynamic>)
  //         .map((emp) => emp['id'])
  //         .toList();
  //
  //     // Get today's attendance data for all employees
  //     final today = await AppState().getCurrentTime();
  //     final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  //
  //     List<Map<String, dynamic>> attendanceData = [];
  //     if (employeeIds.isNotEmpty) {
  //       final attendanceResponse = await supabase
  //           .from('attendance')
  //           .select('employee_id, punch_in, punch_out, date')
  //           .inFilter('employee_id', employeeIds)
  //           .eq('date', todayStr);
  //       attendanceData = List<Map<String, dynamic>>.from(attendanceResponse);
  //     }
  //
  //     // Combine employee data with positions and attendance status
  //     employees = employeesResponse.map<Map<String, dynamic>>((emp) {
  //       final position = positions.firstWhere(
  //             (pos) => pos['id'] == emp['position'],
  //         orElse: () => <String, dynamic>{},
  //       );
  //
  //       // Check attendance status
  //       final attendance = attendanceData.firstWhere(
  //             (att) => att['employee_id'] == emp['id'],
  //         orElse: () => <String, dynamic>{},
  //       );
  //
  //       String status = 'inactive';
  //       if (attendance.isNotEmpty) {
  //         final punchIn = attendance['punch_in'];
  //         final punchOut = attendance['punch_out'];
  //
  //         // Employee is active if punch_in is not null and punch_out is null
  //         if (punchIn != null && punchOut == null) {
  //           status = 'active';
  //         }
  //       }
  //
  //       return {
  //         ...emp,
  //         'position_info': position,
  //         'attendance_status': status,
  //       };
  //     }).toList();
  //
  //     filteredEmployees = employees;
  //
  //     // Get direct sub-departments using cached data
  //     subDepartments = await _getDirectSubDepartmentsFromCache(selectedDeptId);
  //     allSubDepartments[selectedDeptId] = subDepartments;
  //
  //     // Recursively load sub-departments from cache
  //     for (var dept in subDepartments) {
  //       await _loadSubDepartmentsRecursiveFromCache(dept['id'] as int);
  //     }
  //
  //     setState(() {});
  //   } catch (error) {
  //     print('Error loading department details: $error');
  //     _showErrorSnackBar('Failed to load department details');
  //   }
  // }

  Future<void> _loadDepartmentDetails() async {
    if (selectedDepartmentId.isEmpty) return;

    try {
      setState(() {
        employees = [];
        subDepartments = [];
        allSubDepartments = {};
      });

      final selectedDeptId = int.parse(selectedDepartmentId);

      // Get entire department subtree using cached data
      final subtree = _getDepartmentSubtreeFromCache(selectedDeptId);
      final subtreeIds = subtree.map((d) => d['id'] as int).toList();

      // Get employees in all departments in the subtree
      final employeesResponse = await supabase
          .from('profiles')
          .select('''
          id, full_name, employee_code, email, phone, avatar_url,
          employment_type, date_of_joining, is_active, department, position
        ''')
          .inFilter('department', subtreeIds)
          .eq('is_active', true)
          .order('department', ascending: true);

      // Get unique position IDs from employees
      final positionIds = (employeesResponse as List<dynamic>)
          .where((emp) => emp['position'] != null)
          .map((emp) => emp['position'])
          .toSet()
          .toList();

      List<Map<String, dynamic>> positions = [];
      if (positionIds.isNotEmpty) {
        final positionsResponse = await supabase
            .from('positions')
            .select('id, designation, level')
            .inFilter('id', positionIds);
        positions = List<Map<String, dynamic>>.from(positionsResponse);
      }

      // Get employee IDs for attendance check
      final employeeIds = (employeesResponse as List<dynamic>)
          .map((emp) => emp['id'])
          .toList();

      // Get today's attendance data for all employees
      final today = await AppState().getCurrentTime();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      List<Map<String, dynamic>> todayAttendanceData = [];

      if (employeeIds.isNotEmpty) {
        // Get today's attendance
        final todayAttendanceResponse = await supabase
            .from('attendance')
            .select('employee_id, punch_in, punch_out, date')
            .inFilter('employee_id', employeeIds)
            .eq('date', todayStr);
        todayAttendanceData = List<Map<String, dynamic>>.from(todayAttendanceResponse);
      }

      // Define special departments that need different status logic
      final specialDepartments = {101, 1011, 1012, 1013};

      // Get employees from special departments who don't have today's attendance
      final todayAttendanceEmployeeIds = todayAttendanceData.map((att) => att['employee_id']).toSet();
      final specialDeptEmployeesWithoutTodayAttendance = (employeesResponse as List<dynamic>)
          .where((emp) =>
      specialDepartments.contains(emp['department'] as int) &&
          !todayAttendanceEmployeeIds.contains(emp['id']))
          .map((emp) => emp['id'])
          .toList();

      // Get yesterday's attendance only for special department employees without today's attendance
      List<Map<String, dynamic>> yesterdayAttendanceData = [];
      if (specialDeptEmployeesWithoutTodayAttendance.isNotEmpty) {
        final yesterday = today.subtract(const Duration(days: 1));
        final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

        final yesterdayAttendanceResponse = await supabase
            .from('attendance')
            .select('employee_id, punch_in, punch_out, date')
            .inFilter('employee_id', specialDeptEmployeesWithoutTodayAttendance)
            .eq('date', yesterdayStr);
        yesterdayAttendanceData = List<Map<String, dynamic>>.from(yesterdayAttendanceResponse);
      }


      // Combine employee data with positions and attendance status
      employees = employeesResponse.map<Map<String, dynamic>>((emp) {
        final position = positions.firstWhere(
              (pos) => pos['id'] == emp['position'],
          orElse: () => <String, dynamic>{},
        );

        final employeeDepartment = emp['department'] as int;
        final isSpecialDepartment = specialDepartments.contains(employeeDepartment);

        // Check today's attendance status
        final todayAttendance = todayAttendanceData.firstWhere(
              (att) => att['employee_id'] == emp['id'],
          orElse: () => <String, dynamic>{},
        );

        String status = 'inactive';

        if (todayAttendance.isNotEmpty) {
          // Today's attendance found
          final punchIn = todayAttendance['punch_in'];
          final punchOut = todayAttendance['punch_out'];

          if (punchIn != null && punchOut == null) {
            status = 'active';
          }
        } else if (isSpecialDepartment) {
          // No today's attendance found for special department employee
          // Check yesterday's attendance
          final yesterdayAttendance = yesterdayAttendanceData.firstWhere(
                (att) => att['employee_id'] == emp['id'],
            orElse: () => <String, dynamic>{},
          );

          if (yesterdayAttendance.isNotEmpty) {
            final yesterdayPunchIn = yesterdayAttendance['punch_in'];
            final yesterdayPunchOut = yesterdayAttendance['punch_out'];

            if (yesterdayPunchIn != null && yesterdayPunchOut == null) {
              // Parse the punch_in time and check if 12 hours have passed
              try {
                final punchInTime = DateTime.parse(yesterdayPunchIn);
                final timeDifference = today.difference(punchInTime);

                // If less than 12 hours have passed, consider as active
                if (timeDifference.inHours < 13) {
                  status = 'active';
                }
              } catch (e) {
                print('Error parsing punch_in time: $e');
              }
            }
          }
        }

        return {
          ...emp,
          'position_info': position,
          'attendance_status': status,
        };
      }).toList();

      filteredEmployees = employees;

      // Get direct sub-departments using cached data
      subDepartments = await _getDirectSubDepartmentsFromCache(selectedDeptId);
      allSubDepartments[selectedDeptId] = subDepartments;

      // Recursively load sub-departments from cache
      for (var dept in subDepartments) {
        await _loadSubDepartmentsRecursiveFromCache(dept['id'] as int);
      }

      setState(() {});
    } catch (error) {
      print('Error loading department details: $error');
      _showErrorSnackBar('Failed to load department details');
    }
  }

  // OPTIMIZED: Get department subtree from cached data
  List<Map<String, dynamic>> _getDepartmentSubtreeFromCache(int rootId) {
    final List<Map<String, dynamic>> subtree = [];
    final Set<int> visited = {};

    void collectSubtree(int deptId) {
      if (visited.contains(deptId)) return;
      visited.add(deptId);

      final dept = departmentMap[deptId];
      if (dept != null) {
        subtree.add(dept);

        // Find all children of this department
        final children = departmentMap.values
            .where((d) => d['parent_id'] == deptId)
            .toList();

        for (var child in children) {
          collectSubtree(child['id'] as int);
        }
      }
    }

    collectSubtree(rootId);

    // Sort by level
    subtree.sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));

    return subtree;
  }

  // OPTIMIZED: Get direct sub-departments from cached data with manager info
  Future<List<Map<String, dynamic>>> _getDirectSubDepartmentsFromCache(int parentId) async {
    final directSubs = departmentMap.values
        .where((dept) => dept['parent_id'] == parentId && dept['is_active'] == true)
        .toList();

    // Get unique manager IDs for these departments
    final managerIds = directSubs
        .where((dept) => dept['manager_id'] != null)
        .map((dept) => dept['manager_id'] as String)
        .toSet()
        .toList();

    // Fetch manager details for all needed managers in one query
    List<Map<String, dynamic>> managers = [];
    if (managerIds.isNotEmpty) {
      final managersResponse = await supabase
          .from('profiles')
          .select('id, full_name, employee_code')
          .inFilter('id', managerIds);
      managers = List<Map<String, dynamic>>.from(managersResponse);
    }

    // Combine department data with manager info
    return directSubs.map<Map<String, dynamic>>((dept) {
      final manager = managers.firstWhere(
            (mgr) => mgr['id'] == dept['manager_id'],
        orElse: () => <String, dynamic>{},
      );
      return {
        ...dept,
        'manager_info': manager,
      };
    }).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  }

  // OPTIMIZED: Load sub-departments recursively from cached data
  Future<void> _loadSubDepartmentsRecursiveFromCache(int parentId) async {
    final subDepts = await _getDirectSubDepartmentsFromCache(parentId);
    if (subDepts.isEmpty) return;

    allSubDepartments[parentId] = subDepts;

    for (var dept in subDepts) {
      await _loadSubDepartmentsRecursiveFromCache(dept['id'] as int);
    }
  }

  // Helper method to get department name from cache
  String _getDepartmentName(int deptId) {
    return departmentMap[deptId]?['name'] ?? 'Unknown Department';
  }

  void _toggleDepartmentExpansion(int deptId) {
    setState(() {
      if (expandedDepartments.contains(deptId)) {
        expandedDepartments.remove(deptId);
      } else {
        expandedDepartments.add(deptId);
      }
    });
  }

  void _filterEmployees(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredEmployees = employees;
      } else {
        filteredEmployees = employees.where((employee) {
          final name = employee['full_name']?.toLowerCase() ?? '';
          final code = employee['employee_code']?.toLowerCase() ?? '';
          final email = employee['email']?.toLowerCase() ?? '';
          final position = employee['position_info']?['designation']?.toLowerCase() ?? '';

          // Get department name from cached departmentMap
          final departmentId = employee['department'] as int?;
          final departmentName = departmentId != null
              ? (departmentMap[departmentId]?['name']?.toLowerCase() ?? '')
              : '';
          final departmentCode = departmentId != null
              ? (departmentMap[departmentId]?['code']?.toLowerCase() ?? '')
              : '';

          final searchLower = query.toLowerCase().trim();

          return name.contains(searchLower) ||
              code.contains(searchLower) ||
              email.contains(searchLower) ||
              position.contains(searchLower) ||
              departmentName.contains(searchLower) ||
              departmentCode.contains(searchLower);
        }).toList();
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Color _getDepartmentTypeColor(String? type) {
    switch (type) {
      case 'executive':
        return Colors.purple;
      case 'operational':
        return Colors.blue;
      case 'technical':
        return Colors.green;
      case 'customer_facing':
        return Colors.orange;
      case 'support':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getDepartmentTypeIcon(String? type) {
    switch (type) {
      case 'executive':
        return Icons.business_center;
      case 'operational':
        return Icons.settings;
      case 'technical':
        return Icons.engineering;
      case 'customer_facing':
        return Icons.people;
      case 'support':
        return Icons.support_agent;
      default:
        return Icons.corporate_fare;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Department Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppState().appBarGradient,
          ),
        ),
        bottom: managedDepartments.isNotEmpty
            ? TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.account_tree), text: 'Structure'),
            Tab(icon: Icon(Icons.people), text: 'Team'),
          ],
        ) : null,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
              gradient: AppState().bodyGradient
          ),
          child: isLoading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          )
              : managedDepartments.isEmpty
              ? _buildEmptyState()
              : Column(
            children: [
              _buildDepartmentSelector(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildStructureTab(),
                    _buildTeamTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.corporate_fare_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Departments Assigned',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are not assigned as a manager to any department.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentSelector() {
    if (managedDepartments.length <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButton<String>(
        value: selectedDepartmentId,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue.shade600),
        hint: const Text('Select Department'),
        items: managedDepartments.map((dept) {
          return DropdownMenuItem<String>(
            value: dept['id'].toString(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getDepartmentTypeColor(dept['department_type'])
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getDepartmentTypeIcon(dept['department_type']),
                    size: 20,
                    color: _getDepartmentTypeColor(dept['department_type']),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dept['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        dept['code'],
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              selectedDepartmentId = newValue;
              selectedDepartment = managedDepartments.firstWhere(
                    (dept) => dept['id'].toString() == newValue,
              );
              expandedDepartments.clear();
            });
            _loadDepartmentDetails();
          }
        },
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDepartmentOverviewCard(),
          const SizedBox(height: 16),
          _buildStatsCards(),
        ],
      ),
    );
  }

  Widget _buildStructureTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildSubDepartmentsHierarchy(),
    );
  }

  Widget _buildTeamTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _buildEmployeesList(),
        ),
      ],
    );
  }

  Widget _buildDepartmentOverviewCard() {
    if (selectedDepartment == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getDepartmentTypeColor(selectedDepartment!['department_type'])
                  .withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getDepartmentTypeColor(
                        selectedDepartment!['department_type']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getDepartmentTypeIcon(
                        selectedDepartment!['department_type']),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedDepartment!['name'],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        selectedDepartment!['code'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      // --- FIX 1: Adjust childAspectRatio to give more vertical space ---
      childAspectRatio: 1.8, // A common value for 2-line info items. You can experiment: 1.5 to 2.5
      // ------------------------------------------------------------------
      crossAxisSpacing: 16,
      mainAxisSpacing: 12,
      children: [
        _buildInfoItem('Type',
            selectedDepartment!['department_type']?.toString().replaceAll(
                '_', ' ').toUpperCase() ?? 'N/A'),
        _buildInfoItem('Level', selectedDepartment!['level'].toString()),
        _buildInfoItem(
            'Service Area', selectedDepartment!['service_area'] ?? 'N/A'),
        _buildInfoItem('Shift Type',
            selectedDepartment!['shift_type']?.toString()
                .replaceAll('_', ' ')
                .toUpperCase() ?? 'N/A'),
        _buildInfoItem(
            'Cost Center', selectedDepartment!['cost_center'] ?? 'N/A'),
        _buildInfoItem('Max Headcount',
            selectedDepartment!['max_headcount']?.toString() ?? 'N/A'),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Team Members',
            employees.length.toString(),
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Sub Departments',
            subDepartments.length.toString(),
            Icons.account_tree,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: TextField(
        onChanged: _filterEmployees,
        decoration: InputDecoration(
          hintText: 'Search employees...',
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          // suffixIcon: searchQuery.isNotEmpty
          //     ? IconButton(
          //   icon: const Icon(Icons.clear),
          //   onPressed: () => _filterEmployees(''),
          // ) : null,
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
    );
  }

  Widget _buildSubDepartmentsHierarchy() {
    final rootId = int.parse(selectedDepartmentId);
    final rootDept = allSubDepartments[rootId] ?? [];

    if (rootDept.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Sub-departments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                'This department has no sub-departments.',
                style: TextStyle(
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Department Structure',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ..._buildHierarchyLevel(rootId, 0),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHierarchyLevel(int parentId, int depth) {
    final depts = allSubDepartments[parentId] ?? [];
    if (depts.isEmpty) return [];

    return depts.map((dept) {
      final deptId = dept['id'] as int;
      final hasChildren = (allSubDepartments[deptId]?.isNotEmpty ?? false);
      final isExpanded = expandedDepartments.contains(deptId);

      return Container(
        margin: EdgeInsets.only(left: depth * 24.0, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDepartmentItem(dept, hasChildren, isExpanded, deptId),
            if (isExpanded && hasChildren)
              ..._buildHierarchyLevel(deptId, depth + 1),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildDepartmentItem(Map<String, dynamic> dept,
      bool hasChildren,
      bool isExpanded,
      int deptId,) {
    final manager = dept['manager_info'];
    final departmentType = dept['department_type'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getDepartmentTypeColor(departmentType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getDepartmentTypeIcon(departmentType),
            size: 20,
            color: _getDepartmentTypeColor(departmentType),
          ),
        ),
        title: Text(
          dept['name'],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${dept['code']} • Level ${dept['level']}'),
            if (manager != null && manager.isNotEmpty)
              Text(
                'Manager: ${manager['full_name']}',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        onExpansionChanged: hasChildren
            ? (expanded) => _toggleDepartmentExpansion(deptId)
            : null,
        children: hasChildren ? [] : const [],
      ),
    );
  }

  Widget _buildEmployeesList() {
    // Calculate active employees count
    final activeCount = filteredEmployees.where((emp) => emp['attendance_status'] == 'active').length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
              color: Colors.blue.shade50,
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Team Members (${filteredEmployees.length})',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      color: Colors.green.shade600,
                      size: 8,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$activeCount Active',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredEmployees.isEmpty
                ? _buildEmptyEmployeeState()
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredEmployees.length,
              itemBuilder: (context, index) {
                return _buildEmployeeCard(filteredEmployees[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyEmployeeState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isNotEmpty ? 'No employees found' : 'No team members',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            searchQuery.isNotEmpty
                ? 'Try adjusting your search criteria'
                : 'This department has no team members yet.',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> employee) {
    final positionInfo = employee['position_info'] as Map<String, dynamic>?;
    final departmentName = departmentMap[employee['department']]?['name'] ?? 'Unknown Department';
    final attendanceStatus = employee['attendance_status'] as String? ?? 'inactive';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _showEmployeeDetails(employee);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: employee['avatar_url'] != null
                      ? NetworkImage(employee['avatar_url'])
                      : null,
                  child: employee['avatar_url'] == null
                      ? Icon(
                    Icons.person,
                    color: Colors.blue.shade600,
                    size: 24,
                  )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee['full_name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        employee['employee_code'] ?? 'No Code',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (positionInfo != null && positionInfo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          positionInfo['designation'] ?? 'No Position',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        departmentName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: attendanceStatus == 'active'
                            ? Colors.green.shade100
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            attendanceStatus == 'active'
                                ? Icons.circle
                                : Icons.circle_outlined,
                            size: 8,
                            color: attendanceStatus == 'active'
                                ? Colors.green.shade700
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            attendanceStatus == 'active' ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: attendanceStatus == 'active'
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
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
      ),
    );
  }

  void _showEmployeeDetails(Map<String, dynamic> employee) {
    final positionInfo = employee['position_info'] as Map<String, dynamic>?;
    final departmentName = departmentMap[employee['department']]?['name'] ?? 'Unknown Department';
    final employeeId = employee['id'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        // CORRECT: BoxDecoration only contains styling properties
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // CORRECT: Column is the direct child of Container
        child: Column(
          children: [
            // Top drag indicator
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
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
                    // Employee header with avatar
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage: employee['avatar_url'] != null
                              ? NetworkImage(employee['avatar_url'])
                              : null,
                          child: employee['avatar_url'] == null
                              ? Icon(
                            Icons.person,
                            color: Colors.blue.shade600,
                            size: 32,
                          )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee['full_name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                employee['employee_code'] ?? 'No Code',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (positionInfo != null && positionInfo.isNotEmpty)
                                Text(
                                  positionInfo['designation'] ?? 'No Position',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Contact information section
                    _buildDetailSection('Contact Information', [
                      _buildDetailItem(
                          'Email', employee['email'] ?? 'Not provided'),
                      _buildDetailItem(
                          'Phone', employee['phone'] ?? 'Not provided'),
                    ]),
                    const SizedBox(height: 20),

                    // Employment details section
                    _buildDetailSection('Employment Details', [
                      _buildDetailItem('Department', departmentName),
                      _buildDetailItem('Employment Type',
                          employee['employment_type'] ?? 'Unknown'),
                      _buildDetailItem('Date of Joining',
                          employee['date_of_joining'] ?? 'Not provided'),
                      if (positionInfo != null && positionInfo['level'] != null)
                        _buildDetailItem('Level', positionInfo['level']),
                    ]),
                  ],
                ),
              ),
            ),

            // Attendance summary button
            if (AppState().userId != employee['id'] || positionInfo?['id'] == 1)
              Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final currentUser = supabase.auth.currentUser;
                        if (currentUser == null) return;

                        final chain = await _getManagerChain(employeeId!);
                        final managerLevel = chain['count'] + 1;

                        Navigator.pop(context);  // Close bottom sheet

                        _navigateToAttendanceSummary(
                          employeeId,
                          employee['full_name'] ?? 'Unknown Employee',
                          managerLevel,
                          currentUser.id,  // Pass current user ID
                        );
                      },
                      icon: const Icon(Icons.calendar_today, size: 20),
                      label: const Text('View Attendance Summary'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Inside _showEmployeeDetails, after the attendance button
                  // const SizedBox(width: 10),
                  // Expanded(
                  //   child: ElevatedButton.icon(
                  //     onPressed: () async {
                  //       final chain = await _getManagerChain(employeeId!);
                  //       showDialog(
                  //         context: context,
                  //         builder: (context) => AlertDialog(
                  //           title: Text('Manager Chain'),
                  //           content: Column(
                  //             mainAxisSize: MainAxisSize.min,
                  //             crossAxisAlignment: CrossAxisAlignment.start,
                  //             children: [
                  //               Text('Total managers between: ${chain['count']}'),
                  //               const SizedBox(height: 10),
                  //               if (chain['count'] > 0) ...[
                  //                 Text('Managers in chain:'),
                  //                 const SizedBox(height: 5),
                  //                 ...chain['names'].map<Widget>((name) =>
                  //                     Text('• $name')).toList(),
                  //               ] else
                  //                 Text('No managers between you and this employee'),
                  //             ],
                  //           ),
                  //           actions: [
                  //             TextButton(
                  //               onPressed: () => Navigator.pop(context),
                  //               child: Text('OK'),
                  //             )
                  //           ],
                  //         ),
                  //       );
                  //     },
                  //     icon: Icon(Icons.account_tree, size: 20),
                  //     label: Text('Manager Chain'),
                  //     style: ElevatedButton.styleFrom(
                  //       padding: const EdgeInsets.symmetric(vertical: 16),
                  //       backgroundColor: Colors.green.shade700,
                  //       foregroundColor: Colors.white,
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Navigation method to attendance summary page
  void _navigateToAttendanceSummary(
      String employeeId,
      String employeeName,
      int managerLevel,
      String managerId,  // New parameter
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceSummaryPage(
          employeeId: employeeId,
          employeeName: employeeName,
          managerLevel: managerLevel,
          managerId: managerId,  // Pass to next screen
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getManagerChain(String employeeId) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return {'chain': [], 'count': 0};

    // Find employee in prefetched data
    final employee = employees.firstWhere(
          (e) => e['id'] == employeeId,
      orElse: () => {},
    );

    if (employee.isEmpty || employee['department'] == null) {
      return {'chain': [], 'count': 0};
    }

    int? currentDeptId = employee['department'] as int?;
    final String employeeUserId = employee['id'] as String;
    List<String> managerNames = [];
    List<String> managerIds = [];

    // Traverse departments upward using prefetched data
    while (currentDeptId != null) {
      final dept = departmentMap[currentDeptId];
      if (dept == null) break;

      final managerId = dept['manager_id'] as String?;

      // Skip conditions
      if (managerId != null &&
          managerId != currentUser.id &&
          managerId != employeeUserId) {

        // Get manager name from prefetched employees
        final manager = employees.firstWhere(
              (e) => e['id'] == managerId,
          orElse: () => {},
        );

        managerNames.add(manager['full_name'] ?? 'Unknown Manager');
        managerIds.add(managerId);
      }

      // Break if reached current user
      if (managerId == currentUser.id) break;

      // Move to parent department
      currentDeptId = dept['parent_id'] as int?;
    }

    return {
      'ids': managerIds,
      'names': managerNames,
      'count': managerIds.length,
    };
  }

  Widget _buildDetailSection(String title, List<Widget> items) {
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
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
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
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}