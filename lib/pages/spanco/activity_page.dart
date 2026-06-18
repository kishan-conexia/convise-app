import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../models/spanco/spanco_lead.dart';
import '../../providers/lead_provider.dart';
import 'lead_detail_page.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({Key? key}) : super(key: key);

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  late LeadProvider _leadProvider;
  String _selectedFilter = 'all'; // all, created, updated, moved, won, lost

  @override
  void initState() {
    super.initState();
    _leadProvider = Provider.of<LeadProvider>(context, listen: false);

    // ✅ Load leads on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActivity();
    });
  }

  // ✅ ADD: Separate load method for refresh
  Future<void> _loadActivity() async {
    await _leadProvider.refreshLeads();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      // floatingActionButton: FloatingActionButton(
      //   mini: true,
      //   onPressed: _loadActivity,
      //   tooltip: 'Refresh Activity',
      //   backgroundColor: Colors.blue.shade700,
      //   foregroundColor: Colors.white,
      //   child: const Icon(Icons.refresh),
      //   heroTag: 'activity_fab',
      // ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppState().bodyGradient,
          ),
          child: Consumer<LeadProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && provider.leads.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                );
              }

              // Sort leads by most recently updated
              final sortedLeads = List<SpancoLead>.from(provider.leads)
                ..sort((a, b) {
                  // Use updatedAt if available, otherwise use createdAt
                  final aTime = a.updatedAt ?? a.createdAt!;
                  final bTime = b.updatedAt ?? b.createdAt!;
                  return bTime.compareTo(aTime);
                });

              // ✅ Calculate filter counts
              final filterCounts = _calculateFilterCounts(sortedLeads);

              // Filter activity based on selected filter
              final filteredLeads = _filterLeads(sortedLeads);

              // ✅ Group by date
              final groupedActivities = _groupByDate(filteredLeads);

              return Column(
                children: [
                  // ✅ IMPROVED: Filter Chips with counts
                  _buildFilterSection(filterCounts),

                  // Activity List
                  Expanded(
                    child: filteredLeads.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                      onRefresh: _loadActivity,
                      color: Colors.blue.shade700,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: groupedActivities.length,
                        itemBuilder: (context, index) {
                          final group = groupedActivities[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date header
                              _buildDateHeader(group['date'] as String),
                              // Activities for this date
                              ...((group['leads'] as List<SpancoLead>)
                                  .map((lead) => _buildActivityCard(lead))),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }


  // ✅ ADD: Calculate filter counts
  Map<String, int> _calculateFilterCounts(List<SpancoLead> leads) {
    final now = DateTime.now().toUtc();
    return {
      'all': leads.length,
      'created': leads
          .where((l) => now.difference(l.createdAt!).inDays <= 1)
          .length,
      'updated': leads
          .where((l) {
        final updated = l.updatedAt ?? l.createdAt!;
        return now.difference(updated).inDays <= 1;
      })
          .length,
      'moved': leads
          .where((l) => now.difference(l.stageUpdatedAt).inDays <= 1)
          .length,
      'won': leads.where((l) => l.status == LeadStatus.won).length,
      'lost': leads.where((l) => l.status == LeadStatus.lost).length,
    };
  }

  // ✅ IMPROVED: Filter section with counts
  Widget _buildFilterSection(Map<String, int> counts) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Activity Feed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${counts[_selectedFilter]} items',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All Activity', counts['all']!),
                _buildFilterChip('created', 'Created', counts['created']!),
                _buildFilterChip('updated', 'Updated', counts['updated']!),
                _buildFilterChip('moved', 'Stage Moved', counts['moved']!),
                _buildFilterChip('won', 'Won', counts['won']!),
                _buildFilterChip('lost', 'Lost', counts['lost']!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ IMPROVED: Filter chip with count
  Widget _buildFilterChip(String value, String label, int count) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.blue : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
      ),
    );
  }

  // ✅ FIXED: Group activities by date (handle null updatedAt)
  List<Map<String, dynamic>> _groupByDate(List<SpancoLead> leads) {
    final Map<String, List<SpancoLead>> grouped = {};

    for (var lead in leads) {
      // ✅ Use updatedAt if available, otherwise use createdAt
      final dateTime = lead.updatedAt ?? lead.createdAt!;
      final date = _getDateGroup(dateTime);
      grouped.putIfAbsent(date, () => []).add(lead);
    }

    return grouped.entries
        .map((e) => {'date': e.key, 'leads': e.value})
        .toList();
  }


  // ✅ FIXED: Get date group label with proper UTC
  String _getDateGroup(DateTime dateTime) {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day); // ✅ Use DateTime.utc
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime.utc(dateTime.year, dateTime.month, dateTime.day); // ✅ Use DateTime.utc

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else if (today.difference(date).inDays < 7) { // ✅ Use today.difference for UTC
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[date.weekday - 1];
    } else if (today.difference(date).inDays < 30) { // ✅ Use today.difference
      return 'This Month';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.year}';
    }
  }


  // ✅ ADD: Date header
  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              date,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ IMPROVED: Better empty state
  Widget _buildEmptyState() {
    String message = 'No activity found';
    String subtitle = 'Activities will appear here';
    IconData icon = Icons.history_outlined;

    switch (_selectedFilter) {
      case 'created':
        message = 'No leads created recently';
        subtitle = 'Leads created today will appear here';
        icon = Icons.add_circle_outline;
        break;
      case 'updated':
        message = 'No recent updates';
        subtitle = 'Lead updates from today will appear here';
        icon = Icons.edit_outlined;
        break;
      case 'moved':
        message = 'No stage movements';
        subtitle = 'Stage changes from today will appear here';
        icon = Icons.arrow_forward_outlined;
        break;
      case 'won':
        message = 'No won leads';
        subtitle = 'Successfully won leads will appear here';
        icon = Icons.celebration_outlined;
        break;
      case 'lost':
        message = 'No lost leads';
        subtitle = 'Lost leads will appear here';
        icon = Icons.cancel_outlined;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<SpancoLead> _filterLeads(List<SpancoLead> leads) {
    final now = DateTime.now().toUtc();

    switch (_selectedFilter) {
      case 'created':
        return leads
            .where((lead) => now.difference(lead.createdAt!).inDays <= 1)
            .toList();
      case 'updated':
        return leads
            .where((lead) {
          // ✅ FIXED: Handle null updatedAt
          final updated = lead.updatedAt ?? lead.createdAt!;
          return now.difference(updated).inDays <= 1;
        })
            .toList();
      case 'won':
        return leads.where((lead) => lead.status == LeadStatus.won).toList();
      case 'lost':
        return leads.where((lead) => lead.status == LeadStatus.lost).toList();
      case 'moved':
        return leads
            .where((lead) => now.difference(lead.stageUpdatedAt).inDays <= 1)
            .toList();
      default:
        return leads;
    }
  }


  Widget _buildActivityCard(SpancoLead lead) {
    final now = DateTime.now().toUtc();
    final daysSinceCreated = now.difference(lead.createdAt!).inDays;

    // ✅ FIXED: Handle null updatedAt
    final updatedAt = lead.updatedAt ?? lead.createdAt!;
    final daysSinceUpdated = now.difference(updatedAt).inDays;
    final daysSinceMoved = now.difference(lead.stageUpdatedAt).inDays;

    String activityTitle = '';
    String activitySubtitle = '';
    IconData activityIcon = Icons.info;
    Color activityColor = Colors.grey;

    // Determine activity type
    if (lead.status == LeadStatus.won) {
      activityTitle = 'Won: ${lead.customerName}';
      activitySubtitle = '${lead.currentStage.label} • ${lead.estimatedValue != null ? "₹${(lead.estimatedValue! / 1000).toStringAsFixed(0)}K" : "No value"}';
      activityIcon = Icons.check_circle;
      activityColor = Colors.green;
    } else if (lead.status == LeadStatus.lost) {
      activityTitle = 'Lost: ${lead.customerName}';
      activitySubtitle = 'Reason: ${lead.lostReason ?? 'Not specified'}';
      activityIcon = Icons.cancel;
      activityColor = Colors.red;
    } else if (daysSinceMoved == 0) {
      activityTitle = 'Stage Move: ${lead.customerName}';
      activitySubtitle = 'Moved to ${lead.currentStage.label}';
      activityIcon = Icons.trending_up;
      activityColor = Colors.orange;
    } else if (daysSinceCreated == 0) {
      activityTitle = 'New Lead: ${lead.customerName}';
      activitySubtitle = '${lead.customerType.label} • ${lead.serviceCity}';
      activityIcon = Icons.add_circle;
      activityColor = Colors.blue;
    } else if (daysSinceUpdated == 0) {
      activityTitle = 'Updated: ${lead.customerName}';
      activitySubtitle = '${lead.currentStage.label} • ${lead.priority.label} priority';
      activityIcon = Icons.edit;
      activityColor = Colors.purple;
    } else {
      activityTitle = lead.customerName;
      activitySubtitle = '${lead.currentStage.label} • ${lead.status.label}';
      activityIcon = Icons.info_outline;
      activityColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LeadDetailPage(leadId: lead.id!),
          ),
        ).then((_) => _loadActivity());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: activityColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                activityIcon,
                color: activityColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activityTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activitySubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Time & Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _getTimeAgo(updatedAt), // ✅ FIXED: Use the non-null updatedAt
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: lead.status.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: lead.status.color.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    lead.status.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: lead.status.color,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }


  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().toUtc().difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
  }

  // Color _getStatusColor(LeadStatus status) {
  //   switch (status) {
  //     case LeadStatus.active:
  //       return Colors.green;
  //     case LeadStatus.onHold:
  //       return Colors.orange;
  //     case LeadStatus.won:
  //       return Colors.green;
  //     case LeadStatus.lost:
  //       return Colors.red;
  //     case LeadStatus.cancelled:
  //       return Colors.grey;
  //   }
  // }
}
