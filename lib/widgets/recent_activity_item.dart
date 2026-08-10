import 'package:flutter/material.dart';

/// A single row in the "recent activity" list below the chart
/// (e.g. "BNI leadership check-in · Held 8:00 AM · 2 action points captured").
class RecentActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status; // e.g. 'HELD', 'MISSED', 'UPCOMING'

  const RecentActivityItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  Color get _statusColor {
    switch (status.toUpperCase()) {
      case 'HELD':
        return const Color(0xFF2E7D32);
      case 'MISSED':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFEF6C00);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: _statusColor, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(color: _statusColor, fontWeight: FontWeight.w700, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the list when there's no recent activity yet
/// (i.e. the user hasn't completed any appointments).
class NoRecentActivity extends StatelessWidget {
  const NoRecentActivity({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Icon(Icons.event_note_outlined, color: Colors.grey[400], size: 28),
          const SizedBox(height: 10),
          Text(
            'No recent activity',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            'Appointments you complete will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}