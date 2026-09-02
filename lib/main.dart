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
import 'screens/appointment_details_screen.dart';
import 'screens/record_outcome_screen.dart';
import 'screens/action_points_tracker_screen.dart';

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
      onGenerateRoute: (settings) {
        if (settings.name == '/appointment-details') {
          final args = settings.arguments as Map<String, dynamic>?;
          final appointmentId = args?['appointmentId'] as int?;
          if (appointmentId != null) {
            return MaterialPageRoute(
              builder: (context) => AppointmentDetailsScreen(appointmentId: appointmentId),
            );
          }
        }
        if (settings.name == '/record-outcome') {
          final args = settings.arguments as Map<String, dynamic>?;
          final appointmentId = args?['appointmentId'] as int?;
          if (appointmentId != null) {
            return MaterialPageRoute(
              builder: (context) => RecordOutcomeScreen(appointmentId: appointmentId),
            );
          }
        }
        return null;
      },
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
        '/action-points': (context) => const ActionPointsTrackerScreen(),
      },
    );
  }
}
