import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';


class WarningPage extends StatefulWidget {
  const WarningPage({super.key});

  @override
  _WarningPageState createState() => _WarningPageState();
}

class _WarningPageState extends State<WarningPage> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warnings & Notifications'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade200, Colors.deepPurpleAccent.shade200],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Center()
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _severityIcon(String severity) {
    final icon = switch (severity.toLowerCase()) {
      'critical' => Icons.error,
      'warning' => Icons.warning,
      'info' => Icons.info,
      _ => Icons.notification_important,
    };

    return Icon(icon, color: _severityColor(severity));
  }
}