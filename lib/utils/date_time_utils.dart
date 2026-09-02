/// Date and time formatting utilities for the appointment app.
class DateTimeUtils {
  /// Formats an ISO 8601 date string to a readable format like "Sep 2, 2026"
  /// If the input is already a simple date format, it returns it as is.
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
}
