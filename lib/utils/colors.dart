import 'package:flutter/material.dart';

/// App-wide color constants and theme colors
class AppColors {
  AppColors._(); // Private constructor

  // =====================================================
  // SPANCO STAGE COLORS
  // =====================================================
  static const Color suspect = Colors.grey;
  static const Color prospect = Colors.blue;
  static const Color approach = Colors.orange;
  static const Color negotiation = Colors.purple;
  static const Color closure = Colors.red;
  static const Color order = Colors.green;
  static final Color won = Colors.green.shade700;
  static final Color lost = Colors.red.shade700;

  // =====================================================
  // PRIORITY COLORS
  // =====================================================
  static const Color priorityLow = Colors.grey;
  static const Color priorityMedium = Colors.blue;
  static const Color priorityHigh = Colors.orange;
  static const Color priorityUrgent = Colors.red;
  static final Color priorityCritical = Colors.red.shade900;

  // =====================================================
  // STATUS COLORS
  // =====================================================
  static const Color statusActive = Colors.blue;
  static const Color statusOnHold = Colors.orange;
  static const Color statusWon = Colors.green;
  static const Color statusLost = Colors.red;
  static const Color statusCancelled = Colors.grey;

  // =====================================================
  // CONNECTION TYPE COLORS
  // =====================================================
  static const Color fiber = Colors.blue;
  static const Color wireless = Colors.purple;
  static const Color leasedLine = Colors.green;
  static const Color partnerNetwork = Colors.indigo;
}
