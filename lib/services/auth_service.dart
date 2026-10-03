import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://172.17.100.13:8000',
  );

  static const String _tokenKey = 'douglas_ai_access_token';
  static const String _usernameKey = 'douglas_ai_username';
  static const String _userIdKey = 'douglas_ai_user_id';

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$backendUrl/api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username.trim(), 'password': password}),
        )
        .timeout(const Duration(seconds: 30));

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception((data['detail'] ?? 'Registration failed.').toString());
    }

    await _saveSession(data);
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$backendUrl/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username.trim(), 'password': password}),
        )
        .timeout(const Duration(seconds: 30));

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception((data['detail'] ?? 'Login failed.').toString());
    }

    await _saveSession(data);
    return data;
  }

  Future<Map<String, dynamic>?> currentUser() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    final response = await http
        .get(
          Uri.parse('$backendUrl/api/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      await logout();
      return null;
    }

    final data = _decode(response);

    if (response.statusCode != 200) {
      throw Exception(
        (data['detail'] ?? 'Could not verify session.').toString(),
      );
    }

    return data;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_userIdKey);
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final token = data['access_token']?.toString();
    final username = data['username']?.toString();
    final userId = data['user_id'];

    if (token == null || token.isEmpty) {
      throw Exception('Authentication server returned no access token.');
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_tokenKey, token);

    if (username != null && username.isNotEmpty) {
      await prefs.setString(_usernameKey, username);
    }

    if (userId is int) {
      await prefs.setInt(_userIdKey, userId);
    } else if (userId is num) {
      await prefs.setInt(_userIdKey, userId.toInt());
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {'detail': response.body};
    } catch (_) {
      return {
        'detail': response.body.isEmpty
            ? 'The server returned an invalid response.'
            : response.body,
      };
    }
  }
}
