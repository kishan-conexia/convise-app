// lib/pages/feasibility/feasibility_detail_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_state.dart';
import '../../models/spanco/feasibility/connectivity_route.dart';
import '../../models/spanco/feasibility/cost_item.dart';
import '../../models/spanco/feasibility/feasibility_request.dart';
import '../../providers/feasibility_provider.dart';
import '../../utils/formatters.dart';
import 'review_page.dart';

class FeasibilityDetailPage extends StatefulWidget {
  final int requestId;

  const FeasibilityDetailPage({
    Key? key,
    required this.requestId,
  }) : super(key: key);

  @override
  State<FeasibilityDetailPage> createState() => _FeasibilityDetailPageState();
}

class _FeasibilityDetailPageState extends State<FeasibilityDetailPage> {
  late FeasibilityProvider _feasibilityProvider;
  late AppState _appState;
  FeasibilityRequest? _request;

  @override
  void initState() {
    super.initState();
    _feasibilityProvider = Provider.of<FeasibilityProvider>(context, listen: false);
    _appState = Provider.of<AppState>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequest();
    });
  }

  Future<void> _loadRequest() async {
    final request = await _feasibilityProvider.getRequestById(widget.requestId);
    setState(() {
      _request = request;
    });
  }

  bool get _isRequester => _request?.requestedBy == _appState.userId;
  bool get _canReview => _appState.canManageFeasibility;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: _request?.requestNumber != null
            ? Text(
          'Request #${_request!.requestNumber}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        )
            : const Text(
          'Feasibility Details',
          style: TextStyle(
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
        actions: [
          if (_request != null &&
              (_request!.status == FeasibilityStatus.pending ||
                  _request!.status == FeasibilityStatus.underReview) &&
              _isRequester)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: _showCancelDialog,
                  child: const Row(
                    children: [
                      Icon(Icons.cancel, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Cancel Request', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppState().bodyGradient,
          ),
          child: Consumer<FeasibilityProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && _request == null) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                );
              }

              if (_request == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Request not found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // ✅ FIXED: Use LayoutBuilder without IntrinsicHeight
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      // ✅ Ensure minimum height fills the screen
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        children: [
                          _buildHeaderCard(_request!),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Service Location
                                _buildSection('Location', [
                                  _buildDetailRow('Address', _request!.serviceLocation.address),
                                  _buildDetailRow('City', _request!.serviceLocation.city),
                                  _buildDetailRow('State', _request!.serviceLocation.state),
                                  _buildDetailRow('Pin code', _request!.serviceLocation.pincode),
                                  if (_request!.serviceLocation.landmark != null)
                                    _buildDetailRow('Landmark', _request!.serviceLocation.landmark!),
                                  if (_request!.serviceLocation.latitude != null &&
                                      _request!.serviceLocation.longitude != null)
                                    _buildCoordinatesRow(
                                      _request!.serviceLocation.latitude!,
                                      _request!.serviceLocation.longitude!,
                                    ),
                                ]),
                                const SizedBox(height: 24),

                                // Service Requirements
                                _buildSection('Service Requirements', [
                                  _buildDetailRow('Feasibility Type',
                                      _capitalize(_request!.serviceRequirements.feasibilityType)),
                                  _buildDetailRow('Service Type',
                                      _getServiceTypeLabel(_request!.serviceRequirements.connectionType)),
                                  if (_request!.serviceRequirements.connectionType == 'leased_line')
                                    _buildDetailRow('Bandwidth', _request!.serviceRequirements.bandwidth)
                                  else
                                    _buildDetailRow('Bandwidth', 'N/A (Partner Service)'),
                                  _buildDetailRow('Urgency',
                                      _capitalize(_request!.serviceRequirements.urgency)),
                                  _buildDetailRow('Priority',
                                      _capitalize(_request!.serviceRequirements.priority)),
                                  if (_request!.serviceRequirements.specialConditions != null)
                                    _buildDetailRow('Special Conditions',
                                        _request!.serviceRequirements.specialConditions!),
                                ]),

                                const SizedBox(height: 24),

                                // Primary Route Details
                                if (_request!.primaryRoute != null)
                                  _buildRouteSection('Primary Connectivity Route', _request!.primaryRoute!),
                                if (_request!.primaryRoute != null)
                                  const SizedBox(height: 24),

                                // Secondary Route Details
                                if (_request!.secondaryRoute != null)
                                  _buildRouteSection('Secondary Connectivity Route', _request!.secondaryRoute!),
                                if (_request!.secondaryRoute != null)
                                  const SizedBox(height: 24),

                                // Site Survey
                                if (_request!.siteSurvey != null)
                                  _buildSiteSurveySection(),
                                if (_request!.siteSurvey != null)
                                  const SizedBox(height: 24),

                                // Commercial Assessment Section
                                if (_request!.estimatedCapex != null ||
                                    _request!.estimatedOpex != null ||
                                    (_request!.operationalCosts != null && _request!.operationalCosts!.isNotEmpty))
                                  _buildCommercialAssessmentSection(),
                                if (_request!.estimatedCapex != null || _request!.estimatedOpex != null)
                                  const SizedBox(height: 24),

                                // Review Status
                                _buildReviewStatusSection(),
                                const SizedBox(height: 24),

                                // Status History Section
                                _buildStatusHistory(),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: _buildActionButton(),
    );
  }


  // ✅ FIXED: Build comprehensive commercial assessment section
  Widget _buildCommercialAssessmentSection() {
    final hasCapex = _request!.estimatedCapex != null;
    final hasOpex = _request!.estimatedOpex != null;
    final hasOpexDetails = _request!.operationalCosts != null &&
        _request!.operationalCosts!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Commercial Assessment',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // CAPEX Section
              if (hasCapex) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calculate, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Capital Expenditure (CAPEX)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        Formatters.formatCurrency(_request!.estimatedCapex!),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ),

                // CAPEX Breakdown (from routes)
                if (_request!.primaryRoute?.totalCapex != null ||
                    _request!.secondaryRoute?.totalCapex != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Breakdown:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_request!.primaryRoute?.totalCapex != null)
                          _buildBreakdownRow(
                            'Primary Route',
                            _request!.primaryRoute!.totalCapex!,
                            Colors.blue,
                          ),
                        if (_request!.secondaryRoute?.totalCapex != null) ...[
                          const SizedBox(height: 4),
                          _buildBreakdownRow(
                            'Secondary Route',
                            _request!.secondaryRoute!.totalCapex!,
                            Colors.purple,
                          ),
                        ],
                      ],
                    ),
                  ),

                if (hasOpex) const Divider(height: 1),
              ],

              // ✅ FIXED: OPEX Section with vertical layout
              if (hasOpex) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: hasCapex ? null : Colors.orange[50],
                    borderRadius: hasCapex
                        ? null
                        : const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Monthly Operational Expenditure',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${Formatters.formatCurrency(_request!.estimatedOpex!)}/mo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                ),

                // OPEX Breakdown
                if (hasOpexDetails)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Breakdown:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._request!.operationalCosts!.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _buildBreakdownRow(
                            item.description,
                            item.monthlyCost,
                            _getCategoryColor(item.category),
                          ),
                        )),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }


  // ✅ NEW: Build breakdown row
  Widget _buildBreakdownRow(String label, double amount, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Text(
          Formatters.formatCurrency(amount),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ✅ NEW: Get category color
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'infrastructure':
        return Colors.blue;
      case 'power':
        return Colors.amber;
      case 'maintenance':
        return Colors.green;
      case 'bandwidth':
        return Colors.purple;
      case 'licensing':
        return Colors.red;
      case 'labor':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHeaderCard(FeasibilityRequest request) {
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: _getStatusColor(request.status),
                child: Icon(
                  _getStatusIcon(request.status),
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.requestNumber ?? 'FR-${request.id}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(request.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        request.status.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(request.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderStat('Created', Formatters.formatDate(request.createdAt)),
              _buildHeaderStat('Urgency', _capitalize(request.serviceRequirements.urgency)),
              _buildHeaderStat('Priority', _capitalize(request.serviceRequirements.priority)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildRouteSection(String title, ConnectivityRoute route) {
    if (!route.isFeasible) {
      // Not feasible case
      return _buildSection(title, [
        _buildDetailRow('Status', 'Not Feasible'),
        if (route.reason != null)
          _buildDetailRow('Reason', route.reason!),
        if (route.remarks != null)
          _buildDetailRow('Remarks', route.remarks!),
        if (route.technicalConstraints != null && route.technicalConstraints!.isNotEmpty)
          _buildDetailRow('Constraints', route.technicalConstraints!.join(', ')),
      ]);
    }

    // Feasible case - show full details
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(title, [
          _buildDetailRow('Status', 'Feasible'),
          if (route.routeName != null)
            _buildDetailRow('Route Name', route.routeName!),
          if (route.sourceNodeName != null)
            _buildDetailRow('Source Node', route.sourceNodeName!),
          if (route.distanceKm != null)
            _buildDetailRow('Distance', '${route.distanceKm!.toStringAsFixed(2)} km'),
          if (route.technology != null)
            _buildDetailRow('Technology', route.technology!),
          if (route.totalFiberLengthMtr != null)
            _buildDetailRow('Total Fiber Length', '${route.totalFiberLengthMtr!.toStringAsFixed(0)} meters'),
          if (route.infrastructureAvailable != null)
            _buildDetailRow('Infrastructure Available', route.infrastructureAvailable! ? 'Yes' : 'No'),
          if (route.requiresRow != null && route.requiresRow!)
            _buildDetailRow('Requires ROW', 'Yes'),
          if (route.installationDays != null)
            _buildDetailRow('Installation Time', '${route.installationDays} days'),
        ]),

        // Cost breakdown
        if (route.costItems != null && route.costItems!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Cost Breakdown',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildCostItemsTable(route.costItems!),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildCostSummaryRow('Consumable CAPEX', route.consumableCapex ?? 0),
                const SizedBox(height: 8),
                _buildCostSummaryRow('Recoverable CAPEX', route.recoverableCapex ?? 0),
                const Divider(),
                _buildCostSummaryRow('Total CAPEX', route.totalCapex ?? 0, isTotal: true),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCostItemsTable(List<CostItem> items) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(flex: 1, child: Text('UOM', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Cost', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Items
          ...items.map((item) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemDescription,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(flex: 3, child: Text(item.itemCode, style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                    Expanded(flex: 1, child: Text(item.uom, style: TextStyle(fontSize: 11))),
                    Expanded(flex: 1, child: Text('${item.quantity.toStringAsFixed(0)}', style: TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text(Formatters.formatCurrency(item.totalCost), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                  ],
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildCostSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        Text(
          Formatters.formatCurrency(amount),
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            color: isTotal ? Colors.blue[900] : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSiteSurveySection() {
    final survey = _request!.siteSurvey!;
    return _buildSection('Site Survey', [
      _buildDetailRow('Required', survey.required ? 'Yes' : 'No'),
      _buildDetailRow('Completed', survey.completed ? 'Yes' : 'No'),
      if (survey.surveyDate != null)
        _buildDetailRow('Survey Date', Formatters.formatDate(survey.surveyDate!)),
      if (survey.surveyorName != null)
        _buildDetailRow('Surveyor', survey.surveyorName!),
      if (survey.findings != null)
        _buildDetailRow('Findings', survey.findings!),
      if (survey.recommendations != null)
        _buildDetailRow('Recommendations', survey.recommendations!),
    ]);
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStatusSection() {
    if (_request!.reviewedBy == null || _request!.isFeasible == null) {
      final statusInfo = _getUnreviewedStatusInfo();
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusInfo['color'],
          border: Border.all(color: statusInfo['borderColor']),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(statusInfo['icon'], color: statusInfo['iconColor']),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusInfo['message'],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    final isApproved = _request!.isFeasible!;
    final color = isApproved ? Colors.green : Colors.red;
    final icon = isApproved ? Icons.check_circle : Icons.cancel;
    final title = isApproved ? 'Approved' : 'Rejected';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          if (_request!.feasibilityRemarks != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _request!.feasibilityRemarks!,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Reviewed on ${Formatters.formatDateTimeWithPeriod(_request!.reviewedAt!)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getUnreviewedStatusInfo() {
    switch (_request!.status) {
      case FeasibilityStatus.pending:
        return {
          'color': Colors.grey[100],
          'borderColor': Colors.grey[300]!,
          'icon': Icons.hourglass_empty,
          'iconColor': Colors.grey[600],
          'message': 'Awaiting feasibility review',
        };
      case FeasibilityStatus.underReview:
        return {
          'color': Colors.blue[50],
          'borderColor': Colors.blue[300]!,
          'icon': Icons.rate_review,
          'iconColor': Colors.blue[700],
          'message': 'Feasibility assessment in progress',
        };
      case FeasibilityStatus.cancelled:
        return {
          'color': Colors.orange[50],
          'borderColor': Colors.orange[300]!,
          'icon': Icons.block,
          'iconColor': Colors.orange[700],
          'message': 'Request has been cancelled',
        };
      default:
        return {
          'color': Colors.grey[100],
          'borderColor': Colors.grey[300]!,
          'icon': Icons.help_outline,
          'iconColor': Colors.grey[600],
          'message': 'Status unknown',
        };
    }
  }

  Widget? _buildActionButton() {
    if (_request == null) return null;

    final status = _request!.status;
    final canOpenReview = _canReview &&
        (status == FeasibilityStatus.pending || status == FeasibilityStatus.underReview);

    if (canOpenReview) {
      return FloatingActionButton.extended(
        onPressed: () async {
          // if (status == FeasibilityStatus.pending) {
          //   await _feasibilityProvider.startReview(_request!.id!);
          //   await _loadRequest();
          // }

          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReviewPage(request: _request!),
            ),
          );

          if (!mounted) return;
          await _loadRequest();
        },
        icon: const Icon(Icons.rate_review),
        label: const Text('Review'),
        backgroundColor: Colors.blue,
      );
    }

    return null;
  }

  void _showCancelDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this request?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for cancellation (optional)',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _feasibilityProvider.cancelRequest(
                _request!.id!,
                reason: reasonController.text.isEmpty
                    ? 'Cancelled by requester'
                    : reasonController.text,
              );
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request cancelled'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatesRow(double latitude, double longitude) {
    final coords = '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Coordinates',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    coords,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _openInMaps(latitude, longitude),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.map,
                      size: 18,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  /// ✅ UPDATED: Build status history section with ExpansionTile
  Widget _buildStatusHistory() {
    final history = _request?.statusHistory ?? [];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.history,
            color: Colors.blue[700],
          ),
          title: const Text(
            'Status History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            history.isEmpty
                ? 'No status changes yet'
                : '${history.length} event${history.length > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          children: [
            if (history.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Text(
                      'No status history available',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: history.length > 5 ? 450 : double.infinity,
                  ),
                  child: Scrollbar(
                    // ✅ Show scrollbar only when there are more than 5 items
                    thumbVisibility: history.length > 5,
                    thickness: 4,
                    radius: const Radius.circular(2),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: history.length > 5
                          ? const AlwaysScrollableScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        // ✅ Reverse to show latest first
                        final entry = history[history.length - 1 - index];
                        final isLatest = index == 0;
                        final isLast = index == history.length - 1;
                        return _buildHistoryEntry(entry, isLatest, isLast);
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

  /// ✅ UPDATED: Build individual history entry with timeline design
  Widget _buildHistoryEntry(Map<String, dynamic> entry, bool isLatest, bool isLast) {
    final event = entry['event'] as String;
    final timestamp = DateTime.parse(entry['timestamp'] as String);
    final note = entry['note'] as String?;
    final previousStatus = entry['previous_status'] as String?;
    final newStatus = entry['new_status'] as String?;
    final rejectionReason = entry['rejection_reason'] as String?;

    // Determine icon and color based on event type
    IconData icon;
    Color iconColor;

    switch (event) {
      case 'created':
        icon = Icons.add_circle;
        iconColor = Colors.blue;
        break;
      case 'reactivated':
        icon = Icons.refresh;
        iconColor = Colors.orange;
        break;
      case 'approved':
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'rejected':
        icon = Icons.cancel;
        iconColor = Colors.red;
        break;
      case 'cancelled':
        icon = Icons.block;
        iconColor = Colors.grey;
        break;
      case 'status_changed':
        icon = Icons.update;
        iconColor = Colors.blue;
        break;
      default:
        icon = Icons.circle;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isLatest ? Colors.blue[50] : null,
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Timeline indicator (dot + line)
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isLatest ? iconColor : Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isLatest ? iconColor : Colors.grey[400]!,
                    width: isLatest ? 2 : 1,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 12),
          // ✅ Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event label with Latest badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note ?? 'Status changed',
                        style: TextStyle(
                          fontWeight: isLatest ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isLatest)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Latest',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 6),

                // Status transition (if applicable)
                if (previousStatus != null && newStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      '${_formatStatusLabel(previousStatus)} → ${_formatStatusLabel(newStatus)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                const SizedBox(height: 6),

                // Timestamp
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                // Rejection reason (if applicable)
                if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.red[700]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Reason: $rejectionReason',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Helper: Format status label for display
  String _formatStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'under_review':
        return 'Under Review';
      case 'awaiting_approval':
        return 'Awaiting Approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  /// ✅ NEW: Helper method for formatting datetime
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      }
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }



// Method to open coordinates in Google Maps
  Future<void> _openInMaps(double lat, double lng) async {
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
  }

  // ✅ NEW: Get friendly label for service type
  String _getServiceTypeLabel(String serviceType) {
    switch (serviceType) {
      case 'partner':
        return 'Partner';
      case 'leased_line':
        return 'Leased Line';
    // Legacy values (in case old data exists)
      case 'fiber':
        return 'Fiber';
      case 'wireless':
        return 'Wireless';
      case 'hybrid':
        return 'Hybrid';
      default:
        return _capitalize(serviceType);
    }
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

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
