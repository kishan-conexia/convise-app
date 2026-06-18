// lib/models/spanco/feasibility/site_survey.dart

class SiteSurvey {
  final bool required;
  final bool completed;
  final DateTime? surveyDate;
  final String? conductedBy;
  final String? surveyorName;
  final String? reportUrl;
  final List<String>? photos;
  final String? findings;
  final String? recommendations;

  SiteSurvey({
    this.required = false,
    this.completed = false,
    this.surveyDate,
    this.conductedBy,
    this.surveyorName,
    this.reportUrl,
    this.photos,
    this.findings,
    this.recommendations,
  });

  factory SiteSurvey.fromJson(Map<String, dynamic> json) {
    return SiteSurvey(
      required: json['required'] as bool? ?? false,
      completed: json['completed'] as bool? ?? false,
      surveyDate: json['survey_date'] != null
          ? DateTime.parse(json['survey_date'] as String)
          : null,
      conductedBy: json['conducted_by'] as String?,
      surveyorName: json['surveyor_name'] as String?,
      reportUrl: json['report_url'] as String?,
      photos: json['photos'] != null
          ? List<String>.from(json['photos'])
          : null,
      findings: json['findings'] as String?,
      recommendations: json['recommendations'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'required': required,
      'completed': completed,
      if (surveyDate != null) 'survey_date': surveyDate!.toIso8601String().split('T')[0],
      if (conductedBy != null) 'conducted_by': conductedBy,
      if (surveyorName != null) 'surveyor_name': surveyorName,
      if (reportUrl != null) 'report_url': reportUrl,
      if (photos != null) 'photos': photos,
      if (findings != null) 'findings': findings,
      if (recommendations != null) 'recommendations': recommendations,
    };
  }
}
