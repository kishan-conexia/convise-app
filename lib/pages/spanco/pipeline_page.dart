import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../models/spanco/spanco_lead.dart';
import '../../providers/lead_provider.dart';
import '../../utils/currency_helper.dart';
import 'lead_detail_page.dart';
import 'lead_form_page.dart';

class PipelinePage extends StatefulWidget {
  const PipelinePage({Key? key}) : super(key: key);

  @override
  State<PipelinePage> createState() => _PipelinePageState();
}

class _PipelinePageState extends State<PipelinePage> {
  late LeadProvider _leadProvider;

  @override
  void initState() {
    super.initState();
    _leadProvider = Provider.of<LeadProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _leadProvider.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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

              // ✅ NEW: Filter out won/lost leads from pipeline
              final activeLLeadsByStage = <SpancoStage, List<SpancoLead>>{};
              provider.leadsByStage.forEach((stage, leads) {
                activeLLeadsByStage[stage] = leads
                    .where((lead) => lead.status != LeadStatus.won && lead.status != LeadStatus.lost)
                    .toList();
              });

              final totalActiveLeads = activeLLeadsByStage.values
                  .fold(0, (sum, leads) => sum + leads.length);

              // ✅ UPDATED: Empty state - check active leads only
              if (totalActiveLeads == 0) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade100.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.dashboard_outlined,
                          size: 64,
                          color: Colors.blue.shade300,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'No Active Leads',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Create your first lead to see it in the pipeline',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _goToCreateLead,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Create First Lead',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // ✅ Pipeline summary header
                  // _buildPipelineSummary(activeLLeadsByStage),

                  // Pipeline columns
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _leadProvider.refreshLeads(),
                      color: Colors.blue.shade700,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const AlwaysScrollableScrollPhysics(),
                        // ✅ Show only active stages in pipeline
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: SpancoStage.activeStages.map((stage) { // ✅ Use activeStages
                            final leadsInStage = activeLLeadsByStage[stage] ?? [];
                            return _PipelineColumn(
                              stage: stage,
                              leads: leadsInStage,
                              onLeadTap: (lead) => _goToDetail(lead),
                              onAddLead: _goToCreateLead,
                            );
                          }).toList(),
                        ),

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



  // ✅ ADD: Pipeline summary header
  Widget _buildPipelineSummary(Map<SpancoStage, List<SpancoLead>> leadsByStage) {
    final totalLeads = leadsByStage.values.fold(0, (sum, leads) => sum + leads.length);
    final totalValue = leadsByStage.values
        .expand((leads) => leads)
        .fold(0.0, (sum, lead) => sum + (lead.estimatedValue ?? 0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.blue[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            icon: Icons.list_alt,
            label: 'Total Leads',
            value: totalLeads.toString(),
            color: Colors.blue,
          ),
          _buildSummaryItem(
            icon: Icons.attach_money,
            label: 'Pipeline Value',
            value: CurrencyHelper.formatCompact(totalValue), // ✅ NEW
            color: Colors.green,
          ),
          _buildSummaryItem(
            icon: Icons.trending_up,
            label: 'Avg Deal Size',
            value: totalLeads > 0
                ? CurrencyHelper.formatCompact(totalValue / totalLeads) // ✅ NEW
                : '₹0',
            color: Colors.orange,
          ),

        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _goToDetail(SpancoLead lead) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeadDetailPage(leadId: lead.id!),
      ),
    );
    // ✅ Refresh after returning
    _leadProvider.refreshLeads();
  }

  void _goToCreateLead() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LeadFormPage(),
      ),
    );
    // ✅ Refresh after returning
    _leadProvider.refreshLeads();
  }
}

// =====================================================
// PIPELINE COLUMN WIDGET
// =====================================================

class _PipelineColumn extends StatelessWidget {
  final SpancoStage stage;
  final List<SpancoLead> leads;
  final Function(SpancoLead) onLeadTap;
  final VoidCallback onAddLead;

  const _PipelineColumn({
    required this.stage,
    required this.leads,
    required this.onLeadTap,
    required this.onAddLead,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Calculate stage value
    final stageValue = leads.fold(0.0, (sum, lead) => sum + (lead.estimatedValue ?? 0));

    return Container(
      width: 350,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: stage.color.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(
                  color: stage.color,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stage.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: stage.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${leads.length} lead${leads.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stage.color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${leads.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                // ✅ UPDATED: Stage value with CurrencyHelper
                if (stageValue > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.currency_rupee,
                          size: 12,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          CurrencyHelper.formatCompact(stageValue).substring(1), // ✅ NEW: Remove ₹ symbol
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

              ],
            ),
          ),

          // Leads List
          Expanded(
            child: leads.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No leads in ${stage.label}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: leads.length,
              itemBuilder: (context, index) {
                final lead = leads[index];
                return _PipelineCard(
                  lead: lead,
                  onTap: () => onLeadTap(lead),
                );
              },
            ),
          ),

          // Add Lead Button (only show in Suspect stage)
          if (stage == SpancoStage.suspect)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddLead,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Lead'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Color _getStageColor() {
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
}

// =====================================================
// PIPELINE CARD WIDGET (unchanged)
// =====================================================

class _PipelineCard extends StatelessWidget {
  final SpancoLead lead;
  final VoidCallback onTap;

  const _PipelineCard({
    required this.lead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Name
            Text(
              lead.customerName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),

            // Phone
            Row(
              children: [
                const Icon(Icons.phone, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    lead.contactPhone,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Location
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    lead.serviceCity,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Value & Priority
            // Value & Priority
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (lead.estimatedValue != null)
                  Expanded(
                    child: Text(
                      CurrencyHelper.formatCompact(lead.estimatedValue!), // ✅ NEW
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getPriorityColor().withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lead.priority.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getPriorityColor(),
                    ),
                  ),
                ),
              ],
            ),

            // Days in Stage
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 10, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${DateTime.now().difference(lead.stageUpdatedAt).inDays}d in stage',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor() {
    switch (lead.priority) {
      case Priority.low:
        return Colors.grey;
      case Priority.medium:
        return Colors.blue;
      case Priority.high:
        return Colors.orange;
      case Priority.urgent:
        return Colors.red;
      case Priority.critical:
        return Colors.red.shade900;
    }
  }
}
