/// Jordanian Dinar formatting — JOD uses 3 decimal places (1 JOD = 1000
/// fils), unlike most currencies' 2, so a generic `NumberFormat.currency`
/// default would round money wrong. Keep this the single place that knows
/// that rule.
class CurrencyFormatter {
  const CurrencyFormatter._();

  static String jod(num amount) => '${amount.toStringAsFixed(3)} د.أ';

  /// Compact form for tight spaces (badges, chips) — still 3 decimals since
  /// JOD amounts are commonly non-round (e.g. 1.250).
  static String jodCompact(num amount) => amount.toStringAsFixed(3);
}
