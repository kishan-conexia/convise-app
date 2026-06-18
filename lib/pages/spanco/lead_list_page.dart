import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../models/spanco/spanco_lead.dart';
import '../../providers/lead_provider.dart';
import 'lead_detail_page.dart';
import 'lead_form_page.dart';

class LeadListPage extends StatefulWidget {
  const LeadListPage({Key? key}) : super(key: key);

  @override
  State<LeadListPage> createState() => _LeadListPageState();
}

class _LeadListPageState extends State<LeadListPage> {
  late LeadProvider _leadProvider;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _leadProvider = Provider.of<LeadProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _leadProvider.initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: _goToCreateLead,
      //   icon: const Icon(Icons.add),
      //   label: const Text('New Lead'),
      //   backgroundColor: Colors.blue.shade400,
      //   heroTag: 'lead_list_fab',
      // ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppState().bodyGradient,
          ),
          child: Consumer<LeadProvider>(
            builder: (context, provider, _) {
              // ✅ Show SnackBar when messages change
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (provider.successMessage != null) {
                  _showSnackBar(provider.successMessage!, isError: false);
                  provider.clearSuccessMessage(); // Clear after showing
                }
                if (provider.errorMessage != null) {
                  _showSnackBar(provider.errorMessage!, isError: true);
                  provider.clearErrorMessage(); // Clear after showing
                }
              });

              if (provider.isLoading && provider.leads.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                );
              }

              return Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone, or lead #',
                        prefixIcon: Icon(Icons.search, color: Colors.blue.shade600),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            provider.search('');
                            setState(() {});
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
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                        ),
                        counterText: '',
                      ),
                      maxLength: 100,
                      onChanged: (value) {
                        provider.search(value);
                        setState(() {});
                      },
                    ),
                  ),

                  // Active Filters Display
                  if (provider.selectedStage != null ||
                      provider.selectedStatus != null ||
                      provider.selectedAssignee != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            if (provider.selectedStage != null)
                              _FilterChip(
                                label: provider.selectedStage!.label,
                                onRemove: () => provider.setStageFilter(null),
                              ),
                            if (provider.selectedStatus != null)
                              _FilterChip(
                                label: provider.selectedStatus!.label,
                                onRemove: () => provider.setStatusFilter(null),
                              ),
                            if (provider.selectedAssignee != null)
                              _FilterChip(
                                label: 'Assigned',
                                onRemove: () => provider.setAssigneeFilter(null),
                              ),
                            GestureDetector(
                              onTap: () => provider.clearFilters(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Center(
                                  child: Text(
                                    'Clear all',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Lead Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total: ${provider.leads.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          provider.leads.isEmpty
                              ? 'No leads'
                              : 'Showing ${provider.paginatedLeads.length} of ${provider.leads.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Leads List
                  Expanded(
                    child: provider.leads.isEmpty
                        ? _buildEmptyState(provider)
                        : RefreshIndicator(
                      onRefresh: () => _leadProvider.refreshLeads(),
                      color: Colors.blue.shade700,
                      child: ListView.builder(
                        itemCount: provider.paginatedLeads.length,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        itemBuilder: (context, index) {
                          final lead = provider.paginatedLeads[index];
                          return _LeadListItem(
                            lead: lead,
                            onTap: () => _goToDetail(lead),
                            onStageChanged: (newStage) =>
                                _showStageChangeDialog(lead, newStage),
                          );
                        },
                      ),
                    ),
                  ),

                  // Pagination Controls
                  if (provider.totalPages > 1)
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: provider.hasPreviousPage
                                ? () => provider.previousPage()
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Previous page',
                            color: provider.hasPreviousPage
                                ? Colors.blue.shade700
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Page ${provider.currentPage + 1} of ${provider.totalPages}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: provider.hasNextPage
                                ? () => provider.nextPage()
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            tooltip: 'Next page',
                            color: provider.hasNextPage
                                ? Colors.blue.shade700
                                : Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),

                  // ✅ REMOVED: Fixed success/error messages
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }




// ✅ ADD: Navigation method
//   void _goToCreateLead() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => const LeadFormPage(),
//       ),
//     ).then((_) {
//       // Refresh leads after returning
//       _leadProvider.refreshLeads();
//     });
//   }


  // ✅ NEW: Better empty state
  Widget _buildEmptyState(LeadProvider provider) {
    final hasActiveFilters = provider.selectedStage != null ||
        provider.selectedStatus != null ||
        provider.selectedAssignee != null;
    final hasSearchQuery = _searchController.text.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasActiveFilters || hasSearchQuery ? Icons.search_off : Icons.inbox,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            hasActiveFilters || hasSearchQuery
                ? 'No leads match your filters'
                : 'No leads yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasActiveFilters || hasSearchQuery
                ? 'Try adjusting your search or filters'
                : 'Create your first lead to get started',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (hasActiveFilters || hasSearchQuery) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                provider.clearFilters();
                provider.search('');
                setState(() {});
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear all filters'),
            ),
          ],
        ],
      ),
    );
  }

  void _goToDetail(SpancoLead lead) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeadDetailPage(leadId: lead.id!),
      ),
    );
  }

  // ✅ IMPROVED: Better confirmation dialog
  // void _showStageChangeDialog(SpancoLead lead, SpancoStage newStage) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Row(
  //         children: [
  //           Icon(Icons.swap_horiz, color: Colors.blue),
  //           SizedBox(width: 12),
  //           Text('Change Stage'),
  //         ],
  //       ),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             'Move "${lead.customerName}" to a new stage?',
  //             style: const TextStyle(fontWeight: FontWeight.w600),
  //           ),
  //           const SizedBox(height: 12),
  //           _StageTransitionRow(
  //             from: lead.currentStage.label,
  //             to: newStage.label,
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         FilledButton(
  //           onPressed: () async {
  //             Navigator.pop(context);
  //
  //             // ✅ Show loading indicator
  //             ScaffoldMessenger.of(context).showSnackBar(
  //               const SnackBar(
  //                 content: Row(
  //                   children: [
  //                     SizedBox(
  //                       width: 16,
  //                       height: 16,
  //                       child: CircularProgressIndicator(
  //                         strokeWidth: 2,
  //                         valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
  //                       ),
  //                     ),
  //                     SizedBox(width: 12),
  //                     Text('Moving lead...'),
  //                   ],
  //                 ),
  //                 duration: Duration(seconds: 1),
  //               ),
  //             );
  //
  //             await _leadProvider.moveToStage(lead.id!, newStage);
  //
  //             if (mounted) {
  //               ScaffoldMessenger.of(context).showSnackBar(
  //                 SnackBar(
  //                   content: Text('✓ Lead moved to ${newStage.label}'),
  //                   backgroundColor: Colors.green,
  //                 ),
  //               );
  //             }
  //           },
  //           child: const Text('Move'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // ✅ ADD: Check feasibility before moving from Approach to Negotiation
  Future<void> _showStageChangeDialog(SpancoLead lead, SpancoStage newStage) async {
    // ✅ CHECK: If moving from Approach to Negotiation, verify feasibility
    if (lead.currentStage == SpancoStage.approach &&
        newStage == SpancoStage.negotiation) {

      // Check feasibility status
      final feasibilityCheck = await _leadProvider.checkStageMovement(lead.id!);

      if (!feasibilityCheck['canMove']) {
        // ✅ Block stage movement - show feasibility requirement dialog
        _showFeasibilityRequiredDialog(lead, feasibilityCheck);
        return;
      }
    }

    // ✅ Normal stage change dialog
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.blue),
            SizedBox(width: 12),
            Text('Change Stage'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Move "${lead.customerName}" to a new stage?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _StageTransitionRow(
              from: lead.currentStage.label,
              to: newStage.label,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Moving lead...'),
                    ],
                  ),
                  duration: Duration(seconds: 1),
                ),
              );

              await _leadProvider.moveToStage(lead.id!, newStage);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Lead moved to ${newStage.label}'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Move'),
          ),
        ],
      ),
    );
  }

