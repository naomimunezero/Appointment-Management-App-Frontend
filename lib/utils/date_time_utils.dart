import 'package:intl/intl.dart';
/// Date and time formatting utilities for the appointment app.
class DateTimeUtils {

  static String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    
    try {
      // Try to parse as ISO 8601 (e.g., "2026-09-02T00:00:00.000000Z")
      final dateTime = DateTime.parse(dateStr);
      return formatDateFromDateTime(dateTime);
    } catch (_) {
      // If it fails, assume it's already in a readable format
      return dateStr;
    }
  }

  /// Formats a DateTime to a readable format like "Sep 2, 2026"
  static String formatDateFromDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[dateTime.month - 1];
    return '$month ${dateTime.day}, ${dateTime.year}';
  }

  /// Formats a time string to 12-hour format like "10:30 AM"
  /// If it's already in that format, returns as is.
  static String formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    
    var workingStr = timeStr;
    try {
      // If it contains "T", it's ISO format like "10:30:00"
      if (workingStr.contains('T')) {
        final parts = workingStr.split('T');
        workingStr = parts.length > 1 ? parts[1] : workingStr;
      }
      
      // Remove milliseconds if present
      if (workingStr.contains('.')) {
        workingStr = workingStr.split('.')[0];
      }
      
      // Parse time like "10:30:00"
      final timeParts = workingStr.split(':');
      if (timeParts.length >= 2) {
        int hour = int.parse(timeParts[0]);
        int minute = int.parse(timeParts[1]);
        
        final isPM = hour >= 12;
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        
        final period = isPM ? 'PM' : 'AM';
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (_) {}
    
    return workingStr;
  }

  /// Combines date and time into a readable format
  static String formatDateTime(String? dateStr, String? timeStr) {
    final date = formatDate(dateStr);
    final time = formatTime(timeStr);
    
    if (date.isEmpty) return time;
    if (time.isEmpty) return date;
    return '$date · $time';
  }

  /// Returns a live countdown like "In 30 mins" or "Overdue by 2 hrs"
  static String relativeCountdown(DateTime target) {
    final diff = target.difference(DateTime.now());
    final isPast = diff.isNegative;
    final abs = diff.abs();

    String unitText;
    if (abs.inDays >= 1) {
      unitText = '${abs.inDays} day${abs.inDays > 1 ? 's' : ''}';
    } else if (abs.inHours >= 1) {
      unitText = '${abs.inHours} hr${abs.inHours > 1 ? 's' : ''}';
    } else {
      unitText = '${abs.inMinutes} min${abs.inMinutes != 1 ? 's' : ''}';
    }

    return isPast ? 'Overdue by $unitText' : 'In $unitText';
  }

  static String friendlyMeetingDate(String? dateStr, String? timeStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final dayLabel = DateFormat('d MMM yyyy').format(date);
      if (timeStr == null || timeStr.isEmpty) return dayLabel;

      final parts = timeStr.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      final combined = DateTime(date.year, date.month, date.day, hour, minute);
      final timeLabel = DateFormat('h:mm a').format(combined);

      return '$dayLabel at $timeLabel';
    } catch (_) {
      return dateStr;
    }
  }
}
