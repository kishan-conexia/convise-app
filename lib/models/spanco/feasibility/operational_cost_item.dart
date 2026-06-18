// lib/models/spanco/feasibility/operational_cost_item.dart

class OperationalCostItem {
  final String category;
  final String description;
  final double monthlyCost;
  final String? vendor;
  final String? remarks;

  OperationalCostItem({
    required this.category,
    required this.description,
    required this.monthlyCost,
    this.vendor,
    this.remarks,
  });

  /// Annual cost calculation
  double get annualCost => monthlyCost * 12;

  /// From JSON
  factory OperationalCostItem.fromJson(Map<String, dynamic> json) {
    return OperationalCostItem(
      category: json['category'] as String,
      description: json['description'] as String,
      monthlyCost: (json['monthly_cost'] as num).toDouble(),
      vendor: json['vendor'] as String?,
      remarks: json['remarks'] as String?,
    );
  }

  /// To JSON
  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'description': description,
      'monthly_cost': monthlyCost,
      'annual_cost': annualCost,
      if (vendor != null) 'vendor': vendor,
      if (remarks != null) 'remarks': remarks,
    };
  }

  /// Copy with
  OperationalCostItem copyWith({
    String? category,
    String? description,
    double? monthlyCost,
    String? vendor,
    String? remarks,
  }) {
    return OperationalCostItem(
      category: category ?? this.category,
      description: description ?? this.description,
      monthlyCost: monthlyCost ?? this.monthlyCost,
      vendor: vendor ?? this.vendor,
      remarks: remarks ?? this.remarks,
    );
  }
}
