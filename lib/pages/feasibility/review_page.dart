// lib/pages/feasibility/review_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/app_state.dart';
import '../../models/spanco/feasibility/feasibility_request.dart';
import '../../models/spanco/feasibility/connectivity_route.dart';
import '../../models/spanco/feasibility/cost_item.dart';
import '../../models/spanco/feasibility/operational_cost_item.dart';
import '../../models/spanco/feasibility/site_survey.dart';
import '../../providers/feasibility_provider.dart';
import '../../utils/formatters.dart';
import 'operational_costs_dialog.dart';

class ReviewPage extends StatefulWidget {
  final FeasibilityRequest request;

  const ReviewPage({
    super.key,
    required this.request,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late FeasibilityProvider _feasibilityProvider;
  late AppState _appState;
  late TabController _tabController;

  late FeasibilityRequest _currentRequest;

  // Decision
  String _decision = 'approve'; // approve, reject
  final TextEditingController _remarksController = TextEditingController();

  // Primary Route
  ConnectivityRoute? _primaryRoute;
  List<CostItem> _primaryCostItems = [];

  // Secondary Route
  ConnectivityRoute? _secondaryRoute;
  List<CostItem> _secondaryCostItems = [];

  // Site Survey
  SiteSurvey? _siteSurvey;

  // ✅ ADD: Operational Costs
  List<OperationalCostItem> _operationalCosts = [];

  // Commercial
  final TextEditingController _capexController = TextEditingController();
  final TextEditingController _opexController = TextEditingController();
  // final TextEditingController _roiController = TextEditingController();
  bool _isCommerciallyViable = true;

  // ✅ FIXED: Remove 'late final', use regular variables
  String _originalDecision = '';
  String _originalRemarks = '';
  ConnectivityRoute? _originalPrimaryRoute;
  ConnectivityRoute? _originalSecondaryRoute;
  SiteSurvey? _originalSiteSurvey;
  String _originalCapex = '';
  String _originalOpex = '';
  List<OperationalCostItem> _originalOperationalCosts = [];
  String _originalRoi = '';
  bool _originalCommerciallyViable = true;



  @override
  void initState() {
    super.initState();
    _feasibilityProvider = Provider.of<FeasibilityProvider>(context, listen: false);
    _appState = Provider.of<AppState>(context, listen: false);
    _tabController = TabController(length: 2, vsync: this);

    _currentRequest = widget.request;

    // ✅ ADD: Listen to tab changes
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    if (!_appState.canManageFeasibility) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAccessDeniedDialog();
      });
      return;
    }

    _loadDraftData();

