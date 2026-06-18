// lib/models/spanco/feasibility/service_requirements.dart

class ServiceRequirements {
  final String feasibilityType; // technical, commercial, combined
  final String connectionType; // fiber, wireless, hybrid, leased_line
  final String bandwidth;
  final bool staticIpRequired;
  final int staticIpCount;
  final bool ipv6Required;
  final String urgency; // low, normal, high, urgent
  final String priority; // low, normal, high, urgent
  final String? specialConditions;

  ServiceRequirements({
    required this.feasibilityType,
    required this.connectionType,
    required this.bandwidth,
    this.staticIpRequired = false,
    this.staticIpCount = 0,
    this.ipv6Required = false,
    this.urgency = 'normal',
    this.priority = 'normal',
    this.specialConditions,
  });

  factory ServiceRequirements.fromJson(Map<String, dynamic> json) {
    return ServiceRequirements(
      feasibilityType: json['feasibility_type'] as String,
      connectionType: json['connection_type'] as String,
      bandwidth: json['bandwidth'] as String,
      staticIpRequired: json['static_ip_required'] as bool? ?? false,
      staticIpCount: json['static_ip_count'] as int? ?? 0,
      ipv6Required: json['ipv6_required'] as bool? ?? false,
      urgency: json['urgency'] as String? ?? 'normal',
      priority: json['priority'] as String? ?? 'normal',
      specialConditions: json['special_conditions'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feasibility_type': feasibilityType,
      'connection_type': connectionType,
      'bandwidth': bandwidth,
      'static_ip_required': staticIpRequired,
      'static_ip_count': staticIpCount,
      'ipv6_required': ipv6Required,
      'urgency': urgency,
      'priority': priority,
      if (specialConditions != null) 'special_conditions': specialConditions,
    };
  }
}
