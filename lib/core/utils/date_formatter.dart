import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _arabicDateFormat = DateFormat('yyyy/MM/dd', 'ar');
  static final DateFormat _arabicFullDateFormat = DateFormat('EEEE، d MMMM yyyy', 'ar');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'ar');
  static final DateFormat _timeFormat = DateFormat('hh:mm a', 'ar');

  static String formatDate(DateTime date) {
    try {
      return _arabicDateFormat.format(date);
    } catch (_) {
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    }
  }

  static String formatFullDate(DateTime date) {
    try {
      return _arabicFullDateFormat.format(date);
    } catch (_) {
      return formatDate(date);
    }
  }

  static String formatMonthYear(DateTime date) {
    try {
      return _monthYearFormat.format(date);
    } catch (_) {
      return '${date.month}/${date.year}';
    }
  }

  static String formatTime(DateTime date) {
    try {
      return _timeFormat.format(date);
    } catch (_) {
      return '${date.hour}:${date.minute}';
    }
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(itemDate).inDays;

    if (diff == 0) {
      return 'اليوم';
    } else if (diff == 1) {
      return 'الأمس';
    } else if (diff == -1) {
      return 'غداً';
    } else if (diff > 1 && diff < 7) {
      return 'منذ $diff أيام';
    } else {
      return formatDate(date);
    }
  }
}
