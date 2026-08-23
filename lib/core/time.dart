import 'package:intl/intl.dart';

/// Time helpers (P-09).
///
/// Rule: every timestamp is stored as UTC milliseconds since epoch and is
/// only converted to local time at the moment it is displayed.
class AppTime {
  AppTime._();

  static int nowMs() => DateTime.now().toUtc().millisecondsSinceEpoch;

  static DateTime fromMs(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  static DateTime? fromMsOrNull(int? ms) => ms == null ? null : fromMs(ms);

  static int toMs(DateTime time) => time.toUtc().millisecondsSinceEpoch;

  /// ISO-8601 in UTC, e.g. `2026-08-23T10:20:00Z`. Used in sync front matter.
  static String toIso(int ms) =>
      '${fromMs(ms).toIso8601String().split('.').first}Z';

  static int? parseIso(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value.trim());
    return parsed?.toUtc().millisecondsSinceEpoch;
  }

  /// Filename-safe UTC stamp, e.g. `2026-08-23T10-30-00Z` (B-08).
  static String fileStamp(int ms) =>
      toIso(ms).replaceAll(':', '-');

  /// Date only, e.g. `2026-08-23` (E-05, B-08).
  static String dateStamp(int ms) =>
      DateFormat('yyyy-MM-dd').format(fromMs(ms).toLocal());

  /// Month only, e.g. `2026-08` (B-08).
  static String monthStamp(int ms) =>
      DateFormat('yyyy-MM').format(fromMs(ms).toLocal());

  /// Human friendly relative label used on cards and the sync status line.
  static String relative(int ms) {
    final then = fromMs(ms).toLocal();
    final diff = DateTime.now().difference(then);

    if (diff.isNegative) return DateFormat.yMMMd().format(then);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (then.year == DateTime.now().year) {
      return DateFormat('d MMM').format(then);
    }
    return DateFormat('d MMM yyyy').format(then);
  }

  /// Full timestamp for detail screens and PDF headers.
  static String full(int ms) =>
      DateFormat('d MMM yyyy, HH:mm').format(fromMs(ms).toLocal());

  /// True when [lastMs] is at least [days] days old (B-05).
  static bool olderThanDays(int? lastMs, int days) {
    if (lastMs == null) return true;
    return nowMs() - lastMs >= days * 24 * 60 * 60 * 1000;
  }

  /// True when [lastMs] falls in an earlier calendar month than now (B-05).
  static bool inPreviousMonth(int? lastMs) {
    if (lastMs == null) return true;
    final last = fromMs(lastMs).toLocal();
    final now = DateTime.now();
    return last.year < now.year || (last.year == now.year && last.month < now.month);
  }
}
