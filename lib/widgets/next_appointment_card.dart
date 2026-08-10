import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/dashboard_utils.dart';

/// The navy card at the top of the dashboard.
///
/// If [appointment] is null, this shows a "No upcoming appointment" message
/// inside the SAME navy container — so the screen still looks intentional
/// instead of just leaving a gap.
class NextAppointmentCard extends StatelessWidget {
  final Map<String, dynamic>? appointment;

  const NextAppointmentCard({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    if (appointment == null) return _buildEmptyState();
    return _buildAppointmentState(appointment!);
  }

  Widget _buildAppointmentState(Map<String, dynamic> next) {
    final start = parseTimeToday(next['start_time'] as String?);
    final durationMinutes = next['duration_minutes'] is int
        ? next['duration_minutes'] as int
        : int.tryParse('${next['duration_minutes'] ?? ''}') ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NEXT APPOINTMENT',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  next['purpose'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(_subtitle(next), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text('${next['start_time'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 14),
                    const Icon(Icons.hourglass_bottom, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text('$durationMinutes min', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          _CountdownRing(appointmentStart: start),
        ],
      ),
    );
  }

  String _subtitle(Map<String, dynamic> next) {
    final withWho = next['with'] ?? next['contact_name'];
    final location = next['location'] ?? '';
    if (withWho != null && withWho.toString().isNotEmpty) {
      return 'With $withWho${location.toString().isNotEmpty ? ' · $location' : ''}';
    }
    return location.toString();
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.event_available, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 12),
          const Text(
            'No upcoming appointment',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            "You're all caught up for now.",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// The small "42 MIN" progress ring. Private to this file since it's
/// only ever used inside the appointment card.
/// Fills up as the appointment approaches, based on a 4-hour window
/// (empty at 4+ hours away, full right at start time).
class _CountdownRing extends StatelessWidget {
  final DateTime? appointmentStart;
  static const _lookAheadMinutes = 240;

  const _CountdownRing({required this.appointmentStart});

  @override
  Widget build(BuildContext context) {
    final minutesUntil =
        appointmentStart == null ? -1 : appointmentStart!.difference(DateTime.now()).inMinutes;

    double progress;
    String label;

    if (appointmentStart == null) {
      progress = 0;
      label = 'TODAY';
    } else if (minutesUntil <= 0) {
      progress = 1;
      label = 'NOW';
    } else {
      progress = 1 - (minutesUntil.clamp(0, _lookAheadMinutes) / _lookAheadMinutes);
      label = minutesUntil >= 60
          ? '${(minutesUntil / 60).floor()}H ${minutesUntil % 60}M'
          : '$minutesUntil\nMIN';
    }

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1.1),
          ),
        ],
      ),
    );
  }
}