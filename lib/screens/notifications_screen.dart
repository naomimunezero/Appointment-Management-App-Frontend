import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/appointment.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List reminders = [];
  List overdue = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await ApiService.getNotifications();
    final data = response is Map ? Map<String, dynamic>.from(response as Map) : <String, dynamic>{};

    setState(() {
      reminders = List.from(data['reminders'] ?? []);
      overdue = List.from(data['overdue_action_points'] ?? []);
      _loading = false;
    });
  }

  String _timeUntil(String remindAt) {
    final target = DateTime.tryParse(remindAt);
    if (target == null) return '';
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return 'Passed';
    if (diff.inHours >= 1) return '${diff.inHours} hours to go';
    return '${diff.inMinutes} minutes to go';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text('Notifications',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (reminders.isNotEmpty) ...[
                          const _SectionLabel('TODAY'),
                          const SizedBox(height: 8),
                          ...reminders.map((r) => _NotificationCard(
                                color: AppColors.orange,
                                title: 'Reminder — ${_timeUntil(r['remind_at'])}',
                                body: '${r['appointment']?['purpose'] ?? ''} at ${r['appointment']?['start_time'] ?? ''}, ${r['appointment']?['location'] ?? ''}.',
                                time: r['remind_at']?.toString().substring(11, 16) ?? '',
                              )),
                        ],
                        if (overdue.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const _SectionLabel('OVERDUE'),
                          const SizedBox(height: 8),
                          ...overdue.map((a) => _NotificationCard(
                                color: AppColors.red,
                                title: 'Action point overdue',
                                body: '"${a['description']}" was due ${a['due_date']}.',
                                time: '',
                              )),
                        ],
                        if (reminders.isEmpty && overdue.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: Center(
                              child: Text('No notifications right now', style: TextStyle(color: Colors.grey[500])),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Colors.grey[600]));
  }
}

class _NotificationCard extends StatelessWidget {
  final Color color;
  final String title;
  final String body;
  final String time;

  const _NotificationCard({required this.color, required this.title, required this.body, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy)),
                    const SizedBox(height: 4),
                    Text(body, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}