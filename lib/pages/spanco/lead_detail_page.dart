import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../models/spanco/spanco_lead.dart';
import '../../models/spanco/spanco_stage_history.dart';
import '../../providers/feasibility_provider.dart';
import '../../providers/lead_provider.dart';
import '../feasibility/feasibility_detail_page.dart';
import '../feasibility/feasibility_form_page.dart';
import 'lead_form_page.dart';

class LeadDetailPage extends StatefulWidget {
  final int leadId;

  const LeadDetailPage({
    Key? key,
    required this.leadId,
  }) : super(key: key);

  @override
  State<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends State<LeadDetailPage> {
  late LeadProvider _leadProvider;
  late FeasibilityProvider _feasibilityProvider;
  SpancoLead? _lead;
  Map<String, dynamic>? _feasibilityStatus; // 🆕 ADD THIS
// ✅ ADD THIS


  bool _isEditing = false;

  // ✅ ADD: Notes editing state
  bool _isEditingNotes = false;
  bool _isSavingNotes = false;
  // ✅ FIX: Don't use 'late' - initialize directly
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _internalNotesController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _leadProvider = Provider.of<LeadProvider>(context, listen: false);
    _feasibilityProvider = Provider.of<FeasibilityProvider>(context, listen: false);
    _loadLead();
  }

  Future<void> _loadLead() async {
    final lead = await _leadProvider.getLeadById(widget.leadId);
    setState(() {
      _lead = lead;
      if (lead != null) {
        _remarksController.text = lead.remarks ?? '';
        _internalNotesController.text = lead.internalNotes ?? '';
      }
    });

    // ✅ UPDATED: Check feasibility status for all stages
    if (lead != null) {
      _loadFeasibilityStatus();
    }
  }


  Future<void> _loadFeasibilityStatus() async {
    // ✅ UPDATED: Load feasibility for all stages (not just Approach+)
    if (_lead == null) return;

    final status = await _leadProvider.checkStageMovement(_lead!.id!);
    setState(() {
      _feasibilityStatus = status;
    });
  }



