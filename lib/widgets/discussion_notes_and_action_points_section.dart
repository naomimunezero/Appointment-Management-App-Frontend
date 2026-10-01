import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/action_point.dart';

class DiscussionNotesAndActionPointsSection extends StatelessWidget {
  final String? discussionNotes;
  final List<ActionPoint> actionPoints;
  final Function(int, bool)? onActionPointToggle;
  final bool showToggle;
  final bool markDoneOnly;
  final Function(int)? onActionPointEdit;
  final Function(int)? onActionPointDelete;

  const DiscussionNotesAndActionPointsSection({
    super.key,
    this.discussionNotes,
    required this.actionPoints,
    this.onActionPointToggle,
    this.showToggle = true,
    this.markDoneOnly = false,
    this.onActionPointEdit,
    this.onActionPointDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DISCUSSION NOTES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          if (discussionNotes != null && discussionNotes!.isNotEmpty)
            Text(
              discussionNotes!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            )
          else
            Text(
              'No discussion notes recorded',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'ACTION POINTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          if (actionPoints.isEmpty)
            Text(
              'No action points recorded',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actionPoints.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final actionPoint = actionPoints[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: showToggle ? IconButton(
                    tooltip: actionPoint.completed
                        ? 'Mark action point incomplete'
                        : 'Mark action point complete',
                    onPressed: onActionPointToggle == null || (markDoneOnly && actionPoint.completed)
                        ? null
                        : () => onActionPointToggle!(index, !actionPoint.completed),
                    icon: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: actionPoint.completed ? AppColors.green : Colors.grey.shade400,
                          width: 2,
                        ),
                        color: actionPoint.completed ? AppColors.green : Colors.transparent,
                      ),
                      child: actionPoint.completed
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  ) : null,
                  title: Text(
                    actionPoint.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: actionPoint.completed ? Colors.grey[500] : Colors.grey[800],
                      decoration: actionPoint.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: actionPoint.dueDate != null
                      ? Text(
                          'Due: ${_formatDate(actionPoint.dueDate!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (actionPoint.owner != null)
                        Text(
                          actionPoint.owner!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (onActionPointEdit != null)
                        IconButton(
                          onPressed: () => onActionPointEdit!(index),
                          icon: const Icon(Icons.edit, size: 16, color: Color(0xFFAAAAAA)),
                          tooltip: 'Edit action point',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      if (onActionPointDelete != null)
                        IconButton(
                          onPressed: () => onActionPointDelete!(index),
                          icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFCCCCCC)),
                          tooltip: 'Delete action point',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
