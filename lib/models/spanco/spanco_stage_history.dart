import 'spanco_lead.dart';

/// SPANCO Stage History Model
/// Tracks lead progression through SPANCO stages
/// Matches spanco_stage_history table schema
class SpancoStageHistory {
  // Primary Key
  final int? id;

  // Link to Lead
  final int leadId;

  // Stage Transition
  final String? fromStage; // ✅ Nullable (null for first entry)
  final String toStage;
  final DateTime changedAt;

  // Who Changed It
  final String changedBy; // UUID of user who changed the stage
  final String? changeReason;
  final String? remarks;

  // Duration in Previous Stage (Auto-calculated by trigger)
  final int? daysInPreviousStage;

  SpancoStageHistory({
    this.id,
    required this.leadId,
    this.fromStage, // ✅ Nullable
    required this.toStage,
    required this.changedAt,
    required this.changedBy,
    this.changeReason,
    this.remarks,
    this.daysInPreviousStage,
  });

  /// Create from Supabase JSON
  factory SpancoStageHistory.fromJson(Map<String, dynamic> json) {
    return SpancoStageHistory(
      id: json['id'] as int?,
      leadId: json['lead_id'] as int,
      fromStage: json['from_stage'] as String?, // ✅ Safe cast
      toStage: json['to_stage'] as String,
      changedAt: DateTime.parse(json['changed_at'] as String),
      changedBy: json['changed_by'] as String,
      changeReason: json['change_reason'] as String?,
      remarks: json['remarks'] as String?,
      daysInPreviousStage: json['days_in_previous_stage'] as int?,
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'lead_id': leadId,
      'from_stage': fromStage,
      'to_stage': toStage,
      'changed_at': changedAt.toIso8601String(),
      'changed_by': changedBy,
      'change_reason': changeReason,
      'remarks': remarks,
      'days_in_previous_stage': daysInPreviousStage,
    };
  }

  /// Copy with updated fields
  SpancoStageHistory copyWith({
    int? id,
    int? leadId,
    String? fromStage,
    String? toStage,
    DateTime? changedAt,
    String? changedBy,
    String? changeReason,
    String? remarks,
    int? daysInPreviousStage,
  }) {
    return SpancoStageHistory(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      fromStage: fromStage ?? this.fromStage,
      toStage: toStage ?? this.toStage,
      changedAt: changedAt ?? this.changedAt,
      changedBy: changedBy ?? this.changedBy,
      changeReason: changeReason ?? this.changeReason,
      remarks: remarks ?? this.remarks,
      daysInPreviousStage: daysInPreviousStage ?? this.daysInPreviousStage,
    );
  }

  // ✅ Helper getters with safe defaults
  String get fromStageLabel {
    if (fromStage == null) return 'Initial';
    try {
      return SpancoStage.fromString(fromStage!).label;
    } catch (e) {
      return fromStage!;
    }
  }

  String get toStageLabel {
    try {
      return SpancoStage.fromString(toStage).label;
    } catch (e) {
      return toStage;
    }
  }

  String get daysInStageFormatted {
    if (daysInPreviousStage == null) return 'N/A';
    if (daysInPreviousStage == 0) return 'Same day';
    if (daysInPreviousStage == 1) return '1 day';
    return '$daysInPreviousStage days';
  }

  /// Helper: Format stage change description
  String get changeDescription {
    if (fromStage == null) {
      return 'Created as $toStageLabel';
    }
    return 'Moved from $fromStageLabel to $toStageLabel';
  }

  /// Check if this is the first stage entry
  bool get isFirstEntry => fromStage == null;

  /// Format changed date
  String get formattedDate {
    return '${changedAt.day}/${changedAt.month}/${changedAt.year}';
  }

  /// Format changed time
  String get formattedTime {
    final hour = changedAt.hour.toString().padLeft(2, '0');
    final minute = changedAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Format full date time
  String get formattedDateTime {
    return '$formattedDate at $formattedTime';
  }
}
