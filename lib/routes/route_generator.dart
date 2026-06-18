// lib/routes/route_generator.dart

import 'package:flutter/material.dart';
import '../pages/spanco/lead_list_page.dart';
import '../pages/spanco/lead_detail_page.dart';
import '../pages/spanco/lead_form_page.dart';
import '../pages/spanco/pipeline_page.dart';
import '../pages/spanco/activity_page.dart';
import '../pages/spanco/spanco_home_page.dart';
import '../pages/spanco/stage_history_page.dart';
import 'app_routes.dart';


class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final routeName = settings.name ?? '/';

    switch (routeName) {
      case AppRoutes.spanco:
      case AppRoutes.spancoLeads:
        return MaterialPageRoute(
          builder: (_) => const SpancoHomePage(),
        );

      case AppRoutes.spancoLeadDetail:
        final id = _extractId(routeName, ':id');
        return MaterialPageRoute(
          builder: (_) => LeadDetailPage(leadId: int.parse(id)),
        );

      case AppRoutes.spancoLeadForm:
        return MaterialPageRoute(
          builder: (_) => const LeadFormPage(),
        );

      case AppRoutes.spancoPipeline:
        return MaterialPageRoute(
          builder: (_) => const PipelinePage(),
        );

      case AppRoutes.spancoActivity:
        return MaterialPageRoute(
          builder: (_) => const ActivityPage(),
        );

      case AppRoutes.spancoStageHistory:
        final id = _extractId(routeName, ':id');
        return MaterialPageRoute(
          builder: (_) => StageHistoryPage(
            leadId: int.parse(id),
            customerName: args as String? ?? 'Lead History',
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Route not found')),
          ),
        );
    }
  }

  static String _extractId(String routeName, String paramName) {
    // Handle simple cases like '/spanco/leads/123'
    final parts = routeName.split('/');
    if (parts.length > 0) {
      return parts.last; // Get the last segment (ID)
    }
    return '';
  }
}

