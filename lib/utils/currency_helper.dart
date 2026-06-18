import 'package:intl/intl.dart';

/// Currency Helper for Indian Rupee (₹) formatting and calculations
class CurrencyHelper {
  // Private constructor to prevent instantiation
  CurrencyHelper._();

  /// Format amount in full Indian Rupee format
  /// Example: ₹1,50,000
  static String format(double amount, {bool showDecimals = false}) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: showDecimals ? 2 : 0,
    );
    return formatter.format(amount);
  }

  /// Format amount with forced decimals
  /// Example: ₹1,50,000.50
  static String formatWithDecimals(double amount) {
    return format(amount, showDecimals: true);
  }

  /// Format in compact form (K, L, Cr)
  /// Example: ₹1.5L, ₹25K, ₹2.3Cr
  static String formatCompact(double amount, {int decimals = 1}) {
    if (amount >= 10000000) {
      // Crores: 1,00,00,000+
      final crores = amount / 10000000;
      return '₹${crores.toStringAsFixed(crores >= 100 ? 0 : decimals)}Cr';
    } else if (amount >= 100000) {
      // Lakhs: 1,00,000+
      final lakhs = amount / 100000;
      return '₹${lakhs.toStringAsFixed(lakhs >= 100 ? 0 : decimals)}L';
    } else if (amount >= 1000) {
      // Thousands: 1,000+
      final thousands = amount / 1000;
      return '₹${thousands.toStringAsFixed(thousands >= 100 ? 0 : decimals)}K';
    } else {
      return '₹${amount.toStringAsFixed(0)}';
    }
  }

  /// Format without currency symbol
  /// Example: 1,50,000
  static String formatWithoutSymbol(double amount, {bool showDecimals = false}) {
    final formatter = NumberFormat('#,##,##0${showDecimals ? '.00' : ''}', 'en_IN');
    return formatter.format(amount);
  }

  /// Format for input fields (no grouping)
  /// Example: 150000
  static String formatForInput(double amount) {
    return amount.toStringAsFixed(0);
  }

  /// Parse formatted currency string to double
  /// Example: "₹1,50,000" → 150000.0
  static double? parse(String formatted) {
    try {
      // Remove currency symbol, spaces, and commas
      final cleaned = formatted
          .replaceAll('₹', '')
          .replaceAll(',', '')
          .replaceAll(' ', '')
          .trim();

      return double.tryParse(cleaned);
    } catch (e) {
      return null;
    }
  }

  /// Calculate percentage of total
  /// Example: 50000 of 200000 = 25.0%
  static double percentageOf(double amount, double total) {
    if (total == 0) return 0.0;
    return (amount / total) * 100;
  }

  /// Format percentage with amount
  /// Example: ₹50,000 (25%)
  static String formatWithPercentage(double amount, double total) {
    final percentage = percentageOf(amount, total);
    return '${format(amount)} (${percentage.toStringAsFixed(1)}%)';
  }

  /// Calculate growth percentage
  /// Example: 150000 → 180000 = +20%
  static double growthPercentage(double oldValue, double newValue) {
    if (oldValue == 0) return newValue > 0 ? 100.0 : 0.0;
    return ((newValue - oldValue) / oldValue) * 100;
  }

  /// Format growth with sign
  /// Example: +20.5%, -15.2%
  static String formatGrowth(double oldValue, double newValue) {
    final growth = growthPercentage(oldValue, newValue);
    final sign = growth >= 0 ? '+' : '';
    return '$sign${growth.toStringAsFixed(1)}%';
  }

  /// Calculate discount amount
  /// Example: 100000 with 10% discount = 10000
  static double discountAmount(double amount, double discountPercent) {
    return amount * (discountPercent / 100);
  }

  /// Apply discount and return final amount
  /// Example: 100000 with 10% discount = 90000
  static double applyDiscount(double amount, double discountPercent) {
    return amount - discountAmount(amount, discountPercent);
  }

  /// Format with discount info
  /// Example: ₹90,000 (10% off from ₹1,00,000)
  static String formatWithDiscount(double amount, double discountPercent) {
    final original = amount / (1 - discountPercent / 100);
    return '${format(amount)} (${discountPercent.toStringAsFixed(0)}% off from ${format(original)})';
  }

  /// Calculate tax amount (GST)
  /// Example: 100000 with 18% GST = 18000
  static double taxAmount(double amount, double taxPercent) {
    return amount * (taxPercent / 100);
  }

  /// Add tax to amount
  /// Example: 100000 + 18% GST = 118000
  static double withTax(double amount, double taxPercent) {
    return amount + taxAmount(amount, taxPercent);
  }

  /// Calculate base amount from total (reverse tax)
  /// Example: 118000 total with 18% GST = 100000 base
  static double withoutTax(double totalAmount, double taxPercent) {
    return totalAmount / (1 + taxPercent / 100);
  }

  /// Format with tax breakdown
  /// Example: ₹1,00,000 + ₹18,000 (18% GST) = ₹1,18,000
  static String formatWithTax(double amount, double taxPercent) {
    final tax = taxAmount(amount, taxPercent);
    final total = withTax(amount, taxPercent);
    return '${format(amount)} + ${format(tax)} (${taxPercent.toStringAsFixed(0)}% GST) = ${format(total)}';
  }

  /// Calculate monthly payment (simple division)
  /// Example: 120000 over 12 months = 10000/month
  static double monthlyPayment(double totalAmount, int months) {
    if (months <= 0) return 0.0;
    return totalAmount / months;
  }

  /// Format monthly payment
  /// Example: ₹10,000/month for 12 months
  static String formatMonthly(double totalAmount, int months) {
    final monthly = monthlyPayment(totalAmount, months);
    return '${format(monthly)}/month for $months months';
  }

  /// Calculate commission
  /// Example: 100000 with 5% commission = 5000
  static double commission(double amount, double commissionPercent) {
    return amount * (commissionPercent / 100);
  }

  /// Format with commission info
  /// Example: ₹1,00,000 (Commission: ₹5,000 @ 5%)
  static String formatWithCommission(double amount, double commissionPercent) {
    final comm = commission(amount, commissionPercent);
    return '${format(amount)} (Commission: ${format(comm)} @ ${commissionPercent.toStringAsFixed(1)}%)';
  }

  /// Sum list of amounts
  static double sum(List<double> amounts) {
    return amounts.fold(0.0, (sum, amount) => sum + amount);
  }

  /// Average of amounts
  static double average(List<double> amounts) {
    if (amounts.isEmpty) return 0.0;
    return sum(amounts) / amounts.length;
  }

  /// Format range
  /// Example: ₹50,000 - ₹1,00,000
  static String formatRange(double min, double max) {
    return '${format(min)} - ${format(max)}';
  }

  /// Format deal size category
  /// Example: "Small Deal" (<1L), "Medium Deal" (1-10L), "Large Deal" (>10L)
  static String dealSizeCategory(double amount) {
    if (amount < 100000) return 'Small Deal';
    if (amount < 1000000) return 'Medium Deal';
    if (amount < 10000000) return 'Large Deal';
    return 'Enterprise Deal';
  }

  /// Get deal size emoji
  static String dealSizeEmoji(double amount) {
    if (amount < 100000) return '💰';      // Small: < 1L
    if (amount < 1000000) return '💰💰';   // Medium: 1-10L
    if (amount < 10000000) return '💰💰💰'; // Large: 10L-1Cr
    return '💎';                            // Enterprise: > 1Cr
  }

  /// Format with deal size indicator
  /// Example: "₹5.5L 💰💰 Medium Deal"
  static String formatWithDealSize(double amount) {
    return '${formatCompact(amount)} ${dealSizeEmoji(amount)} ${dealSizeCategory(amount)}';
  }

  /// Compare two amounts and return difference
  /// Example: 150000 vs 120000 = +₹30,000 (+25%)
  static String compareTo(double current, double previous) {
    final diff = current - previous;
    final growth = growthPercentage(previous, current);
    final sign = diff >= 0 ? '+' : '';
    return '$sign${format(diff.abs())} ($sign${growth.toStringAsFixed(1)}%)';
  }

  /// Check if amount is within budget
  static bool isWithinBudget(double amount, double budget) {
    return amount <= budget;
  }

  /// Calculate budget utilization percentage
  static double budgetUtilization(double spent, double budget) {
    if (budget == 0) return 0.0;
    return (spent / budget) * 100;
  }

  /// Format budget status
  /// Example: "₹75,000 / ₹1,00,000 (75% utilized)"
  static String formatBudgetStatus(double spent, double budget) {
    final utilization = budgetUtilization(spent, budget);
    return '${format(spent)} / ${format(budget)} (${utilization.toStringAsFixed(1)}% utilized)';
  }
}