  @override
  void dispose() {
    _remarksController.dispose();
    _internalNotesController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: _lead?.leadNumber != null
            ? Text(
          'Lead #${_lead!.leadNumber}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        )
            : const Text(
          'Lead Details',
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
          if (_lead != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              itemBuilder: (context) {
                final isActive = _lead!.status == LeadStatus.active;
                final isLost = _lead!.status == LeadStatus.lost;
                final isOrderStage = _lead!.currentStage == SpancoStage.order; // ✅ NEW

                return [
                  // ✅ Edit (always available)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Edit Lead'),
                      ],
                    ),
                  ),

                  // ✅ Divider
                  if (isActive || isLost)
                    const PopupMenuDivider(),

                  // ✅ UPDATED: Mark as Won (only for Order stage AND active)
                  if (isActive && isOrderStage)
                    const PopupMenuItem(
                      value: 'mark_won',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 18, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Mark as Won', style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ),

                  // ✅ Mark as Lost (for all active leads, any stage)
                  if (isActive)
                    const PopupMenuItem(
                      value: 'mark_lost',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Mark as Lost', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),

                  // ✅ Re-qualify (only for lost leads)
                  if (isLost)
                    const PopupMenuItem(
                      value: 'requalify',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Re-qualify Lead', style: TextStyle(color: Colors.orange)),
                        ],
                      ),
                    ),
                ];
              },
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    await _navigateToEditLead();
                    break;
                  case 'mark_won':
                    _showMarkWonDialog();
                    break;
                  case 'mark_lost':
                    _showMarkLostDialog();
                    break;
                  case 'requalify':
                    _showRequalifyDialog();
                    break;
                }
              },
            ),
        ],


        // actions: [
        //   if (_lead != null)
        //     PopupMenuButton<String>(
        //       icon: const Icon(Icons.more_vert, color: Colors.white),
        //       itemBuilder: (context) => [
        //         const PopupMenuItem(
        //           value: 'edit',
        //           child: Row(
        //             children: [
        //               Icon(Icons.edit, size: 18),
        //               SizedBox(width: 8),
        //               Text('Edit Lead'),
        //             ],
        //           ),
        //         ),
        //         // const PopupMenuItem(
        //         //   value: 'assign',
        //         //   child: Row(
        //         //     children: [
        //         //       Icon(Icons.person_add, size: 18),
        //         //       SizedBox(width: 8),
        //         //       Text('Assign'),
        //         //     ],
        //         //   ),
        //         // ),
        //         // const PopupMenuItem(
        //         //   value: 'delete',
        //         //   child: Row(
        //         //     children: [
        //         //       Icon(Icons.delete, size: 18, color: Colors.red),
        //         //       SizedBox(width: 8),
        //         //       Text('Delete', style: TextStyle(color: Colors.red)),
        //         //     ],
        //         //   ),
        //         // ),
        //       ],
        //       onSelected: (value) async {
        //         switch (value) {
        //           case 'edit':
        //             await _navigateToEditLead();
        //             break;
        //           case 'assign':
        //             ScaffoldMessenger.of(context).showSnackBar(
        //               const SnackBar(content: Text('Assign feature coming soon')),
        //             );
        //             break;
        //           case 'delete':
        //             ScaffoldMessenger.of(context).showSnackBar(
        //               const SnackBar(content: Text('Delete feature coming soon')),
        //             );
        //             break;
        //         }
        //       },
        //     ),
        // ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppState().bodyGradient,
          ),
          child: Consumer<LeadProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading || _lead == null) {
                // ✅ Show loading if provider is loading OR lead is not yet loaded
                if (_lead == null) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  );
                }
              }

              if (_lead == null) {
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
                        'Lead not found',
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

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // Header Card
                    _buildHeaderCard(_lead!),

                    // 🆕 FEASIBILITY STATUS CARD
                    _buildFeasibilityStatusCard(),

                    const SizedBox(height: 16),

                    // Main Details
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Information Section
                          _buildSection(
                            'Customer Information',
                            [
                              _buildDetailRow('Name', _lead!.customerName),
                              _buildDetailRow('Type', _lead!.customerType.label),
                              if (_lead!.contactPerson != null)
                                _buildDetailRow('Contact Person', _lead!.contactPerson!),
                              GestureDetector(
                                onTap: () => launchUrl(Uri.parse('tel:${_lead!.contactPhone}')),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Phone',
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
                                            Icon(Icons.phone, size: 16, color: Colors.blue[700]),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                _lead!.contactPhone,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue[700],
                                                  decoration: TextDecoration.underline,
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
                              if (_lead!.contactEmail != null)
                                _buildDetailRow('Email', _lead!.contactEmail!),
                              if (_lead!.alternatePhone != null)
                                _buildDetailRow(
                                  'Alternate Phone',
                                  _lead!.alternatePhone!,
                                ),
                              if (_lead!.companyName != null)
                                _buildDetailRow('Company', _lead!.companyName!),
                              if (_lead!.gstin != null)
                                _buildDetailRow('GSTIN', _lead!.gstin!),
                              if (_lead!.pan != null)
                                _buildDetailRow('PAN', _lead!.pan!),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Location Information Section
                          _buildSection(
                            'Service Location',
                            [
                              _buildDetailRow('Address', _lead!.serviceAddress),
                              _buildDetailRow('City', _lead!.serviceCity),
                              _buildDetailRow('State', _lead!.serviceState),
                              _buildDetailRow('Pincode', _lead!.servicePincode),
                              if (_lead!.landmark != null)
                                _buildDetailRow('Landmark', _lead!.landmark!),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Service Requirements Section
                          // Service Requirements Section
                          _buildSection(
                            'Service Requirements',
                            [
                              // ✅ Show service type label
                              _buildDetailRow(
                                'Service Type',
                                _lead!.customerType == CustomerType.enterprise
                                    ? 'Partner'
                                    : _lead!.customerType == CustomerType.individual
                                    ? 'Bandwidth'
                                    : 'Leased Line',
                              ),

                              // ✅ Partner-specific fields
                              if (_lead!.customerType == CustomerType.enterprise) ...[
                                if (_lead!.currentCustomers != null)
                                  _buildDetailRow(
                                    'Current Customers (Estimate)',
                                    '${_lead!.currentCustomers}',
                                  ),
                                if (_lead!.expectedCustomers != null)
                                  _buildDetailRow(
                                    'Expected Customers',
                                    '${_lead!.expectedCustomers}',
                                  ),
                              ],

                              // ✅ Bandwidth type: Show only bandwidth required
                              if (_lead!.customerType == CustomerType.individual) ...[
                                _buildDetailRow(
                                  'Bandwidth Required',
                                  _lead!.bandwidthRequired,
                                ),
                              ],

                              // ✅ Leased Line type: Show all fields
                              if (_lead!.customerType == CustomerType.business) ...[
                                _buildDetailRow(
                                  'Bandwidth Required',
                                  _lead!.bandwidthRequired,
                                ),
                                if (_lead!.planInterest != null)
                                  _buildDetailRow(
                                    'Plan Interest',
                                    _lead!.planInterest!,
                                  ),
                                _buildDetailRow(
                                  'Number of Connections',
                                  '${_lead!.numberOfConnections}',
                                ),
                              ],
                            ],
                          ),




                          // Commercial Details Section
                          const SizedBox(height: 24),

                          if (_lead!.estimatedValue != null)
                            _buildSection(
                              'Commercial Details',
                              [
                                _buildDetailRow(
                                  'Estimated Value',
                                  '₹${_lead!.estimatedValue!.toStringAsFixed(0)}',
                                ),
                              ],
                            ),

                          const SizedBox(height: 24),

                          // Status & Dates Section
                          _buildSection(
                            'Status & Dates',
                            [
                              _buildDetailRow('Status', _lead!.status.label),
                              _buildDetailRow('Priority', _lead!.priority.label),
                              if (_lead!.expectedClosureDate != null)
                                _buildDetailRow(
                                  'Expected Closure',
                                  _formatDate(_lead!.expectedClosureDate!),
                                ),
                              if (_lead!.wonDate != null)
                                _buildDetailRow(
                                  'Won Date',
                                  _formatDate(_lead!.wonDate!),
                                ),
                              if (_lead!.lostReason != null) ...[
                                _buildDetailRow('Lost Reason', _lead!.lostReason!),
                                if (_lead!.lostRemarks != null)
                                  _buildDetailRow(
                                    'Lost Remarks',
                                    _lead!.lostRemarks!,
                                  ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Additional Info Section
                          _buildSection(
                            'Additional Information',
                            [
                              if (_lead!.leadSource != null)
                                _buildDetailRow(
                                  'Lead Source',
                                  _lead!.leadSource!.label,
                                ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ✅ NEW: Notes & Remarks Section
                          _buildNotesSection(),

                          const SizedBox(height: 24),

                          // Stage History Section
                          _buildStageHistorySection(provider),

                          const SizedBox(height: 24),

                          // Action Buttons
                          if (_lead!.status == LeadStatus.active)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _showMoveStageDialog,
                                  icon: const Icon(Icons.low_priority),
                                  label: const Text(
                                    'Change Stage',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                ),

                                // const SizedBox(height: 12),
                                // ElevatedButton.icon(
                                //   onPressed: _showMarkWonDialog,
                                //   icon: const Icon(Icons.check_circle),
                                //   label: const Text('Mark as Won'),
                                //   style: ElevatedButton.styleFrom(
                                //     backgroundColor: Colors.green.shade700,
                                //     foregroundColor: Colors.white,
                                //     padding: const EdgeInsets.symmetric(vertical: 14),
                                //     shape: RoundedRectangleBorder(
                                //       borderRadius: BorderRadius.circular(12),
                                //     ),
                                //     elevation: 0,
                                //   ),
                                // ),

                                // const SizedBox(height: 12),
                                // OutlinedButton.icon(
                                //   onPressed: _showMarkLostDialog,
                                //   icon: const Icon(Icons.cancel),
                                //   label: const Text(
                                //     'Mark as Lost',
                                //     style: TextStyle(
                                //       fontWeight: FontWeight.w600,
                                //       fontSize: 15,
                                //     ),
                                //   ),
                                //   style: OutlinedButton.styleFrom(
                                //     foregroundColor: Colors.red.shade700,
                                //     side: BorderSide(color: Colors.red.shade700, width: 1.5),
                                //     padding: const EdgeInsets.symmetric(vertical: 14),
                                //     shape: RoundedRectangleBorder(
                                //       borderRadius: BorderRadius.circular(12),
                                //     ),
                                //   ),
                                // ),
                                const SizedBox(height: 32),
                              ],
                            )
                          // else if (_lead!.status == LeadStatus.lost)
                          //   _buildLostLeadActions(),

                          // const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }


  Widget _buildHeaderCard(SpancoLead lead) {
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
                backgroundColor: lead.currentStage.color,
                child: Text(
                  lead.customerName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.customerName,
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
                        color: lead.currentStage.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        lead.currentStage.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: lead.currentStage.color,
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
              _buildHeaderStat('Created', _formatDate(lead.createdAt!)),
              _buildHeaderStat('Days in Stage',
                  _daysInStage(lead.stageUpdatedAt).toString()),
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
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  /// ✅ UPDATED: Editable Notes Section
  Widget _buildNotesSection() {
    final hasNotes = (_lead!.remarks != null && _lead!.remarks!.isNotEmpty) ||
        (_lead!.internalNotes != null && _lead!.internalNotes!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Notes & Remarks',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            // ✅ Edit/Save/Cancel buttons
            if (!_isEditingNotes)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditingNotes = true;
                    _remarksController.text = _lead!.remarks ?? '';
                    _internalNotesController.text = _lead!.internalNotes ?? '';
                  });
                },
                icon: Icon(
                  hasNotes ? Icons.edit : Icons.add,
                  size: 18,
                ),
                label: Text(hasNotes ? 'Edit' : 'Add Notes'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              )
            else
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _isSavingNotes ? null : () { // ✅ UPDATED: Disable when saving
                      setState(() {
                        _isEditingNotes = false;
                        _remarksController.text = _lead!.remarks ?? '';
                        _internalNotesController.text = _lead!.internalNotes ?? '';
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isSavingNotes ? null : _saveNotes, // ✅ UPDATED: Disable when saving
                    icon: _isSavingNotes // ✅ UPDATED: Show loading spinner
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Icon(Icons.save, size: 18),
                    label: Text(_isSavingNotes ? 'Saving...' : 'Save'), // ✅ UPDATED: Change text
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ✅ Editable or Display mode
        if (_isEditingNotes)
          _buildEditableNotes()
        else if (hasNotes)
          _buildDisplayNotes()
        else
          _buildEmptyNotesPlaceholder(),
      ],
    );
  }


  /// ✅ NEW: Editable notes form
  Widget _buildEditableNotes() {
    return Column(
      children: [
        // Remarks field
        TextFormField(
          controller: _remarksController,
          decoration: InputDecoration(
            labelText: 'Remarks',
            hintText: 'General notes or comments visible to team',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.notes),
            filled: true,
            fillColor: Colors.blue[50],
          ),
          minLines: 3,
          maxLines: 5,
          maxLength: 500,
        ),
        const SizedBox(height: 12),

        // Internal notes field
        TextFormField(
          controller: _internalNotesController,
          decoration: InputDecoration(
            labelText: 'Internal Notes',
            hintText: 'Private notes for internal use only',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.lock_outline),
            filled: true,
            fillColor: Colors.orange[50],
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text(
                  'Private',
                  style: TextStyle(fontSize: 10),
                ),
                backgroundColor: Colors.orange[200],
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          minLines: 3,
          maxLines: 5,
          maxLength: 1000,
        ),
      ],
    );
  }

  /// ✅ NEW: Display notes (non-editable view)
  Widget _buildDisplayNotes() {
    return Column(
      children: [
        // Remarks (if exists)
        if (_lead!.remarks != null && _lead!.remarks!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border.all(color: Colors.blue[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notes, size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Remarks',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _lead!.remarks!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Internal Notes (if exists)
        if (_lead!.internalNotes != null && _lead!.internalNotes!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 18, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Internal Notes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[900],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Private',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _lead!.internalNotes!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// ✅ NEW: Empty state placeholder
  Widget _buildEmptyNotesPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No notes yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Click "Add Notes" to add remarks or internal notes',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  /// ✅ UPDATED: Save notes method with change detection
  Future<void> _saveNotes() async {
    if (_lead == null) return;

    final newRemarks = _remarksController.text.trim();
    final newInternalNotes = _internalNotesController.text.trim();

    // ✅ NEW: Get original values (handle null as empty string)
    final originalRemarks = _lead!.remarks ?? '';
    final originalInternalNotes = _lead!.internalNotes ?? '';

    // ✅ NEW: Check if anything actually changed
    final remarksChanged = newRemarks != originalRemarks;
    final internalNotesChanged = newInternalNotes != originalInternalNotes;

    if (!remarksChanged && !internalNotesChanged) {
      // ✅ NEW: Nothing changed, just exit edit mode
      setState(() {
        _isEditingNotes = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes to save'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return; // Exit early
    }

    // ✅ Continue with save if something changed
    setState(() {
      _isSavingNotes = true;
    });

    // Create notes JSONB object
    final notesJson = {
      'remarks': newRemarks.isEmpty ? null : newRemarks,
      'internal_notes': newInternalNotes.isEmpty ? null : newInternalNotes,
      'tags': _lead!.notes?.tags, // Preserve existing tags
    };

    try {
      await _leadProvider.updateLead(
        _lead!.id!,
        {'notes': notesJson},
      );

      setState(() {
        _isEditingNotes = false;
        _isSavingNotes = false;
      });

      // Reload lead to get updated data
      await _loadLead();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSavingNotes = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update notes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageHistorySection(LeadProvider provider) {
    final history = provider.stageHistory;

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
            'Stage History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            history.isEmpty
                ? 'No stage changes yet'
                : '${history.length} stage change${history.length > 1 ? 's' : ''}',
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
                      'No stage history available',
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
                    // ✅ NEW: Show scrollbar only when there are more than 5 items
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
                        final item = history[index];
                        return _buildStageHistoryItem(item, index == 0);
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


  Widget _buildStageHistoryItem(SpancoStageHistory history, bool isLatest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isLatest ? Colors.blue : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLatest)
                Container(
                  width: 2,
                  height: 24,
                  color: Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Safe display with null check
                Text(
                  history.fromStage != null
                      ? '${history.fromStageLabel} → ${history.toStageLabel}'
                      : 'Created as ${history.toStageLabel}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(history.changedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                // ✅ Only show if not null
                if (history.changeReason != null && history.changeReason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${history.changeReason}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                // ✅ Only show if not null
                if (history.remarks != null && history.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Remarks: ${history.remarks}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                // ✅ Only show if not null
                if (history.daysInPreviousStage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Duration: ${history.daysInStageFormatted}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildLostLeadActions() {
    if (_lead?.status != LeadStatus.lost) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        const Text(
          'Lost Lead Actions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _showRequalifyDialog,
          icon: const Icon(Icons.refresh),
          label: const Text('Re-qualify Lead'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber,
          ),
        ),
      ],
    );
  }


  /// ✅ UPDATED: Build feasibility status card
  Widget _buildFeasibilityStatusCard() {
    // ✅ Hide if lead is null
    if (_lead == null) {
      return const SizedBox.shrink();
    }

    // Loading state
    if (_feasibilityStatus == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Checking feasibility status...'),
          ],
        ),
      );
    }

    final status = _feasibilityStatus!['status'] as String;
    final canMove = _feasibilityStatus!['canMove'] as bool;
    final reason = _feasibilityStatus!['reason'] as String;
    final requestNumber = _feasibilityStatus!['requestNumber'] as String?;

    // ✅ NEW: Check if lead is won or lost
    final isWonOrLost = _lead!.status == LeadStatus.won || _lead!.status == LeadStatus.lost;

    // ✅ UPDATED: For won/lost leads, hide card if no request exists
    if (isWonOrLost && status == 'no_request') {
      return const SizedBox.shrink();
    }

    // Determine card styling based on status
    Color backgroundColor;
    Color borderColor;
    Color iconColor;
    IconData icon;
    String statusLabel;
    String? actionText;
    VoidCallback? onActionPressed;

    switch (status) {
      case 'no_request':
        backgroundColor = Colors.blue[50]!;
        borderColor = Colors.blue[300]!;
        iconColor = Colors.blue;
        icon = Icons.assignment_outlined;
        statusLabel = 'Feasibility Check Available';
        actionText = 'Create Request';
        onActionPressed = _navigateToCreateFeasibility;
        break;

      case 'pending':
        backgroundColor = Colors.orange[50]!;
        borderColor = Colors.orange[300]!;
        iconColor = Colors.orange;
        icon = Icons.hourglass_empty;
        statusLabel = 'Feasibility Pending';
        actionText = 'View Status';
        onActionPressed = () => _navigateToFeasibilityDetail(requestNumber!);
        break;

      case 'under_review':
        backgroundColor = Colors.blue[50]!;
        borderColor = Colors.blue[300]!;
        iconColor = Colors.blue;
        icon = Icons.rate_review;
        statusLabel = 'Under Review';
        actionText = 'View Progress';
        onActionPressed = () => _navigateToFeasibilityDetail(requestNumber!);
        break;

      case 'awaiting_approval':
        backgroundColor = Colors.purple[50]!;
        borderColor = Colors.purple[300]!;
        iconColor = Colors.purple;
        icon = Icons.pending_actions;
        statusLabel = 'Awaiting Final Approval';
        actionText = 'View Details';
        onActionPressed = () => _navigateToFeasibilityDetail(requestNumber!);
        break;

      case 'approved':
        backgroundColor = Colors.green[50]!;
        borderColor = Colors.green[300]!;
        iconColor = Colors.green;
        icon = Icons.check_circle;
        statusLabel = 'Feasibility Approved';
        actionText = 'View Report';
        onActionPressed = () => _navigateToFeasibilityDetail(requestNumber!);
        break;

      case 'rejected':
        backgroundColor = Colors.red[50]!;
        borderColor = Colors.red[300]!;
        iconColor = Colors.red;
        icon = Icons.cancel;
        statusLabel = 'Feasibility Rejected';
        actionText = 'View Rejection';
        onActionPressed = () => _navigateToFeasibilityDetail(requestNumber!);
        break;

      case 'cancelled':
        backgroundColor = Colors.grey[100]!;
        borderColor = Colors.grey[400]!;
        iconColor = Colors.grey;
        icon = Icons.block;
        statusLabel = 'Feasibility Cancelled';
        // ✅ UPDATED: Don't show "Create New" for won/lost leads
        actionText = isWonOrLost ? 'View Details' : 'Create New';
        onActionPressed = isWonOrLost
            ? () => _navigateToFeasibilityDetail(requestNumber!)
            : _navigateToCreateFeasibility;
        break;

      default:
        backgroundColor = Colors.grey[100]!;
        borderColor = Colors.grey[300]!;
        iconColor = Colors.grey;
        icon = Icons.help_outline;
        statusLabel = 'Status Unknown';
        actionText = null;
        onActionPressed = null;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Status Label
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: iconColor,
                                  ),
                                ),
                              ),
                              // ✅ Show lead status badge for won/lost leads
                              if (isWonOrLost) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _lead!.status == LeadStatus.won
                                        ? Colors.green[200]
                                        : Colors.red[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _lead!.status.label.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _lead!.status == LeadStatus.won
                                          ? Colors.green[900]
                                          : Colors.red[900],
                                    ),
                                  ),
                                ),
                              ]
                              // Show stage badge for active leads
                              else if (status == 'no_request' || status == 'cancelled') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _lead!.currentStage.label.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (requestNumber != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Request: $requestNumber',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Button below
                if (actionText != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onActionPressed,
                      icon: Icon(
                        status == 'no_request' || (status == 'cancelled' && !isWonOrLost)
                            ? Icons.add_circle_outline
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      label: Text(actionText),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: iconColor,
                        side: BorderSide(color: iconColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              border: Border(
                top: BorderSide(color: borderColor.withOpacity(0.3)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason,
                  style: const TextStyle(fontSize: 13),
                ),
                // ✅ Don't show create hint for won/lost leads
                if (status == 'no_request' && !isWonOrLost) ...[
                  const SizedBox(height: 8),
                  Text(
                    '💡 Request a feasibility check to assess technical viability and costs for this lead',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
                // ✅ UPDATED: Show different message for cancelled status on won/lost leads
                if (status == 'cancelled') ...[
                  const SizedBox(height: 8),
                  Text(
                    isWonOrLost
                        ? '📋 Previous feasibility request was cancelled - view-only mode'
                        : '♻️ Previous request was cancelled. You can create a new feasibility request',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isWonOrLost ? Colors.grey[600] : Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Progress indicator for in-progress statuses
          if (status == 'under_review') ...[
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Department Review Progress',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'In Progress',
                        style: TextStyle(
                          fontSize: 12,
                          color: iconColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: null, // Indeterminate
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                ],
              ),
            ),
          ],

          // ✅ UPDATED: Softer warning for rejected status
          if (status == 'rejected') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[100],
                border: Border(
                  top: BorderSide(color: Colors.red[300]!),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Feasibility assessment shows technical or commercial constraints',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[900],
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
    );
  }





  Future<void> _showMoveStageDialog() async {
    if (_lead == null) return;

    final currentStage = _lead!.currentStage;

    // ✅ Check if lead is won/lost - cannot move
    if (currentStage.isOutcome) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentStage == SpancoStage.won
                ? 'Won leads cannot be moved to another stage'
                : 'Lost leads cannot be moved. Use Re-qualify instead.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ Check if already at final stage (Order)
    if (currentStage == SpancoStage.order) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already at final stage. Use Mark as Won/Lost instead.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ UPDATED: Get only active stages, exclude current and outcomes (won/lost)
    final availableStages = SpancoStage.activeStages
        .where((stage) => stage != currentStage)
        .toList();

    // Show stage selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Lead to Stage'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current: ${currentStage.label}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select new stage:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              // ✅ List of available stages (won/lost excluded)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableStages.length,
                  itemBuilder: (context, index) {
                    final stage = availableStages[index];
                    final isOrderStage = stage == SpancoStage.order;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: stage.color.withOpacity(0.2),
                        child: Text(
                          '${stage.stageOrder}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: stage.color,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              stage.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isOrderStage)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Final',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: Icon(
                        stage.stageOrder > currentStage.stageOrder
                            ? Icons.arrow_forward
                            : Icons.arrow_back,
                        color: stage.stageOrder > currentStage.stageOrder
                            ? Colors.green
                            : Colors.orange,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.pop(context);

                        // ✅ Show confirmation for Order stage
                        if (isOrderStage) {
                          _showOrderStageConfirmation(stage);
                        } else {
                          _confirmStageMove(stage);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }


  /// ✅ NEW: Show confirmation for moving to Order stage (final stage)
  Future<void> _showOrderStageConfirmation(SpancoStage orderStage) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Expanded(child: Text('Confirm Final Stage')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to move "${_lead!.customerName}" to the final stage: ${orderStage.label}.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Important:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• This is the final stage\n'
                        '• Lead cannot be moved backward\n'
                        '• Only mark as Won/Lost will be available',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange[900],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to proceed?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange[700],
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Move to Order'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _performStageMove(orderStage);
    }
  }

  /// ✅ NEW: Show regular confirmation for non-Order stages
  Future<void> _confirmStageMove(SpancoStage newStage) async {
    final currentStage = _lead!.currentStage;
    final isForward = newStage.stageOrder > currentStage.stageOrder;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isForward ? 'Move Forward' : 'Move Backward'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Move "${_lead!.customerName}"',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'From',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentStage.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    isForward ? Icons.arrow_forward : Icons.arrow_back,
                    color: isForward ? Colors.green : Colors.orange,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: newStage.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: newStage.color,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'To',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          newStage.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: newStage.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _performStageMove(newStage);
    }
  }

  /// ✅ NEW: Perform the actual stage move
  Future<void> _performStageMove(SpancoStage newStage) async {
    try {
      await _leadProvider.moveToStage(_lead!.id!, newStage);
      await _loadLead();

      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text('Lead moved to ${newStage.label}'),
      //       backgroundColor: Colors.green,
      //     ),
      //   );
      // }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move lead: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  // Future<void> _showMoveNextStageDialog() async {
  //   if (_lead == null) return;
  //
  //   final currentOrder = _lead!.currentStage.stageOrder;
  //   final nextStage = SpancoStage.values.firstWhere(
  //         (s) => s.stageOrder == currentOrder + 1,
  //     orElse: () => _lead!.currentStage,
  //   );
  //
  //   if (nextStage == _lead!.currentStage) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Already at final stage')),
  //     );
  //     return;
  //   }
  //
  //   // 🆕 CHECK FEASIBILITY REQUIREMENT
  //   // if (_lead!.currentStage == SpancoStage.approach) {
  //   //   final checkResult = await _leadProvider.checkStageMovement(_lead!.id!);
  //   //
  //   //   if (!checkResult['canMove']) {
  //   //     _showFeasibilityBlockDialog(checkResult);
  //   //     return;
  //   //   }
  //   //
  //   //   // If feasibility approved, show normal move dialog
  //   //   if (checkResult['conditions'] == true) {
  //   //     _showMoveWithConditionsDialog(nextStage, checkResult);
  //   //     return;
  //   //   }
  //   // }
  //
  //   // Normal stage move dialog
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Move to Next Stage'),
  //       content: Text(
  //         'Move "${_lead!.customerName}" from ${_lead!.currentStage.label} to ${nextStage.label}?',
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         FilledButton(
  //           onPressed: () {
  //             _leadProvider.moveToNextStage(_lead!.id!);
  //             Navigator.pop(context);
  //             _loadLead();
  //           },
  //           child: const Text('Move'),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  //
  // /// Show dialog when feasibility blocks stage movement
  // void _showFeasibilityBlockDialog(Map<String, dynamic> checkResult) {
  //   final status = checkResult['status'] as String;
  //   final reason = checkResult['reason'] as String;
  //   final requestNumber = checkResult['requestNumber'] as String?;
  //
  //   IconData icon;
  //   Color iconColor;
  //   String title;
  //   List<Widget> actions = [];
  //
  //   switch (status) {
  //     case 'no_request':
  //       icon = Icons.assignment_outlined;
  //       iconColor = Colors.blue;
  //       title = 'Feasibility Required';
  //       actions = [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         FilledButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //             _navigateToCreateFeasibility();
  //           },
  //           child: const Text('Create Feasibility Request'),
  //         ),
  //       ];
  //       break;
  //
  //     case 'pending':
  //     case 'under_review':
  //     case 'awaiting_approval':
  //       icon = Icons.hourglass_empty;
  //       iconColor = Colors.orange;
  //       title = 'Feasibility In Progress';
  //       actions = [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Close'),
  //         ),
  //         FilledButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //             _navigateToFeasibilityDetail(requestNumber!);
  //           },
  //           child: const Text('View Feasibility'),
  //         ),
  //       ];
  //       break;
  //
  //     case 'rejected':
  //       icon = Icons.cancel;
  //       iconColor = Colors.red;
  //       title = 'Feasibility Rejected';
  //       actions = [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Close'),
  //         ),
  //         FilledButton(
  //           style: FilledButton.styleFrom(backgroundColor: Colors.red),
  //           onPressed: () {
  //             Navigator.pop(context);
  //             _showMarkAsLostDialog('Feasibility rejected');
  //           },
  //           child: const Text('Mark Lead as Lost'),
  //         ),
  //       ];
  //       break;
  //
  //     case 'cancelled':
  //       icon = Icons.refresh;
  //       iconColor = Colors.blue;
  //       title = 'Feasibility Cancelled';
  //       actions = [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         FilledButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //             _navigateToCreateFeasibility();
  //           },
  //           child: const Text('Create New Request'),
  //         ),
  //       ];
  //       break;
  //
  //     default:
  //       icon = Icons.error;
  //       iconColor = Colors.grey;
  //       title = 'Cannot Move Stage';
  //       actions = [
  //         FilledButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('OK'),
  //         ),
  //       ];
  //   }
  //
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Row(
  //         children: [
  //           Icon(icon, color: iconColor),
  //           const SizedBox(width: 12),
  //           Expanded( // ✅ ADD: Wrap title in Expanded
  //             child: Text(
  //               title,
  //               style: const TextStyle(fontSize: 18),
  //             ),
  //           ),
  //         ],
  //       ),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(reason),
  //           if (requestNumber != null) ...[
  //             const SizedBox(height: 12),
  //             Container(
  //               padding: const EdgeInsets.all(8),
  //               decoration: BoxDecoration(
  //                 color: Colors.blue[50],
  //                 borderRadius: BorderRadius.circular(6),
  //               ),
  //               child: Row(
  //                 children: [
  //                   Icon(Icons.info, size: 16, color: Colors.blue[700]), // ✅ FIXED: Use proper color reference
  //                   const SizedBox(width: 8),
  //                   Expanded( // ✅ ADD: Wrap in Expanded to prevent overflow
  //                     child: Text(
  //                       'Request: $requestNumber',
  //                       style: const TextStyle(
  //                         fontSize: 12,
  //                         fontWeight: FontWeight.w600,
  //                       ),
  //                       maxLines: 2, // ✅ ADD: Allow text wrapping
  //                       overflow: TextOverflow.ellipsis,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ],
  //       ),
  //       actions: actions,
  //     ),
  //   );
  // }
  //
  //
  // /// Show dialog when feasibility is approved with conditions
  // void _showMoveWithConditionsDialog(
  //     SpancoStage nextStage,
  //     Map<String, dynamic> checkResult,
  //     ) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Row(
  //         children: [
  //           Icon(Icons.verified, color: Colors.orange),
  //           const SizedBox(width: 12),
  //           const Text('Move with Conditions'),
  //         ],
  //       ),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             'Feasibility approved with conditions. You can move to ${nextStage.label}.',
  //           ),
  //           const SizedBox(height: 12),
  //           Container(
  //             padding: const EdgeInsets.all(8),
  //             decoration: BoxDecoration(
  //               color: Colors.orange[50],
  //               border: Border.all(color: Colors.orange[200]!),
  //               borderRadius: BorderRadius.circular(6),
  //             ),
  //             child: Row(
  //               children: [
  //                 Icon(Icons.warning, size: 16, color: Colors.orange[700]),
  //                 const SizedBox(width: 8),
  //                 const Expanded(
  //                   child: Text(
  //                     'Please review feasibility conditions before proceeding.',
  //                     style: TextStyle(fontSize: 12),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         OutlinedButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //             _navigateToFeasibilityDetail(checkResult['requestNumber']);
  //           },
  //           child: const Text('View Conditions'),
  //         ),
  //         FilledButton(
  //           onPressed: () {
  //             _leadProvider.moveToNextStage(_lead!.id!);
  //             Navigator.pop(context);
  //             _loadLead();
  //           },
  //           child: const Text('Proceed to Negotiation'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  /// Navigate to create feasibility request
  Future<void> _navigateToCreateFeasibility() async {
    if (_lead == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeasibilityFormPage(lead: _lead!),
      ),
    );

    // ✅ UPDATED: Reload without showing message (form already showed one)
    if (result == true && mounted) {
      await _loadFeasibilityStatus();
      // ✅ REMOVED: Don't show generic message
    }
  }



  // ✅ FIXED: Navigate to feasibility detail page
  void _navigateToFeasibilityDetail(String requestNumber) async {
    try {
      // ✅ FIXED: Use getRequestsByLead to get list of requests for this lead
      final provider = Provider.of<FeasibilityProvider>(context, listen: false);
      final requests = await provider.getRequestsByLead(_lead!.id!);

      // Find the request matching the number
      final request = requests.firstWhere(
            (r) => r.requestNumber == requestNumber,
        orElse: () => throw Exception('Request not found'),
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FeasibilityDetailPage(requestId: request.id!),
          ),
        ).then((_) => _loadLead()); // Refresh after returning
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Feasibility request not found: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  void _showMarkWonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Won'),
        content: const Text('Mark this lead as won?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async { // ✅ ADD: async
              Navigator.pop(context); // ✅ Close dialog first

              // ✅ ADD: await
              await _leadProvider.markAsWon(_lead!.id!);
              await _loadLead(); // ✅ ADD: await

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Lead marked as won!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Mark as Won'),
          ),
        ],
      ),
    );
  }


  // ✅ UPDATED: Mark as Lost dialog with await
  void _showMarkLostDialog() {
    final reasonController = TextEditingController();
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Lost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                hintText: 'e.g., Customer went with competitor',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              maxLength: 200,
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                labelText: 'Additional Remarks (Optional)',
                hintText: 'Any other details',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async { // ✅ ADD: async
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context); // ✅ Close dialog first

              // ✅ ADD: await
              await _leadProvider.markAsLost(
                _lead!.id!,
                reason: reasonController.text.trim(),
                remarks: remarksController.text.trim().isEmpty
                    ? null
                    : remarksController.text.trim(),
              );

              await _loadLead(); // ✅ ADD: await

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✗ Lead marked as lost'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Mark as Lost'),
          ),
        ],
      ),
    );
  }

  void _showRequalifyDialog() {
    SpancoStage? selectedStage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.refresh, color: Colors.orange[700], size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Re-qualify Lead'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are re-qualifying "${_lead!.customerName}".',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),

                // Previous lost details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history, size: 16, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Previous Lost Details:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reason: ${_lead!.lostReason ?? "N/A"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                      ),
                      if (_lead!.lostRemarks != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Remarks: ${_lead!.lostRemarks}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ✅ NEW: Stage selection
                const Text(
                  'Select Stage:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: SpancoStage.values
                        .where((stage) => stage != SpancoStage.order) // ✅ Exclude Order stage
                        .map((stage) {
                      final isSelected = selectedStage == stage;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedStage = stage;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? stage.color.withOpacity(0.1)
                                : null,
                            border: Border(
                              bottom: stage != SpancoStage.closure
                                  ? BorderSide(color: Colors.grey[200]!)
                                  : BorderSide.none,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? stage.color
                                      : stage.color.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: isSelected
                                      ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                      : Text(
                                    '${stage.stageOrder}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: stage.color,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  stage.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? stage.color
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.radio_button_checked,
                                  size: 20,
                                  color: stage.color,
                                )
                              else
                                Icon(
                                  Icons.radio_button_unchecked,
                                  size: 20,
                                  color: Colors.grey[400],
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // What happens info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'What happens:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedStage != null
                            ? '• Lead will be marked as ACTIVE\n'
                            '• Moved to ${selectedStage!.label} stage\n'
                            '• Re-qualification recorded in history'
                            : '• Select a stage to continue\n'
                            '• Lead will be marked as ACTIVE\n'
                            '• Re-qualification recorded in history',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[900],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: selectedStage != null
                    ? Colors.orange[700]
                    : Colors.grey[400],
              ),
              onPressed: selectedStage != null
                  ? () async {
                Navigator.pop(context);

                await _leadProvider.requalifyLostLead(
                  _lead!.id!,
                  toStage: selectedStage!, // ✅ Pass selected stage
                );
                await _loadLead();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '♻️ Lead re-qualified to ${selectedStage!.label}!',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange[700],
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
                  : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Re-qualify'),
            ),
          ],
        ),
      ),
    );
  }




// ✅ UPDATED: Mark as Lost from feasibility rejection
//   void _showMarkAsLostDialog(String reason) {
//     final remarksController = TextEditingController(text: reason);
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Mark as Lost'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text('Feasibility was rejected. Mark this lead as lost?'),
//             const SizedBox(height: 16),
//             TextField(
//               controller: remarksController,
//               decoration: const InputDecoration(
//                 labelText: 'Reason',
//                 border: OutlineInputBorder(),
//                 counterText: '',
//               ),
//               maxLength: 500, // ✅ ADD: Character limit
//               minLines: 2,
//               maxLines: 3,
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           FilledButton(
//             style: FilledButton.styleFrom(backgroundColor: Colors.red),
//             onPressed: () {
//               _leadProvider.markAsLost(
//                 _lead!.id!,
//                 reason: remarksController.text.trim(),
//               );
//               Navigator.pop(context);
//               _loadLead();
//             },
//             child: const Text('Mark as Lost'),
//           ),
//         ],
//       ),
//     );
//   }

  /// Navigate to edit lead form (with validation)
  Future<void> _navigateToEditLead() async {
    if (_lead == null) return;

    // ✅ CHECK: Stage validation - only allow editing for first 5 stages
    if (_lead!.currentStage.stageOrder > SpancoStage.closure.stageOrder) {
      _showCannotEditDialog(
        title: 'Cannot Edit Lead',
        message: 'Leads in ${_lead!.currentStage.label} stage and beyond cannot be edited.\n\n'
            'Only leads in Suspect, Prospect, Approach, Negotiation or Closure stages can be modified.',
        icon: Icons.lock,
        iconColor: Colors.orange,
      );
      return;
    }

    // ✅ REMOVED: Feasibility blocking - now handled in form
    // Just navigate and pass feasibility status for the form to handle

    // ✅ Navigate to edit form with feasibility status
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeadFormPage(
          leadToEdit: _lead,
          feasibilityStatus: _feasibilityStatus, // ✅ NEW: Pass status to form
        ),
      ),
    );

    // Reload lead data after editing
    if (result == true || result == null) {
      await _loadLead();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lead details refreshed'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }


  /// Show dialog when editing is not allowed
  void _showCannotEditDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(icon, size: 48, color: iconColor),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to cancel active feasibility before editing
  Future<void> _showCancelFeasibilityDialog(String? requestNumber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber, size: 48, color: Colors.orange),
        title: const Text('Active Feasibility Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This lead has an active feasibility request${requestNumber != null ? ' ($requestNumber)' : ''}.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'You must cancel the feasibility request before editing this lead.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.orange[900]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cancelling will notify the technical team and mark the request as cancelled.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go Back'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.cancel, size: 18),
            label: const Text('Cancel Feasibility & Edit'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelFeasibilityAndEdit();
    }
  }

  /// Cancel active feasibility request and proceed to edit
  Future<void> _cancelFeasibilityAndEdit() async {
    if (_lead == null) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cancelling feasibility request...'),
                ],
              ),
            ),
          ),
        ),
      );

      // ✅ UPDATED: Use FeasibilityProvider instead of LeadProvider
      await _feasibilityProvider.cancelFeasibilityRequest(_lead!.id!);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Reload feasibility status
      await _loadFeasibilityStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feasibility request cancelled'),
            backgroundColor: Colors.orange,
          ),
        );

        // Now navigate to edit form
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LeadFormPage(
              leadToEdit: _lead,
            ),
          ),
        );

        // Reload lead data after editing
        if (result == true || result == null) {
          await _loadLead();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lead details refreshed'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel feasibility: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }





  void _showAssignDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Lead'),
        content: const Text('Assign to current user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // You can implement user selection here
              Navigator.pop(context);
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lead'),
        content: const Text('This will mark the lead as cancelled. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _leadProvider.deleteLead(_lead!.id!);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Color _getStageColor(SpancoStage stage) {
  //   switch (stage) {
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  int _daysInStage(DateTime stageUpdatedAt) {
    return DateTime.now().difference(stageUpdatedAt).inDays;
  }
}
