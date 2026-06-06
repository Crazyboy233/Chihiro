class NumberUtils {
  static String formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }

  static String formatAmount(double amount, {bool showSign = false}) {
    if (showSign) {
      return amount >= 0 ? '+${formatCurrency(amount)}' : '-${formatCurrency(amount.abs())}';
    }
    return formatCurrency(amount);
  }
}
