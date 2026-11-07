import 'dart:async';
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
  final VoidCallback? onTap;

  const NextAppointmentCard({
    super.key,
    required this.appointment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (appointment == null) return _buildEmptyState();
    return _buildAppointmentState(appointment!);
  }

  Widget _buildAppointmentState(Map<String, dynamic> next) {
    final start = parseAppointmentDateTime(
      (next['appointment_date'] ?? next['date'])?.toString(),
      next['start_time']?.toString(),
    );
    final durationMinutes = next['duration_minutes'] is int
        ? next['duration_minutes'] as int
        : int.tryParse('${next['duration_minutes'] ?? ''}') ?? 0;

    final card = Container(
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

    if (onTap == null) return card;

    return GestureDetector(
      onTap: onTap,
      child: card,
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

/// Counts down to the appointment. The ring is hidden beyond 24 hours,
/// becomes full at 24 hours, then empties as the appointment approaches.
class _CountdownRing extends StatefulWidget {
  final DateTime? appointmentStart;

  const _CountdownRing({required this.appointmentStart});

  @override
  State<_CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<_CountdownRing> {
  static const _window = Duration(hours: 24);
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      final now = DateTime.now();
      if (mounted) setState(() => _now = now);
    });
  }

  @override
  void didUpdateWidget(covariant _CountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appointmentStart != widget.appointmentStart) {
      _now = DateTime.now();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.appointmentStart;
    final remaining = start?.difference(_now);
    final remainingHours = remaining == null
        ? null
        : remaining.inSeconds / Duration.secondsPerHour;
    final ringProgress = remaining == null || remaining > _window
        ? 0.0
        : (remaining.inSeconds / _window.inSeconds).clamp(0.0, 1.0).toDouble();
    String label;

    if (remaining == null) {
      label = '--';
    } else if (remaining.isNegative || remaining == Duration.zero) {
      label = 'NOW';
    } else if (remaining > _window) {
      final days = (remaining.inSeconds / Duration.secondsPerDay).ceil();
      label = '$days\n${days == 1 ? 'DAY' : 'DAYS'}';
    } else if (remainingHours! >= 1) {
      final hours = remainingHours.roundToDouble();
      label = '${hours == hours.roundToDouble() ? hours.toInt() : hours}\n${hours == 1 ? 'HR' : 'HRS'}';
    } else {
      final halfHours = (remainingHours! * 2).ceil() / 2;
      label = '$halfHours\n${halfHours == 1 ? 'HR' : 'HRS'}';
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
              value: ringProgress,
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
