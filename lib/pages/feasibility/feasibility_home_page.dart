// lib/pages/feasibility/feasibility_home_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../models/spanco/feasibility/feasibility_request.dart';
import '../../providers/feasibility_provider.dart';
import 'feasibility_list_page.dart';

class FeasibilityHomePage extends StatefulWidget {
  final bool isPendingView; // Show only pending requests for manager

  const FeasibilityHomePage({
    Key? key,
    this.isPendingView = false,
  }) : super(key: key);

  @override
  State<FeasibilityHomePage> createState() => _FeasibilityHomePageState();
}

class _FeasibilityHomePageState extends State<FeasibilityHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late FeasibilityProvider _feasibilityProvider;

  @override
  void initState() {
    super.initState();
    _feasibilityProvider =
        Provider.of<FeasibilityProvider>(context, listen: false);

    // Initialize with 2 tabs if manager view
    final tabCount = widget.isPendingView ? 2 : 1;
    _tabController = TabController(length: tabCount, vsync: this);

    // ✅ Load both datasets at once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isPendingView) {
        // Manager view: Load both datasets
        _feasibilityProvider.loadBothDatasets().then((_) {
          // Set initial view to pending
          _feasibilityProvider.switchViewMode(ViewMode.pending);
        });
      } else {
        // Regular view: Load only all requests
        _feasibilityProvider.initialize();
      }
    });

    // ✅ Listen to tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });
  }

  // ✅ Handle tab switch without reloading
  void _onTabChanged(int index) {
    if (index == 0) {
      // Pending Review tab
      _feasibilityProvider.switchViewMode(ViewMode.pending);
    } else {
      // All Requests tab
      _feasibilityProvider.switchViewMode(ViewMode.all);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.isPendingView
              ? 'Feasibility Review'
              : 'Feasibility Requests',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppState().appBarGradient,
          ),
        ),
        bottom: widget.isPendingView
            ? TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions),
              text: 'Pending Review',
            ),
            Tab(
              icon: Icon(Icons.list),
              text: 'All Requests',
            ),
          ],
        )
            : null,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.refresh),
          //   tooltip: 'Refresh',
          //   color: Colors.white,
          //   onPressed: () {
          //     // ✅ Refresh both datasets if in manager view
          //     if (widget.isPendingView) {
          //       _feasibilityProvider.loadBothDatasets().then((_) {
          //         // Restore current view mode
          //         final currentIndex = _tabController.index;
          //         _feasibilityProvider.switchViewMode(
          //             currentIndex == 0 ? ViewMode.pending : ViewMode.all
          //         );
          //       });
          //     } else {
          //       _feasibilityProvider.refreshRequests();
          //     }
          //   },
          // ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            color: Colors.white,
            onPressed: _showFilterMenu,
          ),
          // if (widget.isPendingView)
          //   IconButton(
          //     icon: const Icon(Icons.info_outline),
          //     tooltip: 'Help',
          //     color: Colors.white,
          //     onPressed: _showHelpDialog,
          //   ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppState().bodyGradient,
          ),
          child: widget.isPendingView
              ? TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // ✅ Prevent swipe
            children: const [
              FeasibilityListPage(),
              FeasibilityListPage(),
            ],
          )
              : const FeasibilityListPage(),
        ),
      ),
    );
  }


  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterBottomSheet(
        provider: _feasibilityProvider,
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feasibility Review Guide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your Role:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Review feasibility requests from sales team and determine if they are technically and commercially feasible.',
              ),
              SizedBox(height: 16),
              Text(
                'Review Process:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('1. Check service location and requirements'),
              Text('2. Evaluate primary connectivity route'),
              Text('3. Evaluate secondary route (if applicable)'),
              Text('4. Fill cost items breakdown'),
              Text('5. Conduct site survey (if needed)'),
              Text('6. Approve or reject with remarks'),
              SizedBox(height: 16),
              Text(
                'Impact:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                '• Approved: Lead can move to Negotiation stage\n'
                    '• Rejected: Lead stays in Approach stage',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// FILTER BOTTOM SHEET
// =====================================================

class _FilterBottomSheet extends StatelessWidget {
  final FeasibilityProvider provider;

  const _FilterBottomSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with close button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Requests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // By Status
                  Text(
                    'By Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FeasibilityStatus.values
                        .map(
                          (status) => FilterChip(
                        label: Text(status.label),
                        selected: provider.selectedStatus == status,
                        onSelected: (selected) {
                          provider.setStatusFilter(selected ? status : null);
                          Navigator.pop(context);
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue.shade700,
                        labelStyle: TextStyle(
                          color: provider.selectedStatus == status
                              ? Colors.blue.shade700
                              : Colors.grey.shade700,
                          fontWeight: provider.selectedStatus == status
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: provider.selectedStatus == status
                                ? Colors.blue.shade700
                                : Colors.grey.shade300,
                            width: provider.selectedStatus == status ? 1.5 : 1,
                          ),
                        ),
                      ),
                    )
                        .toList(),
                  ),
                  const SizedBox(height: 24),

                  // By Urgency
                  Text(
                    'By Urgency',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['low', 'normal', 'high', 'urgent']
                        .map(
                          (urgency) => FilterChip(
                        label: Text(urgency[0].toUpperCase() + urgency.substring(1)),
                        selected: provider.selectedUrgency == urgency,
                        onSelected: (selected) {
                          provider.setUrgencyFilter(selected ? urgency : null);
                          Navigator.pop(context);
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue.shade700,
                        labelStyle: TextStyle(
                          color: provider.selectedUrgency == urgency
                              ? Colors.blue.shade700
                              : Colors.grey.shade700,
                          fontWeight: provider.selectedUrgency == urgency
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: provider.selectedUrgency == urgency
                                ? Colors.blue.shade700
                                : Colors.grey.shade300,
                            width: provider.selectedUrgency == urgency ? 1.5 : 1,
                          ),
                        ),
                      ),
                    )
                        .toList(),
                  ),
                  const SizedBox(height: 24),

                  // Quick Filters
                  Text(
                    'Quick Filters',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        provider.setUrgencyFilter('urgent');
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.priority_high, size: 18),
                      label: const Text(
                        'Urgent Only',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade700, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Clear All
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        provider.clearFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Clear All Filters',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Safe area padding at bottom
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

