import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ActivityPeriod { today, thisWeek, last7Days, last2Weeks, lastMonth }

extension ActivityPeriodLabel on ActivityPeriod {
  String get label {
    switch (this) {
      case ActivityPeriod.today:
        return 'Today';
      case ActivityPeriod.thisWeek:
        return 'This week';
      case ActivityPeriod.last7Days:
        return 'Last 7 days';
      case ActivityPeriod.last2Weeks:
        return 'Last 2 weeks';
      case ActivityPeriod.lastMonth:
        return 'Last month';
    }
  }
}

/// Horizontal, scrollable row of filter pills (Today / This week / ...).
/// This is a "dumb" widget — it just displays [selected] and calls
/// [onChanged] when the user taps a pill. The dashboard screen decides
/// what to actually do with the new period (i.e. reload the chart).
class TimeFilterTabs extends StatelessWidget {
  final ActivityPeriod selected;
  final ValueChanged<ActivityPeriod> onChanged;

  const TimeFilterTabs({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ActivityPeriod.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final period = ActivityPeriod.values[index];
          final isSelected = period == selected;
          return GestureDetector(
            onTap: () => onChanged(period),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.navy : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.navy : Colors.grey.shade300),
              ),
              child: Text(
                period.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}