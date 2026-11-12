import 'package:intl/intl.dart';

/// Formatting helpers. All money in the app is integer rupees.
class Fmt {
  const Fmt._();

  static final _inr = NumberFormat.decimalPattern('en_IN');

  /// `₹1,320`, `₹1,25,000` (Indian grouping). Negative values get a leading minus.
  static String rupees(num amount) {
    final whole = amount.round();
    final s = _inr.format(whole.abs());
    return whole < 0 ? '-₹$s' : '₹$s';
  }

  /// `1,25,000` without the symbol.
  static String number(num n) => _inr.format(n);

  /// Percentage saved vs retail, e.g. `32% off`. Returns null when no saving.
  static int? savePercent({required num price, required num retail}) {
    if (retail <= 0 || price >= retail) return null;
    return (((retail - price) / retail) * 100).round();
  }

  /// `8:30 am`
  static String time(DateTime t) => DateFormat('h:mm a').format(t.toLocal()).toLowerCase();

  /// `Sun 16 Nov`
  static String day(DateTime t) => DateFormat('EEE d MMM').format(t.toLocal());

  /// `Sun 16 Nov, 6:00 am`
  static String dayTime(DateTime t) => '${day(t)}, ${time(t)}';

  /// Countdown to a cutoff: `2h 15m left`, `12m left`, `Closed`.
  static String timeLeft(DateTime cutoff, {DateTime? now}) {
    final d = cutoff.difference(now ?? DateTime.now());
    if (d.isNegative || d.inSeconds == 0) return 'Closed';
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h left';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m left';
    if (d.inMinutes >= 1) return '${d.inMinutes}m left';
    return '<1m left';
  }

  /// Relative time for feeds: `just now`, `5m ago`, `3h ago`, else the day.
  static String ago(DateTime t, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return day(t);
  }

  /// Parses an ISO string; null-safe.
  static DateTime? parseTime(Object? v) => v is String ? DateTime.tryParse(v) : null;
}
