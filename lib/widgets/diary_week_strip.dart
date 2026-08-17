import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/diary_utils.dart';

/// The row of 7 day cells at the top of the diary (MON 6, TUE 7, ...).
/// Selected day is a solid orange rounded cell; other days show a small
/// dot underneath if they have at least one appointment.
class DiaryWeekStrip extends StatelessWidget {
  final List<DateTime> weekDays;
  final DateTime selectedDate;
  final Set<String> datesWithAppointments; // keys from dateKey()
  final ValueChanged<DateTime> onSelect;

  const DiaryWeekStrip({
    super.key,
    required this.weekDays,
    required this.selectedDate,
    required this.datesWithAppointments,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(weekDays.length, (i) {
        final day = weekDays[i];
        final isSelected = _isSameDay(day, selectedDate);
        final hasAppointments = datesWithAppointments.contains(dateKey(day));

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(day),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.orange : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? AppColors.orange : Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    weekdayShort[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !hasAppointments
                          ? Colors.transparent
                          : (isSelected ? Colors.white : AppColors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}