// ✅ ADD: Show feasibility requirement dialog
  void _showFeasibilityRequiredDialog(
      SpancoLead lead,
      Map<String, dynamic> feasibilityCheck,
      ) {
    final status = feasibilityCheck['status'] as String;
    final reason = feasibilityCheck['reason'] as String;
    final requestNumber = feasibilityCheck['requestNumber'] as String?;

    IconData icon;
    Color iconColor;
    String title;
    String actionText;
    VoidCallback? onAction;

    switch (status) {
      case 'no_request':
        icon = Icons.assignment_outlined;
        iconColor = Colors.blue;
        title = 'Feasibility Required';
        actionText = 'Create Feasibility Request';
        onAction = () {
          Navigator.pop(context);
          // Navigate to lead detail where they can create feasibility
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LeadDetailPage(leadId: lead.id!),
            ),
          );
        };
        break;

      case 'pending':
      case 'under_review':
      case 'awaiting_approval':
        icon = Icons.hourglass_empty;
        iconColor = Colors.orange;
        title = 'Feasibility In Progress';
        actionText = 'View Status';
        onAction = () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LeadDetailPage(leadId: lead.id!),
            ),
          );
        };
        break;

      case 'rejected':
        icon = Icons.cancel;
        iconColor = Colors.red;
        title = 'Feasibility Rejected';
        actionText = 'View Details';
        onAction = () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LeadDetailPage(leadId: lead.id!),
            ),
          );
        };
        break;

      case 'cancelled':
        icon = Icons.refresh;
        iconColor = Colors.blue;
        title = 'Feasibility Cancelled';
        actionText = 'Create New Request';
        onAction = () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LeadDetailPage(leadId: lead.id!),
            ),
          );
        };
        break;

      default:
        icon = Icons.error;
        iconColor = Colors.grey;
        title = 'Cannot Move Stage';
        actionText = 'OK';
        onAction = () => Navigator.pop(context);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 18, color: iconColor),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cannot move to Negotiation stage',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              reason,
              style: const TextStyle(fontSize: 14),
            ),
            if (requestNumber != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Request: $requestNumber',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (onAction != null)
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: iconColor,
              ),
              child: Text(actionText),
            ),
        ],
      ),
    );
  }



}

  // now it is in the parent widget
  // void _showFilterMenu() {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (context) => _FilterBottomSheet(
  //       provider: _leadProvider,
  //     ),
  //   );



