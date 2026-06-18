import 'package:intl/intl.dart';

/// Date and Time Formatting Utilities
class Formatters {
  // Private constructor to prevent instantiation
  Formatters._();

  /// Format DateTime with AM/PM
  /// Example: 16/11/2025 3:34 PM
  static String formatDateTimeWithPeriod(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final hour = localDate.hour;
    final isPM = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = isPM ? 'PM' : 'AM';

    return '${localDate.day}/${localDate.month}/${localDate.year} '
        '$displayHour:${localDate.minute.toString().padLeft(2, '0')} $period';
  }

  /// Format date in long format
  /// Example: 16 Nov 2025
  static String formatDateMid(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final formatter = DateFormat('dd MMM yyyy');
    return formatter.format(localDate);
  }

  static String formatDate(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(localDate);
  }

  /// Format DateTime to dd/MM/yyyy HH:mm format in local timezone
  /// Example: 16/11/2025 15:34
  // static String format24DateTime(DateTime date) {
  //   final localDate = date.isUtc ? date.toLocal() : date;
  //   return '${localDate.day}/${localDate.month}/${localDate.year} '
  //       '${localDate.hour.toString().padLeft(2, '0')}:'
  //       '${localDate.minute.toString().padLeft(2, '0')}';
  // }


  /// Format DateTime with timezone suffix
  /// Example: 16/11/2025 15:34 IST
  static String formatDateTimeWithTimezone(DateTime date, {String timezone = 'IST'}) {
    final localDate = date.isUtc ? date.toLocal() : date;
    return '${localDate.day}/${localDate.month}/${localDate.year} '
        '${localDate.hour.toString().padLeft(2, '0')}:'
        '${localDate.minute.toString().padLeft(2, '0')} $timezone';
  }


  /// Format time only (no date)
  /// Example: 15:34
  static String formatTime(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    return '${localDate.hour.toString().padLeft(2, '0')}:'
        '${localDate.minute.toString().padLeft(2, '0')}';
  }

  /// Format time with AM/PM
  /// Example: 3:34 PM
  static String formatTimeWithPeriod(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final hour = localDate.hour;
    final isPM = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = isPM ? 'PM' : 'AM';

    return '$displayHour:${localDate.minute.toString().padLeft(2, '0')} $period';
  }

  /// Format DateTime in detailed format
  /// Example: 16 Nov 2025, 3:34 PM
  static String formatDateTimeDetailed(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final formatter = DateFormat('dd MMM yyyy, h:mm a');
    return formatter.format(localDate);
  }

  /// Format relative time (e.g., "2 hours ago", "Just now")
  static String formatRelativeTime(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final now = DateTime.now();
    final difference = now.difference(localDate);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? "minute" : "minutes"} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? "day" : "days"} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? "week" : "weeks"} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? "month" : "months"} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? "year" : "years"} ago';
    }
  }

  /// Format currency (Indian Rupees)
  /// Example: ₹1,50,000
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  /// Format currency with decimals
  /// Example: ₹1,50,000.50
  static String formatCurrencyWithDecimals(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Format number with Indian numbering system
  /// Example: 1,50,000
  static String formatNumber(num number) {
    final formatter = NumberFormat('#,##,###', 'en_IN');
    return formatter.format(number);
  }

  /// Format percentage
  /// Example: 85.5%
  static String formatPercentage(double value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  /// Format file size
  /// Example: 1.5 MB
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format duration (e.g., "2h 30m", "45s")
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Capitalize first letter
  /// Example: "hello" → "Hello"
  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Format phone number (Indian format)
  /// Example: +91 98765 43210
  static String formatPhoneNumber(String phone) {
    // Remove all non-digits
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
    }
    return phone; // Return as-is if format doesn't match
  }
}
