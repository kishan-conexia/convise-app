import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/app_state.dart';

class ManagerTeamRequestsPage extends StatefulWidget {
  final String managerId;

  const ManagerTeamRequestsPage({
    Key? key,
    required this.managerId,
  }) : super(key: key);

  @override
  State<ManagerTeamRequestsPage> createState() => _ManagerTeamRequestsPageState();
}

class _ManagerTeamRequestsPageState extends State<ManagerTeamRequestsPage>
    with TickerProviderStateMixin {

  late TabController _tabController;
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';


  List<Map<String, dynamic>> leaveRequests = [];
  List<Map<String, dynamic>> regularizationRequests = [];
  List<Map<String, dynamic>> teamMembers = [];
  bool isLoading = true;

  int pendingLeaveCount = 0;
  int pendingRegularizationCount = 0;

  // Cache for department hierarchy and manager data
  Map<int, Map<String, dynamic>> departmentsCache = {};
  Map<String, int> employeeDepartmentMap = {};

  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

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

    // Add search listener
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Default to current month
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);

    _loadData();
  }


  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {

      await _loadDepartmentHierarchy();
      await _loadTeamMembers();

      // Load requests after we have team members
      await Future.wait([
        _loadLeaveRequests(),
        _loadRegularizationRequests(),
      ]);
    } catch (e) {
      _showError('Error loading data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // NEW METHOD: Load all department hierarchy data once
  Future<void> _loadDepartmentHierarchy() async {
    final allDepartments = await supabase
        .from('departments')
        .select('id, name, manager_id, parent_id')
        .eq('is_active', true);

    // Cache all departments for quick lookup
    for (var dept in allDepartments) {
      departmentsCache[dept['id'] as int] = dept;
    }
  }

  Future<void> _loadTeamMembers() async {
    // Get all departments managed by this manager (including sub-departments)
    final allDepartmentIds = _getAllManagedDepartmentIds(widget.managerId);

    if (allDepartmentIds.isNotEmpty) {
      final membersResponse = await supabase
          .from('profiles')
          .select('''
            id, employee_code, full_name, email, department,
            departments!profiles_department_fkey(id, name),
            positions(designation)
          ''')
          .inFilter('department', allDepartmentIds)
          .eq('is_active', true);

      setState(() {
        teamMembers = List<Map<String, dynamic>>.from(membersResponse);

        // Build employee-department mapping for quick lookup
        for (var member in teamMembers) {
          employeeDepartmentMap[member['id']] = member['department'] as int;
        }
      });
    }
  }

  // OPTIMIZED: Use cached data instead of Supabase calls
  List<int> _getAllManagedDepartmentIds(String managerId) {
    final Set<int> allDepartmentIds = {};

    // Get departments directly managed by this manager
    final directDepartments = departmentsCache.values
        .where((dept) => dept['manager_id'] == managerId)
        .toList();

    final directIds = directDepartments
        .map((dept) => dept['id'] as int)
        .toList();

    allDepartmentIds.addAll(directIds);

    // Recursively get all sub-departments
    _getSubDepartments(directIds, allDepartmentIds);

    return allDepartmentIds.toList();
  }

  // OPTIMIZED: Use cached data instead of Supabase calls
  void _getSubDepartments(List<int> parentIds, Set<int> allIds) {
    if (parentIds.isEmpty) return;

    final subDepartments = departmentsCache.values
        .where((dept) => parentIds.contains(dept['parent_id']))
        .toList();

    final subIds = subDepartments
        .map((dept) => dept['id'] as int)
        .toList();

    if (subIds.isNotEmpty) {
      allIds.addAll(subIds);
      // Recursively get sub-departments of these departments
      _getSubDepartments(subIds, allIds);
    }
  }

  // OPTIMIZED: Calculate approval level using cached data
  int calculateApprovalLevel(String employeeId) {
    try {
      // Get employee's department from cached mapping
      final employeeDepartmentId = employeeDepartmentMap[employeeId];
      if (employeeDepartmentId == null) return 1;

      // Get the hierarchy level using cached data
      int level = _getHierarchyLevelFromCache(employeeDepartmentId, widget.managerId, employeeId);

      return level;
    } catch (e) {
      print('Error calculating approval level: $e');
      return 1; // Default to level 1 if there's an error
    }
  }

  // OPTIMIZED: Use cached department data instead of Supabase calls
  int _getHierarchyLevelFromCache(int employeeDepartmentId, String currentManagerId, String employeeId) {
    int level = 1;
    int currentDepartmentId = employeeDepartmentId;

    while (true) {
      // Get current department details from cache
      final department = departmentsCache[currentDepartmentId];
      if (department == null) break;

      final departmentManagerId = department['manager_id'] as String?;

      // If current department's manager is the current user, return the level
      if (departmentManagerId == currentManagerId) {
        return level;
      }

      if (departmentManagerId == employeeId) {
        level--;
      }

      // If there's a manager but it's not the current user, increment level
      if (departmentManagerId != null) {
        level++;
      }

      // Move to parent department
      final parentId = department['parent_id'] as int?;
      if (parentId == null) break;

      currentDepartmentId = parentId;
    }

    return level;
  }


  Future<void> _loadLeaveRequests() async {
    if (teamMembers.isEmpty) return;

    final teamMemberIds = teamMembers.map((member) => member['id']).toList();

    final start = _startOfMonth(_selectedMonth).toIso8601String();
    final end = _endOfMonth(_selectedMonth).toIso8601String();

    final response = await supabase
        .from('leave_applications')
        .select('''
          *,
          profiles!leave_applications_employee_id_fkey(id, employee_code, full_name, position),
          leave_types(leave_name, leave_code)
        ''')
        .inFilter('employee_id', teamMemberIds)
        .gte('created_at', start)
        .lte('created_at', end)
        .order('created_at', ascending: false);

    setState(() {
      leaveRequests = List<Map<String, dynamic>>.from(response);
      // Calculate pending count
      // pendingLeaveCount = leaveRequests.where((req) => req['status'] == 'pending').length;
      pendingLeaveCount = leaveRequests.where((req) {
        if (req['status'] != 'pending') return false;
        return _doesRequestNeedAction(req);
        // return _isCurrentManagerPendingApprover(req, req['employee_id']);
      }).length;
    });
  }

  Future<void> _loadRegularizationRequests() async {
    if (teamMembers.isEmpty) return;

    final teamMemberIds = teamMembers.map((member) => member['id']).toList();

    final start = _startOfMonth(_selectedMonth).toIso8601String();
    final end = _endOfMonth(_selectedMonth).toIso8601String();

    final response = await supabase
        .from('attendance_regularizations')
        .select('''
          *,
          profiles!attendance_regularizations_employee_id_fkey(id, employee_code, full_name, position)
        ''')
        .inFilter('employee_id', teamMemberIds)
        .gte('created_at', start)
        .lte('created_at', end)
        .order('created_at', ascending: false);

    setState(() {
      regularizationRequests = List<Map<String, dynamic>>.from(response);
      // Calculate pending count
      // pendingRegularizationCount = regularizationRequests.where((req) => req['status'] == 'pending').length;
      pendingRegularizationCount = regularizationRequests.where((req) {
        if (req['status'] != 'pending') return false;
        return _doesRequestNeedAction(req);
        // return _isCurrentManagerPendingApprover(req, req['employee_id']);
      }).length;

    });
  }





  // Helper method to check if a leave request needs action
  bool _doesRequestNeedAction(Map<String, dynamic> leaveApplication) {
    final status = leaveApplication['status'] ?? 'pending';
    final totalLevels = leaveApplication['approval_levels'] ?? 0;
    final employeeId = leaveApplication['employee_id'];

    if (status != 'pending' || totalLevels <= 0) return false;

    final currentManagerLevel = calculateApprovalLevel(employeeId);

    // Don't show action needed if manager level is above approval levels
    if (currentManagerLevel > totalLevels) return false;

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

    return allPreviousLevelsCompleted && isCurrentLevelPending && widget.managerId != employeeId;
  }

// Helper method to sort requests with action-needed items first
  List<Map<String, dynamic>> _sortRequestsByActionNeeded(
      List<Map<String, dynamic>> requests,
      bool Function(Map<String, dynamic>) needsActionChecker
      ) {
    final actionNeeded = <Map<String, dynamic>>[];
    final noActionNeeded = <Map<String, dynamic>>[];

    for (final request in requests) {
      if (needsActionChecker(request)) {
        actionNeeded.add(request);
      } else {
        noActionNeeded.add(request);
      }
    }

    // Sort action needed by created_at (newest first)
    actionNeeded.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
      return bDate.compareTo(aDate);
    });

    // Sort no action needed by created_at (newest first)
    noActionNeeded.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
      return bDate.compareTo(aDate);
    });

    // Return action needed first, then others
    return [...actionNeeded, ...noActionNeeded];
  }



  DateTime _startOfMonth(DateTime month) => DateTime(month.year, month.month, 1);

  DateTime _endOfMonth(DateTime month) {
    final startNext = (month.month == 12)
        ? DateTime(month.year + 1, 1, 1)
        : DateTime(month.year, month.month + 1, 1);
    return startNext.subtract(const Duration(microseconds: 1)); // inclusive
  }

