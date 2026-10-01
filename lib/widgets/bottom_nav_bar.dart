import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onAddTap;
  final bool showReports;

  const AppBottomNav({super.key, required this.currentIndex, required this.onTap, this.onAddTap, this.showReports = true});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        SafeArea(
          top: false, // only pad the bottom; this widget never touches the top of the screen
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                _navItem(Icons.home_rounded, 'Home', 0),
                _navItem(Icons.event_note_rounded, 'Diary', 1),
                const Expanded(child: SizedBox()),
                if (showReports) _navItem(Icons.bar_chart_rounded, 'Reports', 2)
                else const Expanded(child: SizedBox()),
                _navItem(Icons.settings_rounded, 'Settings', 3),
              ],
            ),
          ),
        ),
        if (onAddTap != null) Positioned(
          top: -22,
          child: GestureDetector(
            onTap: onAddTap,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = currentIndex == index;
    final color = selected ? AppColors.navy : Colors.grey[500];
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
