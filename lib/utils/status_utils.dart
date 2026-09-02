import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Single source of truth for appointment status colors.
Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'held':
      return const Color(0xFF1E8A6E);
    case 'upcoming':
      return const Color(0xFF0E8FA0);
    case 'missed':
      return AppColors.red;
    case 'cancelled':
      return Colors.grey;
    default:
      return AppColors.navy;
  }
}

/// Light background tint for status pills/badges.
Color statusBackground(String status) => statusColor(status).withOpacity(0.12);