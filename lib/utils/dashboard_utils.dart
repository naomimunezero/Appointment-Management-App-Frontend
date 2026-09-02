/// Small standalone helpers used by the dashboard screen.
/// Kept together in one file since they're both short and unrelated
/// to any single widget.
library;

Map<String, dynamic> normalizeDashboardPayload(dynamic raw) {
  final root = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  final normalized = <String, dynamic>{};

  void collect(dynamic value) {
    if (value is! Map) {
      return;
    }

    final map = Map<String, dynamic>.from(value);
    for (final entry in map.entries) {
      final key = entry.key.toString();
      final val = entry.value;

      if (val is Map && ['data', 'summary', 'dashboard', 'payload'].contains(key)) {
        collect(val);
        continue;
      }

      if (val is Map && val.containsKey('data') && val['data'] is List) {
        normalized[key] = val['data'];
        continue;
      }

      if (val is Map && val.containsKey('data') && val['data'] is Map) {
        collect(val['data']);
        continue;
      }

      normalized[key] = val;
    }
  }

  collect(root);

  if (normalized.isEmpty && root.isNotEmpty) {
    return root;
  }

  return normalized;
}

Map<String, List<dynamic>> demoActivitySeries(String period) {
  switch (period) {
    case 'today':
      return {
        'day_labels': ['9a', '11a', '1p', '3p', '5p'],
        'day_values': [1, 3, 2, 5, 4],
        'time_labels': ['9', '11', '13', '15', '17'],
        'time_values': [1, 2, 4, 3, 2],
      };
    case 'thisWeek':
    case 'last7Days':
      return {
        'day_labels': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
        'day_values': [2, 4, 3, 5, 6, 1, 2],
        'time_labels': ['9', '11', '13', '15', '17'],
        'time_values': [1, 2, 4, 3, 2],
      };
    case 'last2Weeks':
      return {
        'day_labels': ['W1', 'W2'],
        'day_values': [5, 8],
        'time_labels': ['9', '11', '13', '15', '17'],
        'time_values': [2, 3, 5, 4, 3],
      };
    case 'lastMonth':
      return {
        'day_labels': ['W1', 'W2', 'W3', 'W4'],
        'day_values': [3, 5, 6, 4],
        'time_labels': ['9', '11', '13', '15', '17'],
        'time_values': [2, 3, 5, 4, 3],
      };
    default:
      return {
        'day_labels': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
        'day_values': [2, 4, 3, 5, 6, 1, 2],
        'time_labels': ['9', '11', '13', '15', '17'],
        'time_values': [1, 2, 4, 3, 2],
      };
  }
}

List<Map<String, dynamic>> extractListFromDashboard(dynamic source) {
  if (source is List) {
    return source.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  if (source is Map) {
    final map = Map<String, dynamic>.from(source);
    for (final key in ['data', 'items', 'appointments', 'results']) {
      final value = map[key];
      if (value is List) {
        return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
  }

  return const [];
}

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