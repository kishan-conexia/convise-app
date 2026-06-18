// lib/models/spanco/feasibility/connectivity_route.dart

import 'cost_item.dart';

enum RouteStatus {
  notEvaluated,
  notFeasible,
  feasible,
}

class ConnectivityRoute {
  final bool isFeasible;

  // For feasible routes
  final String? routeName;
  final String? sourceNodeName;
  final double? distanceKm;
  final String? technology; // Fiber, Wireless, Hybrid
  final double? totalFiberLengthMtr;
  final bool? infrastructureAvailable;
  final bool? requiresRow;
  final String? rowDetails;
  final int? installationDays;
  final String? remarks;
  final List<CostItem>? costItems;
  final double? consumableCapex;
  final double? recoverableCapex;
  final double? totalCapex;

  // For not feasible routes
  final String? evaluatedBy;
  final DateTime? evaluatedAt;
  final String? reason;
  final List<String>? technicalConstraints;

  ConnectivityRoute({
    required this.isFeasible,
    // Feasible route fields
    this.routeName,
    this.sourceNodeName,
    this.distanceKm,
    this.technology,
    this.totalFiberLengthMtr,
    this.infrastructureAvailable,
    this.requiresRow,
    this.rowDetails,
    this.installationDays,
    this.remarks,
    this.costItems,
    this.consumableCapex,
    this.recoverableCapex,
    this.totalCapex,
    // Not feasible route fields
    this.evaluatedBy,
    this.evaluatedAt,
    this.reason,
    this.technicalConstraints,
  });

  // Factory: Not evaluated (returns null in practice, but useful for checks)
  factory ConnectivityRoute.notEvaluated() {
    return ConnectivityRoute(isFeasible: false);
  }

  // Factory: Not feasible
  factory ConnectivityRoute.notFeasible({
    required String reason,
    String? evaluatedBy,
    DateTime? evaluatedAt,
    List<String>? technicalConstraints,
    String? remarks,
  }) {
    return ConnectivityRoute(
      isFeasible: false,
      reason: reason,
      evaluatedBy: evaluatedBy,
      evaluatedAt: evaluatedAt,
      technicalConstraints: technicalConstraints,
      remarks: remarks,
    );
  }

  // Factory: Feasible
  factory ConnectivityRoute.feasible({
    required String routeName,
    required String sourceNodeName,
    required double distanceKm,
    required String technology,
    required double totalFiberLengthMtr,
    required List<CostItem> costItems,
    bool infrastructureAvailable = false,
    bool requiresRow = false,
    String? rowDetails,
    int? installationDays,
    String? remarks,
  }) {
    // Auto-calculate consumable and recoverable capex
    double consumable = 0;
    double recoverable = 0;

    for (var item in costItems) {
      if (item.category == 'Consumable Capex') {
        consumable += item.totalCost;
      } else if (item.category == 'Recoverable Capex') {
        recoverable += item.totalCost;
      }
    }

    return ConnectivityRoute(
      isFeasible: true,
      routeName: routeName,
      sourceNodeName: sourceNodeName,
      distanceKm: distanceKm,
      technology: technology,
      totalFiberLengthMtr: totalFiberLengthMtr,
      infrastructureAvailable: infrastructureAvailable,
      requiresRow: requiresRow,
      rowDetails: rowDetails,
      installationDays: installationDays,
      remarks: remarks,
      costItems: costItems,
      consumableCapex: consumable,
      recoverableCapex: recoverable,
      totalCapex: consumable + recoverable,
    );
  }

  factory ConnectivityRoute.fromJson(Map<String, dynamic> json) {
    final isFeasible = json['is_feasible'] as bool;

    if (!isFeasible) {
      // Not feasible route
      return ConnectivityRoute(
        isFeasible: false,
        evaluatedBy: json['evaluated_by'] as String?,
        evaluatedAt: json['evaluated_at'] != null
            ? DateTime.parse(json['evaluated_at'] as String)
            : null,
        reason: json['reason'] as String?,
        technicalConstraints: json['technical_constraints'] != null
            ? List<String>.from(json['technical_constraints'])
            : null,
        remarks: json['remarks'] as String?,
      );
    }

    // Feasible route
    return ConnectivityRoute(
      isFeasible: true,
      routeName: json['route_name'] as String?,
      sourceNodeName: json['source_node_name'] as String?,
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
      technology: json['technology'] as String?,
      totalFiberLengthMtr: json['total_fiber_length_mtr'] != null
          ? (json['total_fiber_length_mtr'] as num).toDouble()
          : null,
      infrastructureAvailable: json['infrastructure_available'] as bool?,
      requiresRow: json['requires_row'] as bool?,
      rowDetails: json['row_details'] as String?,
      installationDays: json['installation_days'] as int?,
      remarks: json['remarks'] as String?,
      costItems: json['cost_items'] != null
          ? (json['cost_items'] as List)
          .map((item) => CostItem.fromJson(item as Map<String, dynamic>))
          .toList()
          : null,
      consumableCapex: json['consumable_capex'] != null
          ? (json['consumable_capex'] as num).toDouble()
          : null,
      recoverableCapex: json['recoverable_capex'] != null
          ? (json['recoverable_capex'] as num).toDouble()
          : null,
      totalCapex: json['total_capex'] != null
          ? (json['total_capex'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    if (!isFeasible) {
      // Not feasible route
      return {
        'is_feasible': false,
        if (evaluatedBy != null) 'evaluated_by': evaluatedBy,
        if (evaluatedAt != null) 'evaluated_at': evaluatedAt!.toIso8601String(),
        if (reason != null) 'reason': reason,
        if (technicalConstraints != null) 'technical_constraints': technicalConstraints,
        if (remarks != null) 'remarks': remarks,
      };
    }

    // Feasible route
    return {
      'is_feasible': true,
      if (routeName != null) 'route_name': routeName,
      if (sourceNodeName != null) 'source_node_name': sourceNodeName,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (technology != null) 'technology': technology,
      if (totalFiberLengthMtr != null) 'total_fiber_length_mtr': totalFiberLengthMtr,
      if (infrastructureAvailable != null) 'infrastructure_available': infrastructureAvailable,
      if (requiresRow != null) 'requires_row': requiresRow,
      if (rowDetails != null) 'row_details': rowDetails,
      if (installationDays != null) 'installation_days': installationDays,
      if (remarks != null) 'remarks': remarks,
      if (costItems != null) 'cost_items': costItems!.map((item) => item.toJson()).toList(),
      if (consumableCapex != null) 'consumable_capex': consumableCapex,
      if (recoverableCapex != null) 'recoverable_capex': recoverableCapex,
      if (totalCapex != null) 'total_capex': totalCapex,
    };
  }

  RouteStatus get status {
    if (!isFeasible && reason != null) {
      return RouteStatus.notFeasible;
    } else if (isFeasible) {
      return RouteStatus.feasible;
    }
    return RouteStatus.notEvaluated;
  }
}
