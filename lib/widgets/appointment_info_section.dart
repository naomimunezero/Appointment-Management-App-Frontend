import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/appointment.dart';
import '../utils/status_utils.dart';
import '../utils/date_time_utils.dart';

class AppointmentInfoSection extends StatelessWidget {
  final Appointment appointment;

  const AppointmentInfoSection({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor(appointment.status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              appointment.status.toUpperCase(),
              style: TextStyle(
                color: statusColor(appointment.status),
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            appointment.purpose,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),

          // Description (if available)
          if (appointment.discussionNotes?.isNotEmpty == true)
            Text(
              appointment.discussionNotes!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
                height: 1.5,
              ),
            ),
          const SizedBox(height: 16),

          // Date, time, duration
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF888888)),
              const SizedBox(width: 8),
              Text(
                DateTimeUtils.formatDate(appointment.appointmentDate),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.access_time_outlined, size: 16, color: Color(0xFF888888)),
              const SizedBox(width: 8),
              Text(
                DateTimeUtils.formatTime(appointment.startTime),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.hourglass_bottom_outlined, size: 16, color: Color(0xFF888888)),
              const SizedBox(width: 8),
              Text(
                '${appointment.durationMinutes}m',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          // Location
          if (appointment.location?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appointment.location!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
