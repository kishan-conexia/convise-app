// lib/models/spanco/feasibility/cost_item.dart

class CostItem {
  final String itemCode;
  final String itemDescription;
  final String category; // "Consumable Capex" or "Recoverable Capex"
  final String uom; // Mtr, Nos, Roll, Day, Hour, Lump Sum
  final double quantity;
  final double unitPrice;
  final double totalCost;

  CostItem({
    required this.itemCode,
    required this.itemDescription,
    required this.category,
    required this.uom,
    required this.quantity,
    required this.unitPrice,
    required this.totalCost,
  });

  factory CostItem.fromJson(Map<String, dynamic> json) {
    return CostItem(
      itemCode: json['item_code'] as String,
      itemDescription: json['item_description'] as String,
      category: json['category'] as String,
      uom: json['uom'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode,
      'item_description': itemDescription,
      'category': category,
      'uom': uom,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_cost': totalCost,
    };
  }

  // Helper: Calculate total cost
  static double calculateTotal(double quantity, double unitPrice) {
    return quantity * unitPrice;
  }

  CostItem copyWith({
    String? itemCode,
    String? itemDescription,
    String? category,
    String? uom,
    double? quantity,
    double? unitPrice,
    double? totalCost,
  }) {
    return CostItem(
      itemCode: itemCode ?? this.itemCode,
      itemDescription: itemDescription ?? this.itemDescription,
      category: category ?? this.category,
      uom: uom ?? this.uom,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalCost: totalCost ?? this.totalCost,
    );
  }
}
