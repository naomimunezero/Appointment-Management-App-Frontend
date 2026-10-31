import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/date_time_utils.dart';

class ActivityLogRow extends StatelessWidget {
  const ActivityLogRow({
    required this.item,
    this.bottomPadding = 12,
    super.key,
  });

  final Map<String, dynamic> item;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final actorData = item['actor'] ?? item['user'];
    final actor = actorData is Map
        ? actorData['name']?.toString()
        : item['actor_name']?.toString();
    final message =
        (item['title'] ??
                item['message'] ??
                item['description'] ??
                'Activity recorded')
            .toString();
    final rawTime = item['time'] ?? item['created_at'] ?? item['timestamp'];
    final date = DateTimeUtils.formatServerTimestamp(rawTime?.toString());
    final line =
        actor != null &&
            actor.isNotEmpty &&
            !message.toLowerCase().startsWith(actor.toLowerCase())
        ? '$actor $message'
        : message;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: 9),
            decoration: BoxDecoration(
              color: _activityColor(message),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.blueGrey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _activityColor(String text) {
    final value = text.toLowerCase();
    if (value.contains('cancel') || value.contains('delete')) {
      return AppColors.red;
    }
    if (value.contains('reschedul') ||
        value.contains('edit') ||
        value.contains('updat')) {
      return AppColors.orange;
    }
    return AppColors.teal;
  }
}
