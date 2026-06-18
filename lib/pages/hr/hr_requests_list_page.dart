import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../models/hr_request.dart';
import '../../providers/hr_request_provider.dart';
import '../../utils/formatters.dart';
import 'hr_request_detail_page.dart';

class HrRequestsListPage extends StatefulWidget {
  const HrRequestsListPage({super.key});

  @override
  State<HrRequestsListPage> createState() => _HrRequestsListPageState();
}

class _HrRequestsListPageState extends State<HrRequestsListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HrRequestProvider>(context, listen: false).fetchRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HrRequestProvider>(context);
    final appState = Provider.of<AppState>(context);

    // Guard — only admin can access
    if (!appState.isManager) {
      return const Scaffold(
        body: Center(child: Text('Access Denied')),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: const Text('HR Requests',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white70,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade400,
                  Colors.blue.shade600,
                  Colors.blue.shade800
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => provider.fetchRequests(),
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
        child: Column(
          children: [
            // ── Filter Chips ────────────────────────────────
            _buildFilterBar(provider),

            // ── List ────────────────────────────────────────
            Expanded(
              child: provider.loading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.requests.isEmpty
                  ? _buildEmptyState(provider.activeFilter)
                  : RefreshIndicator(
                onRefresh: provider.fetchRequests,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: provider.requests.length,
                  itemBuilder: (_, i) => _RequestCard(
                    request: provider.requests[i],
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HrRequestDetailPage(
                            request: provider.requests[i],
                          ),
                        ),
                      );
                      provider.fetchRequests(); // refresh on return
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(HrRequestProvider provider) {
    final filters = [
      {'key': 'pending',      'label': 'Pending'},
      {'key': 'under_review', 'label': 'Under Review'},
      {'key': 'all',          'label': 'All'},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isActive = provider.activeFilter == f['key'];
            final color    = _filterColor(f['key']!);
            return GestureDetector(
              onTap: () => provider.setFilter(f['key']!),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? color : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? color : Colors.grey.shade300,
                  ),
                  boxShadow: isActive
                      ? [BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2))]
                      : [],
                ),
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _filterColor(String filter) {
    switch (filter) {
      case 'pending':      return Colors.orange;
      case 'under_review': return Colors.blue;
      default:             return Colors.blueGrey;
    }
  }

  Widget _buildEmptyState(String filter) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            filter == 'pending'
                ? 'No pending requests'
                : filter == 'under_review'
                ? 'No requests under review'
                : 'No requests found',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Request Card
// ─────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final HrRequest request;
  final VoidCallback onTap;

  const _RequestCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(request.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.9),
              Colors.white.withOpacity(0.6)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── User row ──────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: request.avatarUrl != null && request.avatarUrl!.isNotEmpty
                        ? NetworkImage(request.avatarUrl!)
                        : null,
                    child: request.avatarUrl == null || request.avatarUrl!.isEmpty
                        ? Text(
                      _initials(request.userName ?? '?'),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700),
                    )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.userName ?? 'Unknown User',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (request.empCode != null)
                          Text(
                            request.empCode!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        if (request.departmentName != null)
                          Text(
                            request.departmentName!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: request.status),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 12),

              // ── Request info row ──────────────────────────
              Row(
                children: [
                  _InfoChip(
                    icon: request.documentType.isNotEmpty
                        ? _docIcon(request.documentType)
                        : Icons.manage_accounts_outlined,
                    label: request.documentType.isNotEmpty
                        ? _docLabel(request.documentType)
                        : _subtypeLabel(request.newData['subtype'] as String? ?? request.requestType),
                    color: Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.flag_outlined,
                    label: request.priority,
                    color: _priorityColor(request.priority),
                  ),
                  const Spacer(),
                  Icon(Icons.schedule_outlined,
                      size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.formatRelativeTime(request.createdAt),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right,
                      size: 18, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':      return Colors.orange;
      case 'under_review': return Colors.blue;
      case 'approved':     return Colors.green;
      case 'rejected':     return Colors.red;
      default:             return Colors.grey;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent': return Colors.red;
      case 'high':   return Colors.orange;
      case 'low':    return Colors.grey;
      default:       return Colors.blue;
    }
  }

  IconData _docIcon(String type) {
    switch (type) {
      case 'aadhaar':        return Icons.fingerprint;
      case 'pan':            return Icons.credit_card_outlined;
      case 'passport':       return Icons.book_outlined;
      case 'cheque':         return Icons.receipt_long_outlined;
      case 'passbook':       return Icons.account_balance_outlined;
      case 'device_change':  return Icons.smartphone_outlined;
      default:               return Icons.description_outlined;
    }
  }

  String _docLabel(String type) {
    switch (type) {
      case 'aadhaar':        return 'Aadhaar';
      case 'pan':            return 'PAN Card';
      case 'passport':       return 'Passport';
      case 'cheque':         return 'Cheque';
      case 'passbook':       return 'Passbook';
      case 'device_change':  return 'Device Change';
      default:               return type;
    }
  }

  String _subtypeLabel(String subtype) {
    switch (subtype) {
      case 'profile_field': return 'Profile Update';
      case 'family_field':  return 'Family Details';
      case 'children':      return 'Children';
      case 'nominees':      return 'Nominees';
      case 'device_change': return 'Device Change';
      default:              return Formatters.capitalizeFirst(subtype.replaceAll('_', ' '));
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Status Chip
// ─────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange; label = 'Pending';
        icon  = Icons.hourglass_top_outlined;
        break;
      case 'under_review':
        color = Colors.blue; label = 'Under Review';
        icon  = Icons.manage_search_outlined;
        break;
      case 'approved':
        color = Colors.green; label = 'Approved';
        icon  = Icons.check_circle_outline;
        break;
      case 'rejected':
        color = Colors.red; label = 'Rejected';
        icon  = Icons.cancel_outlined;
        break;
      default:
        color = Colors.grey; label = status;
        icon  = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Info Chip
// ─────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}