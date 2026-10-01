import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const navy = Color(0xFF183764);
  static const orange = Color(0xFFF26522);
  static const teal = Color(0xFF1AA5AB);
  static const green = Color(0xFF2E9E5B);
  static const red = Color(0xFFEF3F7A);
  static const background = Color(0xFFF5F7FA);
  static const cardWhite = Color(0xFFFFFFFF);
}

class AppTheme {
  static final ValueNotifier<_TopSnackBarNotification?> _topSnackBarMessage =
      ValueNotifier(null);
  static Timer? _topSnackBarTimer;

  static ThemeData light() {
    final base = ThemeData.light();

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.navy,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.navy,
        secondary: AppColors.teal,
        error: AppColors.red,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.navy,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E5EA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E5EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.green,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Shows a green notification just below the app bar.
  static void showTopSnackBar(
    BuildContext context,
    String message, {
    double appBarHeight = kToolbarHeight,
  }) {
    _topSnackBarTimer?.cancel();
    _topSnackBarMessage.value = _TopSnackBarNotification(
      message: message,
      appBarHeight: appBarHeight,
    );
    _topSnackBarTimer = Timer(const Duration(seconds: 5), () {
      _topSnackBarMessage.value = null;
    });
  }
}

class _TopSnackBarNotification {
  const _TopSnackBarNotification({
    required this.message,
    required this.appBarHeight,
  });

  final String message;
  final double appBarHeight;
}

/// App-level notification host: it stays above each route's Scaffold and
/// positions messages consistently below the status bar and toolbar.
class AppSnackBarHost extends StatelessWidget {
  const AppSnackBarHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        ValueListenableBuilder<_TopSnackBarNotification?>(
          valueListenable: AppTheme._topSnackBarMessage,
          builder: (context, notification, _) {
            if (notification == null) return const SizedBox.shrink();
            return Positioned(
              top: mediaQuery.padding.top + notification.appBarHeight + 8,
              left: 12,
              right: 12,
              child: Semantics(
                liveRegion: true,
                child: Material(
                  color: AppColors.green,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Text(
                      notification.message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ));
          },
        ),
      ],
    );
  }
}