// =====================================================
// HELPER WIDGETS
// =====================================================

class _LeadListItem extends StatelessWidget {
  final SpancoLead lead;
  final VoidCallback onTap;
  final Function(SpancoStage) onStageChanged;

  const _LeadListItem({
    required this.lead,
    required this.onTap,
    required this.onStageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: lead.currentStage.color,
          child: Text(
            lead.customerName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          lead.customerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              lead.contactPhone,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: lead.currentStage.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lead.currentStage.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: lead.currentStage.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: lead.priority.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lead.priority.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: lead.priority.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Text('View'),
              onTap: onTap,
            ),
            PopupMenuItem(
              child: const Text('Next Stage'),
              onTap: () {
                final nextStageOrder = lead.currentStage.stageOrder + 1;
                final nextStage = SpancoStage.values.firstWhere(
                      (s) => s.stageOrder == nextStageOrder,
                  orElse: () => lead.currentStage,
                );
                if (nextStage != lead.currentStage) {
                  // ✅ Use async callback to handle feasibility check
                  Future.microtask(() => onStageChanged(nextStage));
                }
              },
            ),

            // PopupMenuItem(
            //   child: const Text('Mark as Won'),
            //   onTap: () => _showWinDialog(context),
            // ),
            // if (lead.status == LeadStatus.lost)
            //   PopupMenuItem(
            //     child: const Text('Re-qualify'),
            //     onTap: () {
            //       showDialog(
            //         context: context,
            //         builder: (context) => AlertDialog(
            //           title: const Text('Re-qualify Lead'),
            //           content: Text(
            //             'Re-qualify "${lead.customerName}"?',
            //           ),
            //           actions: [
            //             TextButton(
            //               onPressed: () => Navigator.pop(context),
            //               child: const Text('Cancel'),
            //             ),
            //             FilledButton(
            //               onPressed: () {
            //                 Provider.of<LeadProvider>(context, listen: false)
            //                     .requalifyLostLead(lead.id!);
            //                 Navigator.pop(context);
            //               },
            //               child: const Text('Re-qualify'),
            //             ),
            //           ],
            //         ),
            //       );
            //     },
            //   ),
          ],
        ),
      ),
    );
  }

  // Color _getStageColor() {
  //   switch (lead.currentStage) {
  //     case SpancoStage.suspect:
  //       return Colors.grey;
  //     case SpancoStage.prospect:
  //       return Colors.blue;
  //     case SpancoStage.approach:
  //       return Colors.orange;
  //     case SpancoStage.negotiation:
  //       return Colors.purple;
  //     case SpancoStage.closure:
  //       return Colors.red;
  //     case SpancoStage.order:
  //       return Colors.green;
  //   }
  // }

  // Color _getPriorityColor() {
  //   switch (lead.priority) {
  //     case Priority.low:
  //       return Colors.grey;
  //     case Priority.medium:
  //       return Colors.blue;
  //     case Priority.high:
  //       return Colors.orange;
  //     case Priority.urgent:
  //       return Colors.red;
  //     case Priority.critical:
  //       return Colors.red.shade900;
  //   }
  // }

  void _showWinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Won'),
        content: Text(
          'Mark "${lead.customerName}" as won?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Provider.of<LeadProvider>(context, listen: false)
                  .markAsWon(lead.id!);
              Navigator.pop(context);
            },
            child: const Text('Mark as Won'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 18),
    );
  }
}

