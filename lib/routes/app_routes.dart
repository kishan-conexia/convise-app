// lib/routes/app_routes.dart

class AppRoutes {
  // ========== SPANCO Routes ==========
  static const String spanco = '/spanco';
  static const String spancoLeads = '/spanco/leads';
  static const String spancoLeadDetail = '/spanco/leads/:id';
  static const String spancoLeadForm = '/spanco/leads/form';
  static const String spancoLeadEdit = '/spanco/leads/:id/edit';
  static const String spancoPipeline = '/spanco/pipeline';
  static const String spancoActivity = '/spanco/activity';
  static const String spancoStageHistory = '/spanco/leads/:id/history';

  // ========== Feasibility Routes (for later) ==========
  static const String feasibility = '/feasibility';
  static const String feasibilityList = '/feasibility/list';
// ... more later
}
