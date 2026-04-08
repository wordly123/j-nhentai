import 'package:intl/intl.dart';

class DateUtil {
  static String transformUtc2LocalTimeString(String utcTimeString) {
    final String normalized = utcTimeString.trim();
    if (normalized.isEmpty) {
      return '';
    }

    try {
      final DateTime utcTime = DateFormat('yyyy-MM-dd HH:mm', 'en_US')
          .parseUtc(normalized)
          .toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(utcTime);
    } catch (_) {
      final DateTime? parsed =
          DateTime.tryParse(normalized.replaceFirst(' ', 'T'));
      if (parsed != null) {
        return DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
      }

      // Keep raw value instead of throwing parsing exceptions in UI layer.
      return normalized;
    }
  }
}