    // ✅ ADD: Store original state after loading
    _storeOriginalState();
  }

  void _loadDraftData() {
    final r = widget.request;

    // Load routes
    _primaryRoute = r.primaryRoute;
    _secondaryRoute = r.secondaryRoute;

    // Load cost items
    if (_primaryRoute != null && _primaryRoute!.isFeasible) {
      _primaryCostItems = List.from(_primaryRoute!.costItems ?? []);
    }
    if (_secondaryRoute != null && _secondaryRoute!.isFeasible) {
      _secondaryCostItems = List.from(_secondaryRoute!.costItems ?? []);
    }

    // Load site survey
    _siteSurvey = r.siteSurvey;

    // ✅ ADD: Load operational costs
    if (r.operationalCosts != null) {
      _operationalCosts = List.from(r.operationalCosts!);
    }

    // Load commercial data
    _capexController.text = r.estimatedCapex?.toString() ?? '';
    _opexController.text = r.estimatedOpex?.toString() ?? '';
    // _roiController.text = r.estimatedRoiMonths?.toString() ?? '';
    _isCommerciallyViable = r.isCommerciallyViable ?? true;

    // Load remarks
    if (r.feasibilityRemarks != null && r.feasibilityRemarks!.isNotEmpty) {
      _remarksController.text = r.feasibilityRemarks!;
    }

    // Load decision state
    if (r.isFeasible != null) {
      _decision = r.isFeasible! ? 'approve' : 'reject';
    }
  }

  // ✅ FIXED: Now can be called multiple times
  void _storeOriginalState() {
    _originalDecision = _decision;
    _originalRemarks = _remarksController.text;
    _originalPrimaryRoute = _primaryRoute;
    _originalSecondaryRoute = _secondaryRoute;
    _originalSiteSurvey = _siteSurvey;
    _originalOperationalCosts = List.from(_operationalCosts);
    _originalCapex = _capexController.text;
    _originalOpex = _opexController.text;
    // _originalRoi = _roiController.text;
    _originalCommerciallyViable = _isCommerciallyViable;
  }

  // Check if anything has changed
  bool _hasChanges() {
    // ✅ Text fields: Compare trimmed values
    if (_remarksController.text.trim() != _originalRemarks.trim()) return true;

    // ✅ CAPEX: Only compare if both have values or if one changed from empty to value
    final currentCapex = _capexController.text.trim();
    final originalCapex = _originalCapex.trim();
    if (currentCapex != originalCapex) {
      // Changed from empty to value, or value to different value
      if (currentCapex.isNotEmpty || originalCapex.isNotEmpty) return true;
    }

    // ✅ OPEX: Same logic
    final currentOpex = _opexController.text.trim();
    final originalOpex = _originalOpex.trim();
    if (currentOpex != originalOpex) {
      if (currentOpex.isNotEmpty || originalOpex.isNotEmpty) return true;
    }

    // ✅ ROI: Same logic
    // final currentRoi = _roiController.text.trim();
    // final originalRoi = _originalRoi.trim();
    // if (currentRoi != originalRoi) {
    //   if (currentRoi.isNotEmpty || originalRoi.isNotEmpty) return true;
    // }

    // ✅ Decision
    // if (_decision != _originalDecision) return true;

    // ✅ REMOVED: Don't track is_commercially_viable changes
    // if (_isCommerciallyViable != _originalCommerciallyViable) return true;

    // ✅ Routes
    if (_routeChanged(_primaryRoute, _originalPrimaryRoute)) return true;
    if (_routeChanged(_secondaryRoute, _originalSecondaryRoute)) return true;

    // ✅ Site survey
    if (_siteSurveyChanged(_siteSurvey, _originalSiteSurvey)) return true;
    if (_operationalCostsChanged()) return true;

    return false;
  }


  // Compare routes
  bool _routeChanged(ConnectivityRoute? current, ConnectivityRoute? original) {
    if (current == null && original == null) return false;
    if (current == null || original == null) return true;

    // Compare via JSON serialization (simple and accurate)
    return current.toJson().toString() != original.toJson().toString();
  }

  // Compare site surveys
  bool _siteSurveyChanged(SiteSurvey? current, SiteSurvey? original) {
    if (current == null && original == null) return false;
    if (current == null || original == null) return true;

    return current.toJson().toString() != original.toJson().toString();
  }

  // ✅ ADD: Helper method to calculate total CAPEX
  double? _calculateTotalCapex() {
    double total = 0;
    bool hasValues = false;

    // Add primary route CAPEX
    if (_primaryRoute != null && _primaryRoute!.totalCapex != null) {
      total += _primaryRoute!.totalCapex!;
      hasValues = true;
    }

    // Add secondary route CAPEX
    if (_secondaryRoute != null && _secondaryRoute!.totalCapex != null) {
      total += _secondaryRoute!.totalCapex!;
      hasValues = true;
    }

    return hasValues ? total : null;
  }

  // ✅ ADD: Update CAPEX field when routes change
  void _updateCapexFromRoutes() {
    final calculatedCapex = _calculateTotalCapex();
    if (calculatedCapex != null) {
      _capexController.text = calculatedCapex.toStringAsFixed(2);
    } else {
      _capexController.text = '';
    }
  }

  // ✅ ADD: Calculate total monthly OPEX from operational costs
  double? _calculateTotalOpex() {
    if (_operationalCosts.isEmpty) return null;

    return _operationalCosts.fold(
      0.0,
          (sum, item) => sum! + item.monthlyCost,
    );
  }

  // ✅ ADD: Update OPEX field when operational costs change
  void _updateOpexFromCosts() {
    final calculatedOpex = _calculateTotalOpex();
    if (calculatedOpex != null) {
      _opexController.text = calculatedOpex.toStringAsFixed(2);
    } else {
      _opexController.text = '';
    }
  }

  // ✅ ADD: Check if operational costs changed
  bool _operationalCostsChanged() {
    if (_operationalCosts.length != _originalOperationalCosts.length) return true;

    for (int i = 0; i < _operationalCosts.length; i++) {
      if (_operationalCosts[i].toJson().toString() !=
          _originalOperationalCosts[i].toJson().toString()) {
        return true;
      }
    }

    return false;
  }


  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.red),
            SizedBox(width: 12),
            Text('Access Denied'),
          ],
        ),
        content: const Text(
          'You do not have permission to review feasibility requests. '
              'Only feasibility managers can approve or reject requests.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _capexController.dispose();
    _opexController.dispose();
    // _roiController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_appState.canManageFeasibility) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Feasibility Review',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.route), text: 'Routes'),
            // Tab(icon: Icon(Icons.assessment), text: 'Assessment'),
            Tab(icon: Icon(Icons.check_circle), text: 'Decision'),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppState().bodyGradient,
          ),
          child: Consumer<FeasibilityProvider>(
            builder: (context, provider, _) {
              return Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Routes
                    _buildRoutesTab(),
                    // Tab 2: Assessment
                    // _buildAssessmentTab(),
                    // Tab 3: Decision
                    _buildDecisionTab(provider),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      // ✅ FAB with change indicator and improved styling
      floatingActionButton: Consumer<FeasibilityProvider>(
        builder: (context, provider, _) {
          final hasChanges = _hasChanges();

          return FloatingActionButton.extended(
            onPressed: provider.isLoading ? null : _saveDraft,
            icon: provider.isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Icon(
              hasChanges ? Icons.save : Icons.check_circle,
            ),
            label: Text(
              hasChanges ? 'Save Draft' : 'No Changes',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            backgroundColor: provider.isLoading
                ? Colors.grey.shade400
                : (hasChanges ? Colors.blue.shade400 : Colors.green.shade400),
            elevation: 2,
            heroTag: 'review_fab',
          );
        },
      ),
    );
  }


  Widget _buildRoutesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRequestSummaryCard(),
          const SizedBox(height: 24),

          // Primary Route Section
          _buildSectionHeader('Primary Connectivity Route *'),
          const SizedBox(height: 12),
          _buildRouteEditor(
            route: _primaryRoute,
            costItems: _primaryCostItems,
            onRouteChanged: (route) => setState(() => _primaryRoute = route),
            onCostItemsChanged: (items) => setState(() => _primaryCostItems = items),
            isPrimary: true,
          ),
          const SizedBox(height: 24),

          // Secondary Route Section
          _buildSectionHeader('Secondary Connectivity Route (Optional)'),
          const SizedBox(height: 12),
          _buildRouteEditor(
            route: _secondaryRoute,
            costItems: _secondaryCostItems,
            onRouteChanged: (route) => setState(() => _secondaryRoute = route),
            onCostItemsChanged: (items) => setState(() => _secondaryCostItems = items),
            isPrimary: false,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

// Tab 2: Assessment
  Widget _buildAssessmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Site Survey Section
          _buildSectionHeader('Site Survey'),
          const SizedBox(height: 12),
          _buildSiteSurveyEditor(),
          const SizedBox(height: 24),

          // Commercial Assessment Section
          _buildSectionHeader('Commercial Assessment'),
          const SizedBox(height: 12),
          _buildCommercialAssessment(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

// Tab 3: Decision
  Widget _buildDecisionTab(FeasibilityProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Draft status banner
          if (widget.request.status == FeasibilityStatus.underReview &&
              _currentRequest.reviewedAt != null &&
              _currentRequest.reviewedAt != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 22, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Draft in progress. Last saved on ${Formatters.formatDateTimeWithPeriod(_currentRequest.reviewedAt!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ✅ Commercial Summary Section
          _buildSectionHeader('Commercial Summary'),
          const SizedBox(height: 12),
          _buildCommercialSummary(),
          const SizedBox(height: 24),

          // Decision section
          _buildSectionHeader('Your Decision *'),
          const SizedBox(height: 12),
          _buildDecisionSelector(),
          const SizedBox(height: 24),

          // Remarks section
          _buildSectionHeader('Final Remarks *'),
          const SizedBox(height: 12),
          _buildTextFormField(
            controller: _remarksController,
            label: 'Feasibility Remarks',
            hint: 'Explain your decision and key findings',
            minLines: 4,
            maxLength: 500,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please provide remarks for your decision';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: provider.isLoading ? null : _submitDecision,
              style: ElevatedButton.styleFrom(
                backgroundColor: _getDecisionColor(),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: provider.isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                _getDecisionButtonText(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: provider.isLoading ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }


  // ✅ UPDATED: Build commercial summary with operational costs editor
  Widget _buildCommercialSummary() {
    final calculatedCapex = _calculateTotalCapex();
    final calculatedOpex = _calculateTotalOpex();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CAPEX Section (unchanged)
          Row(
            children: [
              Icon(Icons.calculate, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Estimated CAPEX',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                ),
              ),
              const Spacer(),
              if (calculatedCapex != null)
                Text(
                  Formatters.formatCurrency(calculatedCapex),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue[900],
                  ),
                )
              else
                Text(
                  'Not calculated',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),

          if (calculatedCapex != null) ...[
            const SizedBox(height: 8),
            if (_primaryRoute?.totalCapex != null)
              _buildCapexDetailRow('Primary Route', _primaryRoute!.totalCapex!, Colors.blue),
            if (_secondaryRoute?.totalCapex != null)
              _buildCapexDetailRow('Secondary Route', _secondaryRoute!.totalCapex!, Colors.purple),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Add connectivity routes to calculate CAPEX',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],

          const Divider(height: 24),

          // ✅ NEW: Monthly OPEX Section
          Row(
            children: [
              Icon(Icons.trending_up, size: 20, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text(
                'Monthly OPEX',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (calculatedOpex != null)
                Text(
                  '${Formatters.formatCurrency(calculatedOpex)}/mo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange[900],
                  ),
                )
              else
                Text(
                  'Not calculated',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ✅ Operational costs breakdown
          if (_operationalCosts.isNotEmpty) ...[
            ..._operationalCosts.map((item) => _buildOpexDetailRow(
              item.description,
              item.monthlyCost,
              _getCategoryColor(item.category),
            )),
          ],

          const SizedBox(height: 8),

          // ✅ Add/Manage operational costs button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showOperationalCostsDialog,
              icon: Icon(_operationalCosts.isEmpty ? Icons.add : Icons.edit),
              label: Text(_operationalCosts.isEmpty
                  ? 'Add Operational Costs'
                  : 'Manage Operational Costs (${_operationalCosts.length})'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ✅ Helper for OPEX detail rows
  Widget _buildOpexDetailRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 4),
      child: Row(
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
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  // ✅ Show operational costs management dialog
  void _showOperationalCostsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OperationalCostsDialog(
          operationalCosts: _operationalCosts,
          onSave: (updatedCosts) {
            setState(() {
              _operationalCosts = updatedCosts;
              _updateOpexFromCosts(); // Auto-update OPEX
            });
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }


// ✅ Category colors
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'infrastructure':
        return Colors.blue;
      case 'power':
        return Colors.yellow[700]!;
      case 'maintenance':
        return Colors.green;
      case 'bandwidth':
        return Colors.purple;
      case 'licensing':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }


// Helper to build CAPEX detail rows (unchanged)
  Widget _buildCapexDetailRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 4),
      child: Row(
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
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const Spacer(),
          Text(
            Formatters.formatCurrency(amount),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }




  Widget _buildRequestSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request #${widget.request.requestNumber ?? widget.request.id}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.request.serviceLocation.city,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                'Connection',
                widget.request.serviceRequirements.connectionType.toUpperCase(),
              ),
              _buildSummaryItem(
                'Bandwidth',
                widget.request.serviceRequirements.bandwidth,
              ),
              _buildSummaryItem(
                'Urgency',
                _capitalize(widget.request.serviceRequirements.urgency),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildRouteEditor({
    required ConnectivityRoute? route,
    required List<CostItem> costItems,
    required Function(ConnectivityRoute?) onRouteChanged,
    required Function(List<CostItem>) onCostItemsChanged,
    required bool isPrimary,
  }) {
    // If route is null or not evaluated yet
    if (route == null) {
      return Column(
        children: [
          ElevatedButton.icon(
            onPressed: () => _showRouteDialog(
              route: null,
              costItems: [],
              onSave: (newRoute, newItems) {
                onRouteChanged(newRoute);
                onCostItemsChanged(newItems);
              },
              isPrimary: isPrimary,
            ),
            icon: const Icon(Icons.add),
            label: Text('Add ${isPrimary ? "Primary" : "Secondary"} Route'),
          ),
        ],
      );
    }

    // If route is marked as not feasible
    if (!route.isFeasible) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          border: Border.all(color: Colors.red[200]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel, color: Colors.red),
                const SizedBox(width: 12),
                const Text(
                  'Not Feasible',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showRouteDialog(
                    route: route,
                    costItems: costItems,
                    onSave: (newRoute, newItems) {
                      onRouteChanged(newRoute);
                      onCostItemsChanged(newItems);
                    },
                    isPrimary: isPrimary,
                  ),
                ),
              ],
            ),
            if (route.reason != null) ...[
              const SizedBox(height: 8),
              Text('Reason: ${route.reason}'),
            ],
            if (route.remarks != null) ...[
              const SizedBox(height: 8),
              Text('Remarks: ${route.remarks}'),
            ],
          ],
        ),
      );
    }

    // Route is feasible - show summary
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  route.routeName ?? 'Feasible Route',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showRouteDialog(
                  route: route,
                  costItems: costItems,
                  onSave: (newRoute, newItems) {
                    onRouteChanged(newRoute);
                    onCostItemsChanged(newItems);
                  },
                  isPrimary: isPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (route.sourceNodeName != null)
            _buildInfoRow('Source Node', route.sourceNodeName!),
          if (route.distanceKm != null)
            _buildInfoRow('Distance', '${route.distanceKm!.toStringAsFixed(2)} km'),
          if (route.technology != null)
            _buildInfoRow('Technology', route.technology!),
          if (route.totalFiberLengthMtr != null)
            _buildInfoRow('Fiber Length', '${route.totalFiberLengthMtr!.toStringAsFixed(0)} meters'),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consumable CAPEX',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    Formatters.formatCurrency(route.consumableCapex ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recoverable CAPEX',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    Formatters.formatCurrency(route.recoverableCapex ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total CAPEX',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    Formatters.formatCurrency(route.totalCapex ?? 0),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${costItems.length} cost items',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteSurveyEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('Site Survey Required'),
            value: _siteSurvey?.required ?? false,
            onChanged: (value) {
              setState(() {
                if (value) {
                  _siteSurvey = SiteSurvey(required: true);
                } else {
                  _siteSurvey = null;
                }
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          if (_siteSurvey?.required ?? false) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Survey Completed'),
              value: _siteSurvey?.completed ?? false,
              onChanged: (value) {
                setState(() {
                  _siteSurvey = SiteSurvey(
                    required: true,
                    completed: value,
                    surveyDate: value ? DateTime.now() : null,
                  );
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (_siteSurvey?.completed ?? false) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _showSiteSurveyDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Survey Details'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCommercialAssessment() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextFormField(
            controller: _capexController,
            label: 'Estimated CAPEX (₹)',
            hint: 'Total capital expenditure',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _buildTextFormField(
            controller: _opexController,
            label: 'Estimated Monthly OPEX (₹)',
            hint: 'Operational expenditure per month',
            keyboardType: TextInputType.number,
          ),
          // const SizedBox(height: 12),
          // _buildTextFormField(
          //   controller: _roiController,
          //   label: 'Estimated ROI Period (months)',
          //   hint: 'Return on investment period',
          //   keyboardType: TextInputType.number,
          // ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Commercially Viable'),
            value: _isCommerciallyViable,
            onChanged: (value) {
              setState(() => _isCommerciallyViable = value);
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionSelector() {
    return Column(
      children: [
        _buildDecisionOption(
          value: 'approve',
          icon: Icons.check_circle,
          title: 'Approve',
          description: 'This request is technically and commercially feasible',
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        _buildDecisionOption(
          value: 'reject',
          icon: Icons.cancel,
          title: 'Reject',
          description: 'This request is not feasible',
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildDecisionOption({
    required String value,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    final isSelected = _decision == value;
    return GestureDetector(
      onTap: () => setState(() => _decision = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? color : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? color : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int? minLines,
    int? maxLines,
    int? maxLength, // ✅ Add parameter
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        counterText: '', // ✅ Hide counter
      ),
      minLines: minLines,
      maxLines: maxLines ?? minLines,
      maxLength: maxLength, // ✅ Apply limit
      keyboardType: keyboardType,
      validator: validator,
    );
  }


  Color _getDecisionColor() {
    return _decision == 'approve' ? Colors.green : Colors.red;
  }

  String _getDecisionButtonText() {
    return _decision == 'approve' ? 'Approve Feasibility' : 'Reject Feasibility';
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // =====================================================
  // DIALOGS
  // =====================================================

  void _showRouteDialog({
    required ConnectivityRoute? route,
    required List<CostItem> costItems,
    required Function(ConnectivityRoute?, List<CostItem>) onSave,
    required bool isPrimary,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteEditorDialog(
          route: route,
          costItems: costItems,
          isPrimary: isPrimary,
          onSave: onSave,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _showSiteSurveyDialog() {
    final findingsController = TextEditingController(text: _siteSurvey?.findings);
    final recommendationsController = TextEditingController(text: _siteSurvey?.recommendations);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Site Survey Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: findingsController,
                decoration: const InputDecoration(
                  labelText: 'Findings',
                  hintText: 'Key observations from survey',
                  border: OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: recommendationsController,
                decoration: const InputDecoration(
                  labelText: 'Recommendations',
                  hintText: 'Suggested actions',
                  border: OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _siteSurvey = SiteSurvey(
                  required: true,
                  completed: true,
                  surveyDate: _siteSurvey?.surveyDate ?? DateTime.now(),
                  findings: findingsController.text.trim().isEmpty ? null : findingsController.text.trim(),
                  recommendations: recommendationsController.text.trim().isEmpty ? null : recommendationsController.text.trim(),
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmationDialog() async {
    final isReject = _decision == 'reject';
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isReject ? Icons.warning : Icons.check_circle,
              color: isReject ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 12),
            const Text('Confirm Decision'),
          ],
        ),
        content: Text(
          isReject
              ? 'Are you sure you want to REJECT this feasibility request?\n\n'
              'This will block the lead from proceeding to the next stage.'
              : 'Are you sure you want to APPROVE this feasibility request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isReject ? Colors.red : Colors.green,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isReject ? 'Yes, Reject' : 'Yes, Approve'),
          ),
        ],
      ),
    ) ??
        false;
  }

  // =====================================================
  // SUBMIT & SAVE
  // =====================================================

  Future<void> _submitDecision() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_primaryRoute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a primary connectivity route'),
          backgroundColor: Colors.red,
        ),
      );
      _tabController.animateTo(0);
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    final userId = _appState.userId;
    final calculatedCapex = _calculateTotalCapex();
    final calculatedOpex = _calculateTotalOpex(); // ✅ Auto-calculated

    final updates = <String, dynamic>{
      'status': _decision == 'approve' ? 'approved' : 'rejected',
      'is_feasible': _decision == 'approve',
      'feasibility_remarks': _remarksController.text.trim(),
      'reviewed_by': userId,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),

      if (_primaryRoute != null) 'primary_route': _primaryRoute!.toJson(),
      if (_secondaryRoute != null) 'secondary_route': _secondaryRoute!.toJson(),

      if (_siteSurvey != null) 'site_survey': _siteSurvey!.toJson(),

      // ✅ Auto-calculated CAPEX
      if (calculatedCapex != null)
        'estimated_capex': calculatedCapex,

      // ✅ Store operational costs
      if (_operationalCosts.isNotEmpty)
        'operational_costs': _operationalCosts.map((item) => item.toJson()).toList(),

      // ✅ Auto-calculated OPEX
      if (calculatedOpex != null)
        'estimated_opex': calculatedOpex,
    };

    final updated = await _feasibilityProvider.submitDecision(
      widget.request.id!,
      updates,
    );

    if (updated != null && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _decision == 'approve'
                ? '✓ Feasibility approved!'
                : '✗ Feasibility rejected',
          ),
          backgroundColor: _decision == 'approve' ? Colors.green : Colors.red,
        ),
      );
    }
  }





  Future<void> _saveDraft() async {
    if (!_hasChanges()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('No changes to save'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final userId = _appState.userId;
    final calculatedCapex = _calculateTotalCapex();
    final calculatedOpex = _calculateTotalOpex(); // ✅ Auto-calculated

    final updates = <String, dynamic>{
      'status': 'under_review',
      'reviewed_by': userId,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),

      if (_remarksController.text.trim().isNotEmpty)
        'feasibility_remarks': _remarksController.text.trim(),

      if (_primaryRoute != null)
        'primary_route': _primaryRoute!.toJson(),
      if (_secondaryRoute != null)
        'secondary_route': _secondaryRoute!.toJson(),

      if (_siteSurvey != null)
        'site_survey': _siteSurvey!.toJson(),

      // ✅ Auto-calculated CAPEX
      if (calculatedCapex != null)
        'estimated_capex': calculatedCapex,

      // ✅ FIXED: Always include operational_costs (null if empty)
      'operational_costs': _operationalCosts.isNotEmpty
          ? _operationalCosts.map((item) => item.toJson()).toList()
          : null, // ✅ Explicitly set to null when empty

      // ✅ FIXED: Always include estimated_opex (null if no costs)
      'estimated_opex': calculatedOpex, // Will be null if _operationalCosts is empty
    };

    final updated = await _feasibilityProvider.saveDraft(
      widget.request.id!,
      updates,
    );

    if (updated != null && mounted) {
      setState(() {
        _currentRequest = updated;
      });
      _storeOriginalState();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('✓ Draft saved successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }





}

// =====================================================
// ROUTE EDITOR DIALOG (Separate Page)
// =====================================================

class RouteEditorDialog extends StatefulWidget {
  final ConnectivityRoute? route;
  final List<CostItem> costItems;
  final bool isPrimary;
  final Function(ConnectivityRoute?, List<CostItem>) onSave;

  const RouteEditorDialog({
    Key? key,
    required this.route,
    required this.costItems,
    required this.isPrimary,
    required this.onSave,
  }) : super(key: key);

  @override
  State<RouteEditorDialog> createState() => _RouteEditorDialogState();
}

class _RouteEditorDialogState extends State<RouteEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  // Route feasibility
  bool _isFeasible = true;

  // Not feasible fields
  final _reasonController = TextEditingController();
  final _notFeasibleRemarksController = TextEditingController();

  // Feasible route fields
  final _routeNameController = TextEditingController();
  final _sourceNodeNameController = TextEditingController();
  final _distanceController = TextEditingController();
  final _technologyController = TextEditingController();
  final _fiberLengthController = TextEditingController();
  final _installDaysController = TextEditingController();
  final _feasibleRemarksController = TextEditingController();

  bool _infrastructureAvailable = false;
  bool _requiresRow = false;

  List<CostItem> _costItems = [];

  @override
  void initState() {
    super.initState();
    _costItems = List.from(widget.costItems);

    if (widget.route != null) {
      _isFeasible = widget.route!.isFeasible;

      if (!_isFeasible) {
        // Load not feasible data
        _reasonController.text = widget.route!.reason ?? '';
        _notFeasibleRemarksController.text = widget.route!.remarks ?? '';
      } else {
        // Load feasible route data
        _routeNameController.text = widget.route!.routeName ?? '';
        _sourceNodeNameController.text = widget.route!.sourceNodeName ?? '';
        _distanceController.text = widget.route!.distanceKm?.toString() ?? '';
        _technologyController.text = widget.route!.technology ?? '';
        _fiberLengthController.text = widget.route!.totalFiberLengthMtr?.toString() ?? '';
        _installDaysController.text = widget.route!.installationDays?.toString() ?? '';
        _feasibleRemarksController.text = widget.route!.remarks ?? '';
        _infrastructureAvailable = widget.route!.infrastructureAvailable ?? false;
        _requiresRow = widget.route!.requiresRow ?? false;
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notFeasibleRemarksController.dispose();
    _routeNameController.dispose();
    _sourceNodeNameController.dispose();
    _distanceController.dispose();
    _technologyController.dispose();
    _fiberLengthController.dispose();
    _installDaysController.dispose();
    _feasibleRemarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.isPrimary ? "Primary" : "Secondary"} Route',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent, // ✅ Make background transparent
        foregroundColor: Colors.white70,
        iconTheme: const IconThemeData(color: Colors.white), // ✅ White back button
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppState().appBarGradient, // ✅ Add gradient
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveRoute,
            icon: const Icon(Icons.save, size: 18, color: Colors.white),
            label: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(width: 8), // ✅ Add spacing from edge
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Feasibility Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('Route is feasible?'),
                    const Spacer(),
                    Switch(
                      value: _isFeasible,
                      onChanged: (value) {
                        setState(() => _isFeasible = value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Show appropriate fields based on feasibility
              if (!_isFeasible) ..._buildNotFeasibleFields() else ..._buildFeasibleFields(),
            ],
          ),
        ),
      ),
    );
  }


  List<Widget> _buildNotFeasibleFields() {
    return [
      const Text(
        'Route Not Feasible',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _reasonController,
        decoration: InputDecoration(
          labelText: 'Reason *',
          hintText: 'e.g., No fiber infrastructure available',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          counterText: '', // ✅ Hide counter
        ),
        maxLines: 2,
        maxLength: 200, // ✅ Limit: 200 chars
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Required';
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _notFeasibleRemarksController,
        decoration: InputDecoration(
          labelText: 'Additional Remarks',
          hintText: 'Any additional details',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          counterText: '', // ✅ Hide counter
        ),
        minLines: 3,
        maxLines: 5,
        maxLength: 500,
      ),
    ];
  }

  List<Widget> _buildFeasibleFields() {
    return [
      const Text(
        'Route Details',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),

      TextFormField(
        controller: _routeNameController,
        decoration: InputDecoration(
          labelText: 'Route Name *',
          hintText: 'e.g., Primary via Badarpur POP',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          counterText: '',
        ),
        maxLength: 100, // ✅ Limit: 100 chars
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Required';
          return null;
        },
      ),
      const SizedBox(height: 16),

      TextFormField(
        controller: _sourceNodeNameController,
        decoration: InputDecoration(
          labelText: 'Source Node Name *',
          hintText: 'e.g., TKD POP, Raj Enterprises Switch',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          counterText: '',
        ),
        maxLength: 50, // ✅ Limit: 100 chars
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Required';
          return null;
        },
      ),
      const SizedBox(height: 16),

      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _distanceController,
              decoration: InputDecoration(
                labelText: 'Distance (km) *',
                hintText: '2.5',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 5,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                if (double.tryParse(value!) == null) return 'Invalid';
                return null;
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _technologyController,
              decoration: InputDecoration(
                labelText: 'Technology *',
                hintText: 'Fiber/Wireless',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                counterText: '',
              ),
              maxLength: 50,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                return null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _fiberLengthController,
              decoration: InputDecoration(
                labelText: 'Fiber Length (meters)',
                hintText: '2500',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 5,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _installDaysController,
              decoration: InputDecoration(
                labelText: 'Installation Days',
                hintText: '15',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 3,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      SwitchListTile(
        title: const Text('Infrastructure Available'),
        value: _infrastructureAvailable,
        onChanged: (value) => setState(() => _infrastructureAvailable = value),
        contentPadding: EdgeInsets.zero,
      ),
      SwitchListTile(
        title: const Text('Requires Right of Way (ROW)'),
        value: _requiresRow,
        onChanged: (value) => setState(() => _requiresRow = value),
        contentPadding: EdgeInsets.zero,
      ),
      const SizedBox(height: 16),

      TextFormField(
        controller: _feasibleRemarksController,
        decoration: InputDecoration(
          labelText: 'Remarks',
          hintText: 'Additional notes',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          counterText: '',
        ),
        minLines: 3,
        maxLines: 5,
        maxLength: 500,
      ),
      const SizedBox(height: 24),

      // Cost Items Section
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Cost Items',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          ElevatedButton.icon(
            onPressed: _addCostItem,
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ],
      ),
      const SizedBox(height: 16),

      if (_costItems.isEmpty)
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No cost items added yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        )
      else
        ..._costItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildCostItemCard(item, index);
        }).toList(),

      if (_costItems.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildCostSummary(),
      ],
    ];
  }

  Widget _buildCostItemCard(CostItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          item.itemDescription,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${item.itemCode} • ${item.quantity.toStringAsFixed(0)} ${item.uom} • '
              '${Formatters.formatCurrency(item.totalCost)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editCostItem(index),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deleteCostItem(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostSummary() {
    double consumable = 0;
    double recoverable = 0;

    for (var item in _costItems) {
      if (item.category == 'Consumable Capex') {
        consumable += item.totalCost;
      } else if (item.category == 'Recoverable Capex') {
        recoverable += item.totalCost;
      }
    }

    final total = consumable + recoverable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Consumable CAPEX', consumable),
          const SizedBox(height: 8),
          _buildSummaryRow('Recoverable CAPEX', recoverable),
          const Divider(height: 24),
          _buildSummaryRow('Total CAPEX', total, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        Text(
          Formatters.formatCurrency(amount),
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            color: isTotal ? Colors.blue[900] : null,
          ),
        ),
      ],
    );
  }

  void _addCostItem() {
    _showCostItemDialog(null, -1);
  }

  void _editCostItem(int index) {
    _showCostItemDialog(_costItems[index], index);
  }

  void _deleteCostItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cost Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _costItems.removeAt(index));
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCostItemDialog(CostItem? item, int index) {
    final itemCodeController = TextEditingController(text: item?.itemCode);
    final itemDescController = TextEditingController(text: item?.itemDescription);
    final quantityController = TextEditingController(text: item?.quantity.toString());
    final unitPriceController = TextEditingController(text: item?.unitPrice.toString());
    String category = item?.category ?? 'Consumable Capex';
    String uom = item?.uom ?? 'Mtr';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Add Cost Item' : 'Edit Cost Item'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: itemCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Item Code',
                        hintText: 'e.g., FBR-6F',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      maxLength: 50, // ✅ Limit: 50 chars
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: itemDescController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Item description',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      minLines: 2,
                      maxLines: 3,
                      maxLength: 200, // ✅ Limit: 200 chars
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: ['Consumable Capex', 'Recoverable Capex']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => category = value!);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 10, // ✅ Limit: 10 chars
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: uom,
                      decoration: const InputDecoration(
                        labelText: 'Unit of Measurement',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: ['Mtr', 'Nos', 'Roll', 'Day', 'Hour', 'Lump Sum']
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => uom = value!);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Unit Price (₹)',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 15, // ✅ Limit: 15 chars (large numbers)
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text) ?? 0;
              final unitPrice = double.tryParse(unitPriceController.text) ?? 0;
              final totalCost = quantity * unitPrice;

              final newItem = CostItem(
                itemCode: itemCodeController.text.trim(),
                itemDescription: itemDescController.text.trim(),
                category: category,
                uom: uom,
                quantity: quantity,
                unitPrice: unitPrice,
                totalCost: totalCost,
              );

              setState(() {
                if (index >= 0) {
                  _costItems[index] = newItem;
                } else {
                  _costItems.add(newItem);
                }
              });

              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }



  void _saveRoute() {
    if (!_formKey.currentState!.validate()) return;

    ConnectivityRoute? route;

    if (!_isFeasible) {
      // Create not feasible route
      route = ConnectivityRoute.notFeasible(
        reason: _reasonController.text.trim(),
        remarks: _notFeasibleRemarksController.text.trim().isEmpty
            ? null
            : _notFeasibleRemarksController.text.trim(),
      );
      widget.onSave(route, []);
    } else {
      // Create feasible route
      route = ConnectivityRoute.feasible(
        routeName: _routeNameController.text.trim(),
        sourceNodeName: _sourceNodeNameController.text.trim(),
        distanceKm: double.parse(_distanceController.text.trim()),
        technology: _technologyController.text.trim(),
        totalFiberLengthMtr: _fiberLengthController.text.trim().isEmpty
            ? 0
            : double.parse(_fiberLengthController.text.trim()),
        costItems: _costItems,
        infrastructureAvailable: _infrastructureAvailable,
        requiresRow: _requiresRow,
        installationDays: _installDaysController.text.trim().isEmpty
            ? null
            : int.parse(_installDaysController.text.trim()),
        remarks: _feasibleRemarksController.text.trim().isEmpty
            ? null
            : _feasibleRemarksController.text.trim(),
      );
      widget.onSave(route, _costItems);
    }

    Navigator.pop(context);
  }
}


