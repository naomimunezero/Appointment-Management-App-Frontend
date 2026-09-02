import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The row of 4 stat cards (UPCOMING / HELD / MISSED / ACTIONS DUE).
/// Pulled out of dashboard_screen.dart as-is, just wrapped in its own
/// widget so the screen file is easier to read.
class StatCardsRow extends StatelessWidget {
  final int upcoming;
  final int held;
  final int missed;
  final int actionsDue;
  final VoidCallback? onUpcomingTap;
  final VoidCallback? onHeldTap;
  final VoidCallback? onMissedTap;
  final VoidCallback? onActionsTap;

  const StatCardsRow({
    super.key,
    required this.upcoming,
    required this.held,
    required this.missed,
    required this.actionsDue,
    this.onUpcomingTap,
    this.onHeldTap,
    this.onMissedTap,
    this.onActionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StatCard(number: '$upcoming', label: 'UPCOMING', color: AppColors.navy, onTap: onUpcomingTap),
        const SizedBox(width: 10),
        StatCard(number: '$held', label: 'HELD', color: AppColors.green, onTap: onHeldTap),
        const SizedBox(width: 10),
        StatCard(number: '$missed', label: 'MISSED', color: AppColors.red, onTap: onMissedTap),
        const SizedBox(width: 10),
        StatCard(number: '$actionsDue', label: 'ACTIONS DUE', color: AppColors.orange, onTap: onActionsTap),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String number;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({super.key, required this.number, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
            ),
            child: Column(
              children: [
                Text(number, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}