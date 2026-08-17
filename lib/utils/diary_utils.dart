import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small helpers shared by the diary screen and its widgets:
/// date formatting (week ranges, day headers) and status colors/labels.

const List<String> weekdayShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const List<String> weekdayFull = [
  'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'
];
const List<String> monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

/// Returns the Monday of the week containing [date], time stripped.
DateTime startOfWeek(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

String _dKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Key used to group appointments by date, e.g. "2026-07-09".
String dateKey(DateTime d) => _dKey(d);

/// "6 – 12 July 2026" (or "28 June – 4 July 2026" if the week spans months).
String formatWeekRange(DateTime start, DateTime end) {
  final startMonth = monthNames[start.month - 1];
  final endMonth = monthNames[end.month - 1];
  if (start.month == end.month && start.year == end.year) {
    return '${start.day} – ${end.day} $endMonth ${end.year}';
  }
  return '${start.day} $startMonth – ${end.day} $endMonth ${end.year}';
}

/// "THURSDAY · 9 JULY"
String formatDayHeader(DateTime date) {
  final weekday = weekdayFull[date.weekday - 1];
  final month = monthNames[date.month - 1].toUpperCase();
  return '$weekday · ${date.day} $month';
}

/// Splits a formatted time string like "8:00 AM" into ["8:00", "AM"]
/// for the two-line time display on each appointment card.
List<String> splitTime(String? timeStr) {
  if (timeStr == null || timeStr.trim().isEmpty) return ['--', ''];
  final parts = timeStr.trim().split(' ');
  if (parts.length == 2) return parts;
  return [timeStr, ''];
}

/// Color used for the status pill text and the card's left accent bar.
Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'held':
      return const Color(0xFF1E8A6E);
    case 'upcoming':
      return const Color(0xFF0E8FA0);
    case 'missed':
      return AppColors.red;
    case 'cancelled':
      return Colors.grey;
    default:
      return AppColors.navy;
  }
}

/// Light background tint for the status pill.
Color statusBackground(String status) => statusColor(status).withOpacity(0.12);