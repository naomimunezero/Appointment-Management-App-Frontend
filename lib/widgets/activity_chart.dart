import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Generic bar chart for the dashboard activity cards.
class ActivityChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;
  final String title;
  final Color accentColor;

  const ActivityChart({
    super.key,
    required this.labels,
    required this.values,
    required this.title,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedLabels = labels.isEmpty ? const <String>[] : labels;
    final normalizedValues = values.isEmpty ? List.filled(normalizedLabels.length, 0) : values;
    final hasData = normalizedValues.any((v) => v > 0);
    final maxValue = hasData ? normalizedValues.reduce((a, b) => a > b ? a : b) : 1;
    final busiestIndex = hasData ? normalizedValues.indexOf(maxValue) : -1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(normalizedLabels.length, (i) {
                final value = i < normalizedValues.length ? normalizedValues[i] : 0;
                final heightFraction = hasData ? value / maxValue : 0.0;
                final barHeight = hasData ? (heightFraction * 80).clamp(6, 80).toDouble() : 10.0;
                final isBusiest = hasData && i == busiestIndex;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: !hasData
                                ? Colors.grey.shade200
                                : (isBusiest ? AppColors.orange : accentColor),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          normalizedLabels[i],
                          style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          if (!hasData) ...[
            const SizedBox(height: 8),
            Text(
              'No activity for this period',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }
}