// lib/pages/feasibility/operational_costs_dialog.dart

import 'package:flutter/material.dart';
import '../../models/spanco/feasibility/operational_cost_item.dart';
import '../../utils/formatters.dart';

class OperationalCostsDialog extends StatefulWidget {
  final List<OperationalCostItem> operationalCosts;
  final Function(List<OperationalCostItem>) onSave;

  const OperationalCostsDialog({
    Key? key,
    required this.operationalCosts,
    required this.onSave,
  }) : super(key: key);

  @override
  State<OperationalCostsDialog> createState() => _OperationalCostsDialogState();
}

class _OperationalCostsDialogState extends State<OperationalCostsDialog> {
  late List<OperationalCostItem> _costs;

  @override
  void initState() {
    super.initState();
    _costs = List.from(widget.operationalCosts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operational Costs'),
        actions: [
          TextButton(
            onPressed: _saveCosts,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary header
          _buildSummaryHeader(),

          // Cost items list
          Expanded(
            child: _costs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _costs.length,
              itemBuilder: (context, index) => _buildCostItemCard(_costs[index], index),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCostItem,
        icon: const Icon(Icons.add),
        label: const Text('Add Cost'),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final totalMonthly = _costs.fold(0.0, (sum, item) => sum + item.monthlyCost);
    final totalAnnual = totalMonthly * 12;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[400]!, Colors.orange[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
                  const Text(
                    'Monthly OPEX',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(totalMonthly),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Annual OPEX',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(totalAnnual),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_costs.length} cost items',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No operational costs added',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first cost item',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostItemCard(OperationalCostItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(item.category).withOpacity(0.2),
          child: Icon(
            _getCategoryIcon(item.category),
            color: _getCategoryColor(item.category),
            size: 20,
          ),
        ),
        title: Text(
          item.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.category,
              style: TextStyle(
                fontSize: 12,
                color: _getCategoryColor(item.category),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (item.vendor != null) ...[
              const SizedBox(height: 2),
              Text(
                'Vendor: ${item.vendor}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.formatCurrency(item.monthlyCost),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '/month',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editCostItem(index);
                } else if (value == 'delete') {
                  _deleteCostItem(index);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addCostItem() {
    _showCostItemDialog(null, -1);
  }

  void _editCostItem(int index) {
    _showCostItemDialog(_costs[index], index);
  }

  void _deleteCostItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cost Item'),
        content: Text('Remove "${_costs[index].description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _costs.removeAt(index));
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCostItemDialog(OperationalCostItem? item, int index) {
    final descController = TextEditingController(text: item?.description);
    final monthlyCostController = TextEditingController(text: item?.monthlyCost.toString());
    final vendorController = TextEditingController(text: item?.vendor);
    final remarksController = TextEditingController(text: item?.remarks);

    String category = item?.category ?? 'Infrastructure';

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
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: [
                        'Infrastructure',
                        'Power',
                        'Maintenance',
                        'Bandwidth',
                        'Licensing',
                        'Labor',
                        'Other',
                      ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (value) {
                        setDialogState(() => category = value!);
                      },
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'e.g., Fiber lease from ISP',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      minLines: 2,
                      maxLines: 3,
                      maxLength: 200, // ✅ Limit: 200 chars
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: monthlyCostController,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Cost (₹)',
                        hintText: '2000',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                        counterText: '',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 15, // ✅ Limit: 15 chars
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: vendorController,
                      decoration: const InputDecoration(
                        labelText: 'Vendor (Optional)',
                        hintText: 'e.g., ABC Corp',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      maxLength: 100, // ✅ Limit: 100 chars
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: remarksController,
                      decoration: const InputDecoration(
                        labelText: 'Remarks (Optional)',
                        hintText: 'Additional notes',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      minLines: 2,
                      maxLines: 3,
                      maxLength: 300, // ✅ Limit: 300 chars
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
              final monthlyCost = double.tryParse(monthlyCostController.text) ?? 0;

              if (descController.text.trim().isEmpty || monthlyCost <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter description and valid monthly cost'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final newItem = OperationalCostItem(
                category: category,
                description: descController.text.trim(),
                monthlyCost: monthlyCost,
                vendor: vendorController.text.trim().isEmpty ? null : vendorController.text.trim(),
                remarks: remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
              );

              setState(() {
                if (index >= 0) {
                  _costs[index] = newItem;
                } else {
                  _costs.add(newItem);
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

  void _saveCosts() {
    widget.onSave(_costs);
    Navigator.pop(context);
  }

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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'infrastructure':
        return Icons.router;
      case 'power':
        return Icons.bolt;
      case 'maintenance':
        return Icons.build;
      case 'bandwidth':
        return Icons.cloud_upload;
      case 'licensing':
        return Icons.verified_user;
      case 'labor':
        return Icons.people;
      default:
        return Icons.receipt;
    }
  }
}
