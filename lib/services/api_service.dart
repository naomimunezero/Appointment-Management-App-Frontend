import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Replace with YOUR PC's actual local IP from ipconfig
  static const String baseUrl = 'http://192.168.100.181:8000/api';

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
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      await _saveToken(data['token']);
      await _saveUserName(data['user']?['name']); // NEW
      return {'success': true, 'user': data['user']};
    }
    return {'success': false, 'message': data['message'] ?? 'Registration failed'};
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await _saveToken(data['token']);
      await _saveUserName(data['user']?['name']); // NEW
      return {'success': true, 'user': data['user']};
    }
    return {'success': false, 'message': data['message'] ?? 'Login failed'};
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
}