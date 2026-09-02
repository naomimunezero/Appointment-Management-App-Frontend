import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HistoryItem {
  final String action;
  final String details;
  final DateTime timestamp;
  final IconData icon;
  final Color iconColor;

  HistoryItem({
    required this.action,
    required this.details,
    required this.timestamp,
    required this.icon,
    required this.iconColor,
  });
}

class HistorySection extends StatelessWidget {
  final List<HistoryItem> historyItems;

  const HistorySection({
    super.key,
    required this.historyItems,
  });

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateOnly == today) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')} today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.day} ${_monthName(dateTime.month)}';
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (historyItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HISTORY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No history recorded',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HISTORY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            historyItems.length,
            (index) {
              final item = historyItems[index];
              final isLast = index == historyItems.length - 1;

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline dot
                      Column(
                        children: [
                          Icon(
                            item.icon,
                            size: 16,
                            color: item.iconColor,
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 40,
                              color: const Color(0xFFE2E5EA),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.action,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.details,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF888888),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTime(item.timestamp),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFAAAAAA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isLast) const SizedBox(height: 4),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
