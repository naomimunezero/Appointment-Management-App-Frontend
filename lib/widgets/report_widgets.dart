import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/appointment.dart';
import '../utils/status_utils.dart';

class InReportCard extends StatelessWidget {
  final Appointment? selected;
  final VoidCallback onPreview;

  const InReportCard({super.key, required this.selected, required this.onPreview});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('IN THIS REPORT',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              if (selected != null)
                GestureDetector(
                  onTap: onPreview,
                  child: const Text('Preview →',
                      style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (selected == null)
            Text('Tap an appointment below to see its details here.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13))
          else ...[
            _bullet('${selected!.purpose} · ${selected!.status}'),
            _bullet('People met: ${selected!.attendees.isEmpty ? '—' : selected!.attendees.join(', ')}'),
            _bullet(selected!.discussionNotes?.isNotEmpty == true
                ? 'Discussion: ${selected!.discussionNotes}'
                : 'No discussion notes recorded yet.'),
            _bullet('Action points: ${selected!.actionPoints.where((a) => a.status == 'done').length}/${selected!.actionPoints.length} completed'),
          ],
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: CircleAvatar(radius: 3, backgroundColor: AppColors.navy),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class AppointmentListTile extends StatelessWidget {
  final Appointment appointment;
  final bool selected;
  final VoidCallback onTap;

  const AppointmentListTile({super.key, required this.appointment, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: statusColor(appointment.status), width: 4)),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.navy.withOpacity(0.15), blurRadius: 8)]
              : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appointment.purpose, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '${appointment.appointmentDate} · ${appointment.attendees.isEmpty ? "not held" : appointment.attendees.join(", ")}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor(appointment.status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                appointment.status.toUpperCase(),
                style: TextStyle(color: statusColor(appointment.status), fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}