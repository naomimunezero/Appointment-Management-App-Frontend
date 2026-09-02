import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AttendeeAvatar extends StatelessWidget {
  final String initials;
  final Color backgroundColor;
  final String name;
  final String? role;

  const AttendeeAvatar({
    super.key,
    required this.initials,
    required this.backgroundColor,
    required this.name,
    this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: backgroundColor,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (role != null) ...[
                const SizedBox(height: 2),
                Text(
                  role!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888888),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class MeetingWithSection extends StatelessWidget {
  final List<String> attendees;
  final String? sectionTitle;

  const MeetingWithSection({
    super.key,
    required this.attendees,
    this.sectionTitle = 'MEETING WITH',
  });

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return (name.isNotEmpty ? name[0] : '?').toUpperCase();
  }

  Color _getAvatarColor(int index) {
    final colors = [
      const Color(0xFFF26522), // orange
      const Color(0xFF1AA5AB), // teal
      const Color(0xFF183764), // navy
      const Color(0xFF2E9E5B), // green
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (attendees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sectionTitle ?? 'MEETING WITH',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No attendees recorded',
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
          Text(
            sectionTitle ?? 'MEETING WITH',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(
              attendees.length,
              (index) => AttendeeAvatar(
                initials: _getInitials(attendees[index]),
                backgroundColor: _getAvatarColor(index),
                name: attendees[index],
                role: null, // You can extend this to include roles if available
              ),
            ),
          ),
        ],
      ),
    );
  }
}
