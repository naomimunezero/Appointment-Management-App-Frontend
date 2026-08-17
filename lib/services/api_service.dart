import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_summary.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.82:8000/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // NEW: saves the user's name at the same time we save the token,
  // so the dashboard can show it without any extra network call.
  static Future<void> _saveUserName(String? name) async {
    if (name == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
  }

  // NEW: dashboard calls this to display the greeting.
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_name'); // NEW: clear name on logout too
  }

  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _saveToken(data['token']);
        await _saveUserName(data['user']?['name']); // NEW
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'message': data['message'] ?? 'Registration failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveToken(data['token']);
        await _saveUserName(data['user']?['name']);
        return {
          'success': true,
          'user': data['user'],
          'pendingInvites': data['pendingInvites'] ?? const [],
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> inviteAssistant(String email, List<String> permissions) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/assistant-invites'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'email': email, 'permissions': permissions}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'invite': data['invite'], 'token': data['token']};
      }
      return {'success': false, 'message': data['message'] ?? 'Unable to send invitation'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> acceptAssistantInvite({required String token}) async {
    try {
      final authToken = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/assistant-invites/$token/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Unable to accept invitation'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> declineAssistantInvite({required String token}) async {
    try {
      final authToken = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/assistant-invites/$token/decline'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Unable to decline invitation'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> getDashboardSummary() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/summary'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getNotifications() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  // NEW: powers the activity chart / time filter pills on the dashboard.
  // See dashboard_screen.dart for the expected response shape.
  static Future<Map<String, dynamic>> getActivity(String period) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/activity?period=$period'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  // Powers the diary screen. Expects a Laravel route that returns
  // appointments between two dates for the logged-in user's scope.
  static Future<List<dynamic>> getAppointments(DateTime from, DateTime to) async {
    final token = await _getToken();
    final fromStr = from.toIso8601String().substring(0, 10); // "2026-07-06"
    final toStr = to.toIso8601String().substring(0, 10);
    final response = await http.get(
      Uri.parse('$baseUrl/appointments?from=$fromStr&to=$toStr'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  /// Loads the report for the inclusive date range. The API should return:
  /// {
  ///   "appointments_held": 12, "people_met": 15,
  ///   "actions_closed": 9, "actions_total": 14,
  ///   "appointments": [{"title": "...", "date": "2026-07-09",
  ///     "people": ["..."], "action_points": 2, "status": "held"}],
  ///   "report_items": [{"label": "...", "value": "..."}]
  /// }
  static Future<Map<String, dynamic>> getReport(DateTime from, DateTime to) async {
    final token = await _getToken();
    final query = {
      'from': from.toIso8601String().substring(0, 10),
      'to': to.toIso8601String().substring(0, 10),
    };
    final response = await http.get(
      Uri.parse('$baseUrl/reports').replace(queryParameters: query),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response.body, 'Unable to load report'));
    }
    final data = jsonDecode(response.body);
    return Map<String, dynamic>.from(data is Map && data['data'] is Map ? data['data'] : data as Map);
  }

  /// Requests a server-rendered PDF report for the selected date range.
  static Future<List<int>> exportReportPdf(DateTime from, DateTime to) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/reports/export').replace(queryParameters: {
        'from': from.toIso8601String().substring(0, 10),
        'to': to.toIso8601String().substring(0, 10),
        'format': 'pdf',
      }),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/pdf'},
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response.body, 'Unable to export PDF'));
    }
    return response.bodyBytes;
  }

  static String _errorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? (decoded['message']?.toString() ?? fallback) : fallback;
    } catch (_) {
      return fallback;
    }
  }

    // NEW: step 1 of forgot-password — sends a reset code to the user's email.
  // Expects a Laravel route e.g. POST /api/forgot-password { email }
  // that generates a short-lived code (OTP), emails it, and returns
  // { message: '...' } on success (200) or { message: '...' } on failure (4xx).
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message'] ?? 'Code sent'};
    }
    return {'success': false, 'message': data['message'] ?? 'Could not send reset code'};
  }

    // that validates the code (correct + not expired) and updates the password.
  static Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-password'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'password': password,
        'password_confirmation': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message'] ?? 'Password reset'};
    }
    return {'success': false, 'message': data['message'] ?? 'Could not reset password'};
  }

  // NEW: Create a new appointment
  static Future<Map<String, dynamic>> createAppointment({
    required String purpose,
    required String date,
    required String startTime,
    required int durationMinutes,
    required List<String> attendeeEmails,
    required String locationType, // 'physical' or 'online'
    String? location,
    String? zoomLink,
    required List<Map<String, dynamic>> reminders,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/appointments'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'purpose': purpose,
          'appointment_date': date,
          'start_time': startTime,
          'duration_minutes': durationMinutes,
          'attendee_emails': attendeeEmails,
          'location_type': locationType,
          'location': location,
          'zoom_link': zoomLink,
          'reminders': reminders,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'appointment': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to create appointment'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // NEW: Check for time conflicts
  static Future<Map<String, dynamic>> checkTimeConflict(String date, String startTime, int durationMinutes) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/appointments/check-conflict?date=$date&start_time=$startTime&duration_minutes=$durationMinutes'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'conflict': data['conflict'], 'conflictingAppointment': data['conflicting_appointment']};
      }
      return {'success': false, 'message': 'Error checking conflicts'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // NEW: Get list of users for inviting (people to meet)
  static Future<List<dynamic>> searchUsers(String query) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/search?q=$query'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }

  // NEW: Get pending appointment invites for the current user
  static Future<List<dynamic>> getPendingAppointmentInvites() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/appointments/pending-invites'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }

  // NEW: Accept appointment invitation
  static Future<Map<String, dynamic>> acceptAppointmentInvite(int appointmentId) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/appointments/$appointmentId/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Unable to accept invitation'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // NEW: Decline appointment invitation
  static Future<Map<String, dynamic>> declineAppointmentInvite(int appointmentId) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/appointments/$appointmentId/decline'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Unable to decline invitation'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<ReportSummary> getReports(String startDate, String endDate) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/reports?start_date=$startDate&end_date=$endDate'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    return ReportSummary.fromJson(jsonDecode(response.body));
  }
}
