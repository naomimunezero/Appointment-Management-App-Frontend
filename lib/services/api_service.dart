import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_summary.dart';
import '../models/app_user.dart';
import '../models/appointment.dart';

class ApiService {

  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // NEW: saves the user's name at the same time we save the token,
  static Future<void> _saveUserName(String? name) async {
    if (name == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
  }

  static Future<void> _saveUserPermissions(dynamic user) async {
    if (user is! Map) return;
    final prefs = await SharedPreferences.getInstance();
    final role = user['role'];
    await prefs.setStringList(
      'user_permissions',
      user['permissions'] is List
          ? (user['permissions'] as List).map((value) => value.toString()).toList()
          : <String>[],
    );
    await prefs.setBool(
      'user_is_owner',
      role is Map && role['name']?.toString().toLowerCase() == 'owner',
    );
  }

  static Future<bool> hasPermission(String permission) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('user_is_owner') == true ||
        (prefs.getStringList('user_permissions') ?? const <String>[]).contains(permission);
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
    await prefs.remove('user_permissions');
    await prefs.remove('user_is_owner');
  }

  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      print('REGISTER ATTEMPT - URL: $baseUrl/register');
      print('REGISTER ATTEMPT - Email: $email, Name: $name');

      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      print('REGISTER RESPONSE - Status: ${response.statusCode}');
      print('REGISTER RESPONSE - Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _saveToken(data['token']);
        await _saveUserName(data['user']?['name']); // NEW
        await _saveUserPermissions(data['user']);
        return {'success': true, 'user': AppUser.fromJson(data['user'])};
      }
      return {'success': false, 'message': data['message'] ?? 'Registration failed'};
    } catch (e) {
      print('REGISTER ERROR: $e');
      print('REGISTER ERROR TYPE: ${e.runtimeType}');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('LOGIN ATTEMPT - URL: $baseUrl/login');
      print('LOGIN ATTEMPT - Email: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      print('LOGIN RESPONSE - Status: ${response.statusCode}');
      print('LOGIN RESPONSE - Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveToken(data['token']);
        await _saveUserName(data['user']?['name']);
        await _saveUserPermissions(data['user']);
        return {
          'success': true,
          'user': AppUser.fromJson(data['user']),
          'pendingInvites': data['pendingInvites'] ?? const [],
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      print('LOGIN ERROR: $e');
      print('LOGIN ERROR TYPE: ${e.runtimeType}');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> inviteAssistant(String email, List<String> permissions,{String? name}) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/assistant-invites'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'email': email,'name': name, 'permissions': permissions}),
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

  /// Returns the current owner's assistant invitation or assistant record.
  static Future<Map<String, dynamic>> getAssistantAccess() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/assistant-invites'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body);
      if (response.statusCode != 200) {
        return {'success': false, 'message': 'Unable to load assistant details.'};
      }
      final data = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
      dynamic assistant = data['assistant'] ?? data['invite'];
      final invites = decoded is List ? decoded : (data['invites'] ?? data['data']);
      if (assistant == null && data['data'] is Map) assistant = data['data'];
      if (assistant == null && invites is List) {
        final records = invites.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
        records.sort((a, b) =>
            (int.tryParse(b['id']?.toString() ?? '') ?? 0)
                .compareTo(int.tryParse(a['id']?.toString() ?? '') ?? 0));
        if (records.isNotEmpty) assistant = records.first;
      }
      if (assistant is Map) assistant = Map<String, dynamic>.from(assistant);
      return {'success': true, 'assistant': assistant};
    } catch (e) {
      return {'success': false, 'message': 'Unable to load assistant details: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateAssistantPermissions(int inviteId, List<String> permissions) async {
    try {
      final token = await _getToken();
      final response = await http.patch(
        Uri.parse('$baseUrl/assistant-invites/$inviteId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'permissions': permissions}),
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, if (data is Map) ...Map<String, dynamic>.from(data)};
      }
      return {'success': false, 'message': data is Map ? data['message'] ?? 'Unable to update permissions.' : 'Unable to update permissions.'};
    } catch (e) {
      return {'success': false, 'message': 'Unable to update permissions: $e'};
    }
  }

  static Future<Map<String, dynamic>> acceptAssistantInvite({required int inviteId}) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/assistant-invites/$inviteId/accept'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    final data = jsonDecode(response.body);
    return response.statusCode == 200 ? {'success': true, ...data} : {'success': false, 'message': data['message']};
  }

  static Future<Map<String, dynamic>> declineAssistantInvite({required int inviteId}) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/assistant-invites/$inviteId/decline'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    final data = jsonDecode(response.body);
    return response.statusCode == 200 ? {'success': true, ...data} : {'success': false, 'message': data['message']};
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
    try {
      final token = await _getToken();
      print('GET NOTIFICATIONS - Token exists: ${token != null && token.isNotEmpty}');

      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      print('NOTIFICATIONS STATUS: ${response.statusCode}');
      print('NOTIFICATIONS BODY: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('DECODED NOTIFICATIONS TYPE: ${decoded.runtimeType}');
        print('DECODED NOTIFICATIONS: $decoded');
        return decoded;
      }

      print('NON-200 STATUS CODE: ${response.statusCode}');
      return [];
    } catch (e) {
      print('NOTIFICATIONS ERROR: $e');
      return [];
    }
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
    required List<Map<String, String>> attendees,
    required String locationType, // 'physical' or 'online'
    String? location,
    String? onlineLink,
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
          'attendees': attendees,
          'location_type': locationType,
          'location': location,
          'online_link': onlineLink,
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

  static Future<Map<String, dynamic>> updateAppointment({
    required int appointmentId,
    required String auditAction,
    required String purpose,
    required String date,
    required String startTime,
    required int durationMinutes,
    required String location,
    String? locationType,
    String? onlineLink,
    required List<Map<String, String>> attendees,
    required List<Map<String, dynamic>> reminders,
  }) async {
    try {
      final token = await _getToken();

      // Debug: Print request data
      print('UPDATE APPOINTMENT - Request data:');
      print('  Appointment ID: $appointmentId');
      print('  Purpose: $purpose');
      print('  Date: $date');
      print('  Start Time: $startTime');
      print('  Duration: $durationMinutes');
      print('  Location: $location');
      print('  Location Type: $locationType');
      print('  Online Link: $onlineLink');
      print('  Attendees count: ${attendees.length}');
      print('  Reminders count: ${reminders.length}');
      print('  Reminders: $reminders');

      final response = await http.put(
        Uri.parse('$baseUrl/appointments/$appointmentId'),
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
          'location': location,
          'location_type': locationType,
          'online_link': onlineLink,
          'attendees': attendees,
          'reminders': reminders,
          'audit_action': auditAction,
        }),
      ).timeout(const Duration(seconds: 10));

      print('UPDATE APPOINTMENT - Response status: ${response.statusCode}');
      print('UPDATE APPOINTMENT - Response body: ${response.body}');

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'appointment': data};
      }
      return {
        'success': false,
        'message': _apiErrorMessage(data, 'Failed to update appointment'),
      };
    } catch (e) {
      print('UPDATE APPOINTMENT - Error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static String _apiErrorMessage(dynamic data, String fallback) {
    if (data is! Map) return fallback;

    final errors = data['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value != null && value.toString().isNotEmpty) return value.toString();
      }
    }

    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message;
    return fallback;
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

  static Future<List<dynamic>> getAppointmentHistory(int id) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/appointments/$id/history'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
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

  // Get detailed appointment info
  static Future<Appointment> getAppointmentDetails(int appointmentId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/appointments/$appointmentId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Appointment.fromJson(data);
      }
      throw Exception('Failed to load appointment details');
    } catch (e) {
      throw Exception('Error loading appointment: ${e.toString()}');
    }
  }

  // Record appointment outcome
  static Future<Map<String, dynamic>> recordAppointmentOutcome(int appointmentId, {
    String? discussionNotes,
    List<Map<String, dynamic>>? actionPoints,
    List<Map<String, String>>? attendees,
  }) async {
    final token = await _getToken();
    
    // Debug: Print what's being sent
    print('API - RECORD OUTCOME:');
    print('  Appointment ID: $appointmentId');
    print('  Attendees: $attendees');
    print('  Attendees count: ${attendees?.length ?? 0}');
    
    final payload = {
      'discussion_notes': discussionNotes,
      'action_points': actionPoints,
      'attendees': attendees,
      'status': 'held',
    };

    final attempts = [
      {
        'method': 'PUT',
        'url': '$baseUrl/appointments/$appointmentId/outcome',
        'body': payload,
      },
      {
        'method': 'POST',
        'url': '$baseUrl/appointments/$appointmentId/record-outcome',
        'body': payload,
      },
      {
        'method': 'POST',
        'url': '$baseUrl/appointments/$appointmentId/mark-held',
        'body': {'status': 'held'},
      },
      {
        'method': 'POST',
        'url': '$baseUrl/appointments/$appointmentId/hold',
        'body': {'status': 'held'},
      },
      {
        'method': 'PUT',
        'url': '$baseUrl/appointments/$appointmentId',
        'body': {'status': 'held', 'discussion_notes': discussionNotes, 'attendees': attendees},
      },
    ];

    Object? lastError;
    for (final attempt in attempts) {
      try {
        final method = attempt['method'] as String;
        final url = attempt['url'] as String;
        final body = attempt['body'] as Map<String, dynamic>;

        final response = method == 'PUT'
            ? await http.put(
                Uri.parse(url),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode(body),
              ).timeout(const Duration(seconds: 10))
            : await http.post(
                Uri.parse(url),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode(body),
              ).timeout(const Duration(seconds: 10));

        final raw = response.body.trim();
        final data = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);

        if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
          return {'success': true, 'data': data, 'status': 'held'};
        }

        if (response.statusCode == 404) {
          continue;
        }

        return {
          'success': false,
          'message': data is Map ? (data['message'] ?? 'Failed to record outcome') : 'Failed to record outcome',
        };
      } catch (e) {
        lastError = e;
      }
    }

    return {
      'success': false,
      'message': lastError != null
          ? 'Network error: ${lastError.toString()}'
          : 'The appointment could not be marked as held on the server.',
    };
  }

  // Update action point completion status
  static Future<Map<String, dynamic>> updateActionPointStatus(int actionPointId, bool completed) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/action-points/$actionPointId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': completed ? 'done' : 'pending'}),
      ).timeout(const Duration(seconds: 10));

      final rawBody = response.body.trim();
      final data = rawBody.isEmpty ? <String, dynamic>{} : jsonDecode(rawBody);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data is Map ? (data['message'] ?? 'Failed to update action point') : 'Failed to update action point',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Delete action point
  static Future<Map<String, dynamic>> deleteActionPoint(int actionPointId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/action-points/$actionPointId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final rawBody = response.body.trim();
      final data = rawBody.isEmpty ? <String, dynamic>{} : jsonDecode(rawBody);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data is Map ? (data['message'] ?? 'Failed to delete action point') : 'Failed to delete action point',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Update action point details
  static Future<Map<String, dynamic>> updateActionPoint(
    int actionPointId,
    String description,
    String? responsiblePerson,
    String? dueDate,
  ) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/action-points/$actionPointId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'description': description,
          'responsible_person': responsiblePerson,
          'due_date': dueDate,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to update action point'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }
}