// class _FilterBottomSheet extends StatelessWidget {
//   final LeadProvider provider;
//
//   const _FilterBottomSheet({required this.provider});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Text(
//             'Filter Leads',
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//           ),
//           const SizedBox(height: 16),
//           // Stage Filter
//           const Text('By Stage'),
//           Wrap(
//             spacing: 8,
//             children: SpancoStage.values
//                 .map(
//                   (stage) => FilterChip(
//                 label: Text(stage.label),
//                 selected: provider.selectedStage == stage,
//                 onSelected: (selected) {
//                   provider.setStageFilter(selected ? stage : null);
//                   Navigator.pop(context);
//                 },
//               ),
//             )
//                 .toList(),
//           ),
//           const SizedBox(height: 16),
//           // Status Filter
//           const Text('By Status'),
//           Wrap(
//             spacing: 8,
//             children: LeadStatus.values
//                 .map(
//                   (status) => FilterChip(
//                 label: Text(status.label),
//                 selected: provider.selectedStatus == status,
//                 onSelected: (selected) {
//                   provider.setStatusFilter(selected ? status : null);
//                   Navigator.pop(context);
//                 },
//               ),
//             )
//                 .toList(),
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             child: FilledButton(
//               onPressed: () {
//                 provider.clearFilters();
//                 Navigator.pop(context);
//               },
//               child: const Text('Clear All Filters'),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class _SnackBar extends StatelessWidget {
  final String message;
  final bool isError;

  const _SnackBar({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? Colors.red[100] : Colors.green[100],
        border: Border.all(
          color: isError ? Colors.red : Colors.green,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error : Icons.check_circle,
            color: isError ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.red[900] : Colors.green[900],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// =====================================================
// HELPER WIDGETS
// =====================================================

// ✅ NEW: Stage transition visual
class _StageTransitionRow extends StatelessWidget {
  final String from;
  final String to;

  const _StageTransitionRow({
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              from,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Icon(Icons.arrow_forward, size: 20, color: Colors.blue),
          Expanded(
            child: Text(
              to,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.blue[900],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}