import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/sign_in_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/register_screen.dart';
import 'screens/diary_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/invite_assistant_screen.dart';
import 'screens/pending_invite_screen.dart';
import 'screens/new_appointment_screen.dart';
import 'screens/reports_screen.dart';

void main() {
  runApp(const AppointmentApp());
}

class AppointmentApp extends StatelessWidget {
  const AppointmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Appointment Manager',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const SignInScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/diary': (context) => DiaryScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/invite-assistant': (context) => const InviteAssistantScreen(),
        '/pending-invite': (context) => const PendingInviteScreen(),
        '/new-appointment': (context) => const NewAppointmentScreen(),
        '/reports': (context) => const ReportsScreen(),
      },
    );
  }
}
