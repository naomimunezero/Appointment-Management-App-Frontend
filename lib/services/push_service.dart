import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'live_refresh.dart';

// Global navigator key for deep linking from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // The OS shows the notification itself when the app is closed; nothing needed here.
}

class PushService {
  static final _local = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission();

    // App open: FCM doesn't show a banner, so show one ourselves and refresh pages.
    FirebaseMessaging.onMessage.listen((message) {
      print('PUSH RECEIVED (foreground): ${message.notification?.title}');
      liveRefresh.value++;
      final n = message.notification;
      if (n != null) {
        _local.show(
          message.hashCode,
          n.title,
          n.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'appointment_reminders', 'Appointment Reminders',
              importance: Importance.high, priority: Priority.high,
            ),
          ),
          payload: _getNotificationPayload(message.data),
        );
      }
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('NOTIFICATION TAPPED (background): ${message.data}');
      _handleNotificationTap(message.data);
    });

    // Handle notification tap when app is terminated (cold start)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('NOTIFICATION TAPPED (terminated): ${message.data}');
        _handleNotificationTap(message.data);
      }
    });

    // Handle local notification tap
    const androidSettings = AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          print('LOCAL NOTIFICATION TAPPED: ${details.payload}');
          _handleNotificationPayload(details.payload!);
        }
      },
    );

    fcm.onTokenRefresh.listen(ApiService.registerDeviceToken);
  }

  /// Call right after a successful login/register.
  static Future<void> registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await ApiService.registerDeviceToken(token);
  }

  /// Extract notification payload as JSON string
  static String _getNotificationPayload(Map<String, dynamic> data) {
    return data.toString();
  }

  /// Handle notification tap from payload string
  static void _handleNotificationPayload(String payload) {
    try {
      // Parse the payload (simple string representation of Map)
      final data = _parseMapString(payload);
      _handleNotificationTap(data);
    } catch (e) {
      print('Error parsing notification payload: $e');
    }
  }

  /// Parse simple map string like "{key: value, key2: value2}" into Map
  static Map<String, dynamic> _parseMapString(String str) {
    final data = <String, dynamic>{};
    // Remove braces and split by comma
    final content = str.replaceAll('{', '').replaceAll('}', '').trim();
    if (content.isEmpty) return data;

    final pairs = content.split(',');
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        final key = parts[0].trim();
        final value = parts[1].trim();
        data[key] = value;
      }
    }
    return data;
  }

  /// Handle notification tap based on type and data
  static void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final appointmentId = data['appointment_id']?.toString();
    final actionPointId = data['action_point_id']?.toString();

    print('Handling notification tap: type=$type, appointmentId=$appointmentId, actionPointId=$actionPointId');

    if (navigatorKey.currentContext == null) {
      print('Navigator key context is null, cannot navigate');
      return;
    }

    switch (type) {
      case 'reminder':
      case 'missed_nudge':
        // Open appointment details
        if (appointmentId != null) {
          final aptId = int.tryParse(appointmentId);
          if (aptId != null) {
            navigatorKey.currentState?.pushNamed(
              '/appointment-details',
              arguments: {'appointmentId': aptId},
            );
          }
        }
        break;

      case 'overdue_action':
        // Open appointment details (could also open action point screen if exists)
        if (appointmentId != null) {
          final aptId = int.tryParse(appointmentId);
          if (aptId != null) {
            navigatorKey.currentState?.pushNamed(
              '/appointment-details',
              arguments: {'appointmentId': aptId},
            );
          }
        }
        break;

      case 'daily_summary':
        // Open diary screen
        navigatorKey.currentState?.pushNamed('/diary');
        break;

      case 'activity_alert':
        // Open appointment details if available
        if (appointmentId != null) {
          final aptId = int.tryParse(appointmentId);
          if (aptId != null) {
            navigatorKey.currentState?.pushNamed(
              '/appointment-details',
              arguments: {'appointmentId': aptId},
            );
          }
        } else {
          // Fallback to dashboard if no appointment ID
          navigatorKey.currentState?.pushNamed('/dashboard');
        }
        break;

      default:
        // Default to dashboard
        navigatorKey.currentState?.pushNamed('/dashboard');
        break;
    }
  }
}