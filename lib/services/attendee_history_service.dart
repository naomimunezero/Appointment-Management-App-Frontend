import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AttendeeHistoryService {
  static const _key = 'attendee_history';

  static Future<List<Map<String, String>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, String>.from(e)).toList();
  }

  static Future<void> save(String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getAll();

    current.removeWhere((a) => a['email']?.toLowerCase() == email.toLowerCase());
    current.insert(0, {'name': name, 'email': email});

    final trimmed = current.take(30).toList(); // keep the list small
    await prefs.setString(_key, jsonEncode(trimmed));
  }

  static Future<List<Map<String, String>>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final all = await getAll();
    final q = query.toLowerCase();
    return all.where((a) {
      final name = (a['name'] ?? '').toLowerCase();
      final email = (a['email'] ?? '').toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }
}