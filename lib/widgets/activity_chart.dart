import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bar chart for the "Activity" card.
///
/// Important behaviour: if every value in [values] is 0 (nothing happened
/// in the selected period), this still draws the chart — with flat,
/// light-grey bars and a small caption underneath — instead of leaving a
/// blank space or dividing by zero when working out bar heights.
class ActivityChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;

  const ActivityChart({super.key, required this.labels, required this.values});

  @override
  Widget build(BuildContext context) {
    final hasData = values.any((v) => v > 0);
    final maxValue = hasData ? values.reduce((a, b) => a > b ? a : b) : 1;
    final busiestIndex = hasData ? values.indexOf(maxValue) : -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(labels.length, (i) {
              final value = i < values.length ? values[i] : 0;
              final heightFraction = hasData ? value / maxValue : 0.0;

              // Even empty bars get a small minimum height so the chart
              // reads as "nothing happened" rather than "something broke".
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
                              : (isBusiest ? AppColors.orange : AppColors.navy.withValues(alpha: 0.85)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        i < labels.length ? labels[i] : '',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
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
    );
  }
}