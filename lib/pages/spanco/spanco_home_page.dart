import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import 'lead_list_page.dart';
import 'pipeline_page.dart';
import 'activity_page.dart';
import 'lead_form_page.dart';
import '../../providers/lead_provider.dart';
import '../../models/spanco/spanco_lead.dart';

class SpancoHomePage extends StatefulWidget {
  const SpancoHomePage({Key? key}) : super(key: key);

  @override
  State<SpancoHomePage> createState() => _SpancoHomePageState();
}

class _SpancoHomePageState extends State<SpancoHomePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late LeadProvider _leadProvider;

  // ✅ NEW: Sort state
  String _currentSort = 'date_desc';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _leadProvider = Provider.of<LeadProvider>(context, listen: false);

    // Listen to tab changes to update AppBar
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide filter button
    });
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
        title: const Text(
          'LMS',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Leads'),
            Tab(icon: Icon(Icons.dashboard), text: 'Pipeline'),
            Tab(icon: Icon(Icons.history), text: 'Activity'),
          ],
        ),
        actions: [
          // ✅ Show "New Lead" button only on Leads tab
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'New Lead',
              color: Colors.white,
              onPressed: _goToCreateLead,
            ),
          // ✅ NEW: Show sort button only on Leads tab
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort',
              color: Colors.white,
              onPressed: _showSortMenu,
            ),
          // ✅ Show filter button only on Leads tab
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Filter',
              color: Colors.white,
              onPressed: _showFilterMenu,
            ),
        ],

      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppState().bodyGradient,
          ),
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // ✅ Prevent swipe
            children: const [
              LeadListPage(),
              PipelinePage(),
              ActivityPage(),
            ],
          ),
        ),
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: _goToCreateLead,
      //   icon: const Icon(Icons.add),
      //   label: const Text('New Lead'),
      //   backgroundColor: Colors.blue.shade700,
      //   heroTag: 'spanco_fab_create',
      // ),
    );
  }


  void _refreshCurrentTab() {
    switch (_tabController.index) {
      case 0: // Leads
        _leadProvider.refreshLeads();
        break;
      case 1: // Pipeline
        _leadProvider.refreshLeads();
        break;
      case 2: // Activity
        _leadProvider.refreshLeads();
        break;
    }
  }

  void _goToCreateLead() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LeadFormPage(),
      ),
    ).then((_) {
      // Refresh leads after returning
      _leadProvider.refreshLeads();
    });
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterBottomSheet(provider: _leadProvider),
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ✅ NEW: Allow custom height
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7, // ✅ Takes 70% of screen initially
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (fixed, not scrollable)
              Row(
                children: [
                  const Icon(Icons.sort, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Text(
                    'Sort Leads By',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),

              // ✅ Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Priority Section
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        'Priority',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    _buildSortOption(
                      value: 'priority_high',
                      title: 'High to Low',
                      subtitle: 'Critical → High → Medium → Low',
                      icon: Icons.priority_high,
                      iconColor: Colors.red,
                    ),
                    _buildSortOption(
                      value: 'priority_low',
                      title: 'Low to High',
                      subtitle: 'Low → Medium → High → Critical',
                      icon: Icons.low_priority,
                      iconColor: Colors.green,
                    ),

                    const Divider(),

                    // Date Section
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        'Date Created',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    _buildSortOption(
                      value: 'date_desc',
                      title: 'Newest First',
                      subtitle: 'Recently created leads on top',
                      icon: Icons.calendar_today,
                      iconColor: Colors.blue,
                    ),
                    _buildSortOption(
                      value: 'date_asc',
                      title: 'Oldest First',
                      subtitle: 'Find neglected leads',
                      icon: Icons.history,
                      iconColor: Colors.orange,
                    ),

                    const Divider(),

                    // Other Options
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        'Other',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    _buildSortOption(
                      value: 'name_asc',
                      title: 'Customer Name (A-Z)',
                      subtitle: 'Alphabetical order',
                      icon: Icons.sort_by_alpha,
                      iconColor: Colors.purple,
                    ),
                    _buildSortOption(
                      value: 'value_desc',
                      title: 'Estimated Value (High-Low)',
                      subtitle: 'Largest deals first',
                      icon: Icons.attach_money,
                      iconColor: Colors.green,
                    ),
                    _buildSortOption(
                      value: 'stage_order',
                      title: 'Pipeline Stage',
                      subtitle: 'Suspect → Order progression',
                      icon: Icons.timeline,
                      iconColor: Colors.indigo,
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  /// ✅ NEW: Build sort option item
  Widget _buildSortOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _currentSort == value;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.blue : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blue)
          : null,
      selected: isSelected,
      selectedTileColor: Colors.blue.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: () {
        setState(() {
          _currentSort = value;
        });
        _applySorting();
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sorted by: $title'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  /// ✅ NEW: Apply sorting to leads
  void _applySorting() {
    _leadProvider.sortLeads(_currentSort);
  }



}

// ✅ Filter bottom sheet widget
class _FilterBottomSheet extends StatelessWidget {
  final LeadProvider provider;

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
                  'Filter Leads',
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
                  // Stage Filter
                  Text(
                    'By Stage',
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
                    children: SpancoStage.values
                        .where((stage) =>
                    stage != SpancoStage.won &&
                        stage != SpancoStage.lost) // ✅ Exclude Won and Lost
                        .map(
                          (stage) => FilterChip(
                        label: Text(stage.label),
                        selected: provider.selectedStage == stage,
                        onSelected: (selected) {
                          provider.setStageFilter(selected ? stage : null);
                          Navigator.pop(context);
                        },
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue.shade700,
                        labelStyle: TextStyle(
                          color: provider.selectedStage == stage
                              ? Colors.blue.shade700
                              : Colors.grey.shade700,
                          fontWeight: provider.selectedStage == stage
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
                            color: provider.selectedStage == stage
                                ? Colors.blue.shade700
                                : Colors.grey.shade300,
                            width: provider.selectedStage == stage ? 1.5 : 1,
                          ),
                        ),
                      ),
                    )
                        .toList(),
                  ),
                  const SizedBox(height: 24),

                  // Status Filter
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
                    children: LeadStatus.values
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

                  // Clear all button
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
