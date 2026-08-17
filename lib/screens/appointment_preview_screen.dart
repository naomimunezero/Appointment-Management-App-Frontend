import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/appointment.dart';
import '../widgets/report_widgets.dart';

class AppointmentPreviewScreen extends StatelessWidget {
  final Appointment appointment;
  const AppointmentPreviewScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(appointment.purpose)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor(appointment.status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(appointment.status.toUpperCase(),
                  style: TextStyle(color: statusColor(appointment.status), fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            const SizedBox(height: 16),
            Text('${appointment.appointmentDate} · ${appointment.startTime} · ${appointment.durationMinutes} min',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (appointment.location != null) ...[
              const SizedBox(height: 4),
              Text(appointment.location!, style: TextStyle(color: Colors.grey[600])),
            ],
            const SizedBox(height: 20),
            const Text('PEOPLE MET', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(appointment.attendees.isEmpty ? 'None recorded' : appointment.attendees.join(', ')),
            const SizedBox(height: 20),
            const Text('DISCUSSION', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(appointment.discussionNotes?.isNotEmpty == true ? appointment.discussionNotes! : 'No notes recorded'),
            const SizedBox(height: 20),
            const Text('ACTION POINTS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            if (appointment.actionPoints.isEmpty) const Text('None')
            else ...appointment.actionPoints.map((ap) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(ap.status == 'done' ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 18, color: ap.status == 'done' ? AppColors.green : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(ap.description)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}