// Format for displaying the current month in UI (optional label)
  String get _selectedMonthLabel {
    return "${_monthName(_selectedMonth.month)} ${_selectedMonth.year}";
  }

  String _monthName(int m) {
    const names = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return names[m - 1];
  }


  Future<void> _selectMonth(BuildContext context) async {
    // Simple month-year picker using showDatePicker constrained to month selection semantics
    final now = DateTime.now();
    final initial = _selectedMonth;
    final firstDate = DateTime(2025, 7); // adjust business constraint if needed
    final lastDate = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      try {
        setState(() => isLoading = true);
        // Normalize to first day of picked month
        final normalized = DateTime(picked.year, picked.month, 1);
        setState(() {
          _selectedMonth = normalized;
        });
        // Reload requests for the new month (keep cached departments/team)
        await Future.wait([
          _loadLeaveRequests(),
          _loadRegularizationRequests(),
        ]);
      } catch (e) {
        debugPrint('Error selecting month: $e');
      } finally {
        setState(() => isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Team Requests', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text(
                _selectedMonthLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),

          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white70,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: AppState().appBarGradient,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 2,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.schedule, size: 20),
                    const SizedBox(width: 8),
                    const Text('Regularizations '),
                    if (pendingRegularizationCount > 0) Text('($pendingRegularizationCount)'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.beach_access, size: 20),
                    const SizedBox(width: 8),
                    const Text('Leave Requests '),
                    if (pendingLeaveCount > 0) Text('($pendingLeaveCount)'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'calendar':
                    _selectMonth(context);
                    break;
                  // case 'filter':
                  //   // _exportToCSV();
                  //   break;
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
                // const PopupMenuItem<String>(
                //   value: 'filter',
                //   child: Row(
                //     children: [
                //       Icon(Icons.filter_alt, size: 20, color: Colors.purple),
                //       SizedBox(width: 8),
                //       Text('Filter by Status'),
                //     ],
                //   ),
                // ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
              gradient: AppState().bodyGradient
          ),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              // Add search bar at the top
              _buildSearchBar(),
              // TabBarView with filtered content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Regularization Requests Tab
                    RefreshIndicator(
                      onRefresh: _loadRegularizationRequests,
                      child: Builder(
                        builder: (context) {
                          // Filter first, then sort
                          final filteredRequests = _filterRegularizationRequests(regularizationRequests);

                          if (filteredRequests.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.schedule, size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No regularization requests found for "$_searchQuery"'
                                        : 'No regularization requests found',
                                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          // Sort filtered requests with action-needed items first
                          final sortedRequests = _sortRequestsByActionNeeded(
                            filteredRequests,
                            _doesRequestNeedAction,
                          );

                          return ListView.builder(
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: sortedRequests.length,
                            itemBuilder: (context, index) =>
                                _buildRegularizationCard(sortedRequests[index]),
                          );
                        },
                      ),
                    ),

                    // Leave Requests Tab
                    RefreshIndicator(
                      onRefresh: _loadLeaveRequests,
                      child: Builder(
                        builder: (context) {
                          // Filter first, then sort
                          final filteredRequests = _filterLeaveRequests(leaveRequests);

                          if (filteredRequests.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.beach_access, size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No leave requests found for "$_searchQuery"'
                                        : 'No leave requests found',
                                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          // Sort filtered requests with action-needed items first
                          final sortedRequests = _sortRequestsByActionNeeded(
                            filteredRequests,
                            _doesRequestNeedAction,
                          );

                          return ListView.builder(
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: sortedRequests.length,
                            itemBuilder: (context, index) =>
                                _buildLeaveCard(sortedRequests[index]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name, status, or request type...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterLeaveRequests(List<Map<String, dynamic>> requests) {
    if (_searchQuery.isEmpty) return requests;

    return requests.where((request) {
      final employee = request['profiles'] as Map<String, dynamic>?;
      final employeeName = employee?['full_name']?.toString().toLowerCase() ?? '';
      final employeeCode = employee?['employee_code']?.toString().toLowerCase() ?? '';
      final status = request['status']?.toString().toLowerCase() ?? '';
      final leaveType = request['leave_types']?['leave_name']?.toString().toLowerCase() ?? '';
      final reason = request['reason']?.toString().toLowerCase() ?? '';

      // Search in multiple fields
      return employeeName.contains(_searchQuery) ||
          employeeCode.contains(_searchQuery) ||
          status.contains(_searchQuery) ||
          leaveType.contains(_searchQuery) ||
          reason.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> _filterRegularizationRequests(List<Map<String, dynamic>> requests) {
    if (_searchQuery.isEmpty) return requests;

    return requests.where((request) {
      final employee = request['profiles'] as Map<String, dynamic>?;
      final employeeName = employee?['full_name']?.toString().toLowerCase() ?? '';
      final employeeCode = employee?['employee_code']?.toString().toLowerCase() ?? '';
      final status = request['status']?.toString().toLowerCase() ?? '';
      final requestType = request['request_type']?.toString().toLowerCase() ?? '';
      final reason = request['reason']?.toString().toLowerCase() ?? '';

      // Search in multiple fields
      return employeeName.contains(_searchQuery) ||
          employeeCode.contains(_searchQuery) ||
          status.contains(_searchQuery) ||
          requestType.contains(_searchQuery) ||
          reason.contains(_searchQuery);
    }).toList();
  }




  Widget _buildLeaveCard(Map<String, dynamic> leaveApplication) {
    final employeeName = leaveApplication['profiles']['full_name'];
    // final employeeCode = leaveApplication['profiles']['employee_code'];
    final status = leaveApplication['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final totalLevels = leaveApplication['approval_levels'] ?? 0;
    final leaveType = leaveApplication['leave_types'];
    final employeeId = leaveApplication['employee_id'];

    // Get department name from teamMembers cache
    String departmentName = 'Unknown Department';
    try {
      final teamMember = teamMembers.firstWhere(
            (member) => member['id'] == employeeId,
        orElse: () => {},
      );

      if (teamMember.isNotEmpty && teamMember['departments'] != null) {
        departmentName = teamMember['departments']['name'] ?? 'Unknown Department';
      }
    } catch (e) {
      print('Error getting department name: $e');
    }

    int approvedLevels = 0;
    bool needsAction = false;

    // Calculate approval progress and check if action is needed
    if (status == 'pending' && totalLevels > 0) {
      final currentManagerLevel = calculateApprovalLevel(employeeId);

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

        needsAction = allPreviousLevelsCompleted && isCurrentLevelPending && widget.managerId != employeeId;
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
        animation: needsAction ? _zoomAnimation : const AlwaysStoppedAnimation(1.0),
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
                                const SizedBox(width: 8),
                                Text(
                                  '($departmentName)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
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


  Future<void> _showLeaveDetails(Map<String, dynamic> leaveApplication) async {

    final employeeId = leaveApplication['employee_id'];

    final level = calculateApprovalLevel(employeeId);

    final statusColor = _getStatusColor(leaveApplication['status'] ?? 'pending');
    final totalLevels = leaveApplication['approval_levels'] ?? 0;
    // final level = widget.managerLevel;
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

    final isEmployee = AppState().userId == employeeId && level < 1;
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
              if ((canApprove || canCancel) && (AppState().userId != employeeId || leaveApplication['profiles']['position'] == 1))  // Add this condition
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (canApprove)  // Existing approval button
                        ElevatedButton.icon(
                          onPressed: () {
                            _showLeaveApprovalDialog(leaveApplication, level);
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

  void _showLeaveApprovalDialog(Map<String, dynamic> leaveApplication, int level) {
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
              'Employee: ${leaveApplication['profiles']['full_name']}',
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
                level,
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
                level,
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
      int level,
      ) async {
    try {

      final now = await AppState().getCurrentTime(); // Assumes device is in IST
      final startTime = DateTime(now.year, now.month, now.day, 6, 0);     // 6:00 AM
      final endTime = DateTime(now.year, now.month, now.day, 23, 30);     // 11:30 PM

      if (now.isBefore(startTime) || now.isAfter(endTime)) {
        _showMessage('Leave approval are allowed only between 6:00 AM and 11:30 PM', isError: true);
        if (mounted) {
          Navigator.pop(context);
        }
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
        'current_level': level,
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
          _showMessage(message, isError: true);
        }
      } else {
        _showMessage('Leave $action successfully');
      }

      // Refresh the leave data
      await _loadLeaveRequests();

    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
      _showMessage('Approval failed: ${e.toString()}', isError: true);
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
        _showMessage('Leave cancellation are allowed only between 6:00 AM and 11:30 PM', isError: true);
        if (mounted) {
          Navigator.pop(context);
        }
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
          await _loadLeaveRequests();
        } else {
          _showMessage(message, isError: true);
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showMessage('Cancellation failed: ${e.toString()}', isError: true);
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






  Widget _buildRegularizationCard(Map<String, dynamic> regularization) {
    final employeeName = regularization['profiles']['full_name'];
    // final employeeCode = regularization['profiles']['employee_code'];
    final status = regularization['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final totalLevels = regularization['approval_levels'] ?? 0;
    final employeeId = regularization['employee_id'];

    // Get department name from teamMembers cache
    String departmentName = 'Unknown Department';
    try {
      final teamMember = teamMembers.firstWhere(
            (member) => member['id'] == employeeId,
        orElse: () => {},
      );

      if (teamMember.isNotEmpty && teamMember['departments'] != null) {
        departmentName = teamMember['departments']['name'] ?? 'Unknown Department';
      }
    } catch (e) {
      print('Error getting department name: $e');
    }

    int approvedLevels = 0;
    bool needsAction = false;

    // Determine needsAction
    if (status == 'pending' && totalLevels > 0) {
      final currentManagerLevel = calculateApprovalLevel(employeeId);

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

        needsAction = allPreviousApproved && isPending && widget.managerId != employeeId;
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
                                const SizedBox(width: 8),
                                Text(
                                  '($departmentName)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
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
                              const SizedBox(height: 8),
                            ],

                            // Reason Section
                            if (regularization['reason'] != null && regularization['reason'].toString().isNotEmpty) ...[
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
                            ],

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


  Future<void> _showRegularizationDetails(Map<String, dynamic> regularization) async {
    final employeeId = regularization['employee_id'];

    final level = calculateApprovalLevel(employeeId);

    final statusColor = _getStatusColor(regularization['status'] ?? 'pending');
    final totalLevels = regularization['approval_levels'] ?? 0;

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

    final isEmployee = AppState().userId == employeeId && level < 1;
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
                if ((canApprove || canCancel) && (AppState().userId != employeeId || regularization['profiles']['position'] == 1))  // Add this condition
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (canApprove)  // Existing approval button
                          ElevatedButton.icon(
                            onPressed: () {
                              _showRegApprovalDialog(regularization, level);
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

  void _showRegApprovalDialog(Map<String, dynamic> regularization, int level) {
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
              'Employee: ${regularization['profiles']['full_name']}',
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
                level,
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
                level,
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
      level,
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
        'current_level': level,
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
          _showMessage(message, isError: true);
        }

        // Refresh UI
        await _loadRegularizationRequests();
      }
    } catch (e) {
      _showMessage('Approval failed: ${e.toString()}', isError: true);
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
        _showMessage('Cancellation are allowed only between 6:00 AM and 11:30 PM', isError: true);
        if (mounted) {
          Navigator.pop(context);
        }
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
          await _loadRegularizationRequests();
        } else {
          _showMessage(message, isError: true);
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
      _showMessage('Cancellation failed: ${e.toString()}', isError: true);
    }
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


  String _formatFinalApprovalDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      return 'Invalid date';
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

  String _formatTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid time';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }


  @override
  void dispose() {
    _tabController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

}