// lib/pages/feasibility/feasibility_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/spanco/feasibility/feasibility_request.dart';
import '../../providers/feasibility_provider.dart';
import '../../utils/formatters.dart';
import 'feasibility_detail_page.dart';

class FeasibilityListPage extends StatelessWidget {
  const FeasibilityListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<FeasibilityProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.requests.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (provider.requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  provider.currentViewMode == ViewMode.pending
                      ? 'No pending requests'
                      : 'No feasibility requests yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.currentViewMode == ViewMode.pending
                      ? 'All requests have been reviewed'
                      : 'Create one from a lead in Approach stage',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.refreshRequests,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.paginatedRequests.length,
            itemBuilder: (context, index) {
              final request = provider.paginatedRequests[index];
              return _FeasibilityCard(
                request: request,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FeasibilityDetailPage(requestId: request.id!),
                    ),
                  ).then((_) => provider.refreshRequests());
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _FeasibilityCard extends StatelessWidget {
  final FeasibilityRequest request;
  final VoidCallback onTap;

  const _FeasibilityCard({
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(request.status),
                      color: _getStatusColor(request.status),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.requestNumber ?? 'FR-${request.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.serviceLocation.city,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      request.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: _getStatusColor(request.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Details
              Row(
                children: [
                  _buildInfoChip(
                    Icons.router,
                    request.serviceRequirements.connectionType.toUpperCase(),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.speed,
                    request.serviceRequirements.bandwidth,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    _getUrgencyIcon(request.serviceRequirements.urgency),
                    _capitalize(request.serviceRequirements.urgency),
                    color: _getUrgencyColor(request.serviceRequirements.urgency),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Routes Status (if reviewed)
              if (request.primaryRoute != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      request.hasPrimaryRoute
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 16,
                      color: request.hasPrimaryRoute
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Primary: ${request.primaryRouteStatus}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: request.hasPrimaryRoute
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    if (request.secondaryRoute != null) ...[
                      const SizedBox(width: 12),
                      Icon(
                        request.hasSecondaryRoute
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 16,
                        color: request.hasSecondaryRoute
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Secondary: ${request.secondaryRouteStatus}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: request.hasSecondaryRoute
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Formatters.formatDate(request.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  // if (request.isFeasible != null)
                  //   Row(
                  //     children: [
                  //       Icon(
                  //         request.isFeasible == true
                  //             ? Icons.check_circle
                  //             : Icons.cancel,
                  //         size: 16,
                  //         color: request.isFeasible == true
                  //             ? Colors.green
                  //             : Colors.red,
                  //       ),
                  //       const SizedBox(width: 4),
                  //       Text(
                  //         request.isFeasible == true ? 'Approved' : 'Rejected',
                  //         style: TextStyle(
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.w600,
                  //           color: request.isFeasible == true
                  //               ? Colors.green
                  //               : Colors.red,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color ?? Colors.grey[700],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color ?? Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(FeasibilityStatus status) {
    switch (status) {
      case FeasibilityStatus.pending:
        return Colors.grey;
      case FeasibilityStatus.underReview:
        return Colors.blue;
      case FeasibilityStatus.approved:
        return Colors.green;
      case FeasibilityStatus.rejected:
        return Colors.red;
      case FeasibilityStatus.cancelled:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(FeasibilityStatus status) {
    switch (status) {
      case FeasibilityStatus.pending:
        return Icons.hourglass_empty;
      case FeasibilityStatus.underReview:
        return Icons.rate_review;
      case FeasibilityStatus.approved:
        return Icons.check_circle;
      case FeasibilityStatus.rejected:
        return Icons.cancel;
      case FeasibilityStatus.cancelled:
        return Icons.block;
    }
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'normal':
        return Colors.blue;
      case 'high':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getUrgencyIcon(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'low':
        return Icons.arrow_downward;
      case 'normal':
        return Icons.remove;
      case 'high':
        return Icons.arrow_upward;
      case 'urgent':
        return Icons.priority_high;
      default:
        return Icons.remove;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
