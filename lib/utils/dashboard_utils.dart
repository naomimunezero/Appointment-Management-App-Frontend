/// Small standalone helpers used by the dashboard screen.
/// Kept together in one file since they're both short and unrelated
/// to any single widget.
library;

/// Parses a time string like "10:00 AM" into a DateTime for *today*.
/// Returns null if the string is missing or doesn't match the expected format.
DateTime? parseTimeToday(String? timeStr) {
  if (timeStr == null || timeStr.trim().isEmpty) return null;

  final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
      .firstMatch(timeStr.trim());
  if (match == null) return null;

  int hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final period = match.group(3)!.toUpperCase();

  if (period == 'PM' && hour != 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;

  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

/// Returns "Good morning" / "Good afternoon" / "Good evening" based on
/// the device's current time.
/// Boundaries: before 12pm = morning, 12pm–5pm = afternoon, after 5pm = evening.
String greetingForNow([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}