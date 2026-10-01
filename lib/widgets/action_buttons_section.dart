import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ActionButtonsSection extends StatelessWidget {
  final VoidCallback? onRecordOutcome;
  final VoidCallback? onEdit;
  final VoidCallback? onReschedule;
  final bool isLoading;

  const ActionButtonsSection({
    super.key,
    this.onRecordOutcome,
    this.onEdit,
    this.onReschedule,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onRecordOutcome != null) ElevatedButton.icon(
            onPressed: isLoading ? null : onRecordOutcome,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              'Record outcome',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRecordOutcome != null && (onEdit != null || onReschedule != null)) const SizedBox(height: 12),
          if (onEdit != null || onReschedule != null) Row(
            children: [
              Expanded(
                child: onEdit == null ? const SizedBox.shrink() : OutlinedButton.icon(
                  onPressed: isLoading ? null : onEdit,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.navy, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: onReschedule == null ? const SizedBox.shrink() : OutlinedButton.icon(
                  onPressed: isLoading ? null : onReschedule,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.navy, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.event_repeat_outlined, size: 18),
                  label: const Text('Reschedule'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
