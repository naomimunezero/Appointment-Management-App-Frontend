import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/diary_utils.dart';

/// A single appointment row in the diary list — time on the left,
/// a colored accent bar, then title/subtitle, with a status pill
/// aligned to the top-right.
class DiaryAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback? onTap;

  const DiaryAppointmentCard({super.key, required this.appointment, this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = (appointment['status'] ?? 'upcoming').toString();
    final color = statusColor(status);
    final timeParts = splitTime(appointment['start_time'] as String?);

    final subtitle = _subtitle();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(timeParts[0],
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy)),
                  Text(timeParts[1], style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Container(
              width: 3,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          appointment['purpose'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBackground(status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds "Robert K. · Ntinda · 1 hr" style subtitle from whatever
  // fields are present, skipping any that are missing.
  String _subtitle() {
    final person = appointment['person_to_meet'];
    final location = appointment['location'];
    final duration = appointment['duration_minutes'];

    final parts = <String>[];
    if (person != null && person.toString().isNotEmpty) parts.add(person.toString());
    if (location != null && location.toString().isNotEmpty) parts.add(location.toString());
    if (duration != null) {
      final mins = int.tryParse(duration.toString());
      if (mins != null) {
        parts.add(mins >= 60 && mins % 60 == 0 ? '${mins ~/ 60} hr' : '$mins min');
      }
    }
    return parts.join(' · ');
  }
}