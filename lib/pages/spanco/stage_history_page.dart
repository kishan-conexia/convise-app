import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/spanco/spanco_stage_history.dart';
import '../../providers/lead_provider.dart';
import '../../utils/formatters.dart'; // ✅ ADD: For consistent date formatting

class StageHistoryPage extends StatefulWidget {
  final int leadId;
  final String customerName;

  const StageHistoryPage({
    Key? key,
    required this.leadId,
    required this.customerName,
  }) : super(key: key);

  @override
  State<StageHistoryPage> createState() => _StageHistoryPageState();
}

class _StageHistoryPageState extends State<StageHistoryPage> {
  late LeadProvider _leadProvider;

  @override
  void initState() {
    super.initState();
    _leadProvider = Provider.of<LeadProvider>(context, listen: false);
    _loadHistory();
  }

  // ✅ ADD: Separate load method for refresh
  Future<void> _loadHistory() async {
    await _leadProvider.loadStageHistory(widget.leadId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stage History',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              widget.customerName,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        // ✅ ADD: Refresh button
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<LeadProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final history = provider.stageHistory;

          if (history.isEmpty) {
            return _buildEmptyState();
          }

          // ✅ ADD: Pull-to-refresh
          return RefreshIndicator(
            onRefresh: _loadHistory,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Summary Card
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildSummaryCard(history),
                  ),

                  // Timeline
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildTimeline(history),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ IMPROVED: Better empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'No Stage History Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stage changes will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(List<SpancoStageHistory> history) {
    // ✅ FIXED: Correct order (history[0] is newest, history.last is oldest)
    final firstEntry = history.last; // Oldest (creation)
    final lastEntry = history.first; // Newest (current)

    final totalDays = DateTime.now().difference(firstEntry.changedAt).inDays;
    final stagesCount = history.length;

    // ✅ ADD: Calculate average days per stage
    final totalDaysInStages = history
        .where((h) => h.daysInPreviousStage != null)
        .fold(0, (sum, h) => sum + h.daysInPreviousStage!);
    final avgDaysPerStage = stagesCount > 1
        ? (totalDaysInStages / (stagesCount - 1)).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.blue[300]!),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Total Days',
                '$totalDays',
                Icons.calendar_today,
                Colors.blue,
              ),
              _buildSummaryItem(
                'Stage Changes',
                '$stagesCount',
                Icons.swap_horiz,
                Colors.orange,
              ),
              _buildSummaryItem(
                'Avg Days/Stage',
                '$avgDaysPerStage',
                Icons.trending_up,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Journey timeline card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.route, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Journey Timeline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        // ✅ FIXED: Show correct first stage
                        firstEntry.toStageLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    const Text('...', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 16, color: Colors.grey[600]),
                    Expanded(
                      child: Text(
                        lastEntry.toStageLabel,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Started: ${Formatters.formatDate(firstEntry.changedAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ IMPROVED: Add color parameter
  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTimeline(List<SpancoStageHistory> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Detailed Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            // ✅ ADD: Entry count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${history.length} entries',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            final isFirst = index == 0; // Newest
            final isLast = index == history.length - 1; // Oldest

            return _buildTimelineItem(item, isFirst, isLast);
          },
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
      SpancoStageHistory item,
      bool isFirst,
      bool isLast,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot and line
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isFirst ? Colors.green : Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isFirst ? Colors.green : Colors.blue).withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: isFirst
                  ? const Icon(
                Icons.place,
                size: 12,
                color: Colors.white,
              )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 3,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blue[300]!,
                      Colors.blue[100]!,
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),

        // Content
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: isFirst ? Colors.green[200]! : Colors.grey[300]!,
                width: isFirst ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
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
                // ✅ IMPROVED: Stage transition with better styling
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      // ✅ Handle creation case
                      if (item.fromStage == null) ...[
                        const Icon(Icons.flag, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lead Created',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: Text(
                            item.fromStageLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.toStageLabel,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isFirst ? Colors.green[700] : Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Date and time
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(item.changedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // Days in stage
                if (item.daysInPreviousStage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getDurationColor(item.daysInPreviousStage!).withOpacity(0.1),
                      border: Border.all(
                        color: _getDurationColor(item.daysInPreviousStage!).withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: _getDurationColor(item.daysInPreviousStage!),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Duration: ${item.daysInStageFormatted}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getDurationColor(item.daysInPreviousStage!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Reason
                if (item.changeReason != null && item.changeReason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 12, color: Colors.blue[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Reason',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.changeReason!,
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Remarks
                if (item.remarks != null && item.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note_outlined, size: 12, color: Colors.purple[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Remarks',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.remarks!,
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ✅ ADD: Color based on duration (green = fast, orange = normal, red = slow)
  Color _getDurationColor(int days) {
    if (days <= 3) return Colors.green;
    if (days <= 7) return Colors.orange;
    return Colors.red;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (date == today) {
      dateStr = 'Today';
    } else if (date == yesterday) {
      dateStr = 'Yesterday';
    } else {
      // ✅ IMPROVED: Better date format
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      dateStr = '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    }

    final time =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    return '$dateStr at $time';
  }
}
