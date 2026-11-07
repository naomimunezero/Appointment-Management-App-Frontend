import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_utils.dart';
import '../widgets/activity_log_row.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<Map<String, dynamic>> _activity = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.navy,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final notifications = await ApiService.getNotifications();
    if (!mounted) return;

    final now = DateTimeUtils.nowInUganda();
    final targetMonth = DateTime(now.year, now.month - 3, 1);
    final lastDayOfTargetMonth = DateTime(
      targetMonth.year,
      targetMonth.month + 1,
      0,
    ).day;
    final cutoff = tz.TZDateTime(
      tz.getLocation('Africa/Kampala'),
      targetMonth.year,
      targetMonth.month,
      now.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
    final activity =
        notifications
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) {
              if (item['type']?.toString() != 'activity') return false;
              final rawTime =
                  item['time'] ?? item['created_at'] ?? item['timestamp'];
              final date = DateTimeUtils.parseServerTimestamp(
                rawTime?.toString(),
              );
              return date != null &&
                  !date.isBefore(cutoff) &&
                  !date.isAfter(now);
            })
            .toList()
          ..sort((a, b) => _activityDate(b).compareTo(_activityDate(a)));

    setState(() {
      _activity = activity;
      _loading = false;
    });
  }

  DateTime _activityDate(Map<String, dynamic> item) {
    final rawTime = item['time'] ?? item['created_at'] ?? item['timestamp'];
    return DateTimeUtils.parseServerTimestamp(rawTime?.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent activity'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.navy,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text(
              'Team activity from the past 3 months',
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_loading && _activity.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_activity.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No activity in the past 3 months.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              )
            else
              for (final item in _activity)
                ActivityLogRow(item: item, bottomPadding: 16),
          ],
        ),
      ),
    );
  }
}
