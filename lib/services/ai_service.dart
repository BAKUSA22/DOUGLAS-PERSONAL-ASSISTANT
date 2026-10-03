import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/message.dart';
import 'auth_service.dart';

abstract class AiService {
  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
  });
}

class LocalAiService implements AiService {
  final AuthService _authService = AuthService();

  String get _backendUrl => AuthService.backendUrl;

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Your DOUGLAS AI session has expired. Please sign in again.',
      );
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<String>> loadPersonalMemories() async {
    final response = await http
        .get(
          Uri.parse('$_backendUrl/api/personal-memory'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      await _authService.logout();
      throw Exception(
        'Your DOUGLAS AI session has expired. Please sign in again.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'DOUGLAS AI memory service returned HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final memories = data['memories'];

    if (memories is! List) {
      return <String>[];
    }

    return memories
        .whereType<Map<String, dynamic>>()
        .map((item) => (item['memory'] as String?)?.trim() ?? '')
        .where((memory) => memory.isNotEmpty)
        .toList();
  }

  Future<void> addPersonalMemory(String memory) async {
    final text = memory.trim();

    if (text.isEmpty) {
      throw Exception('Memory cannot be empty.');
    }

    final response = await http
        .post(
          Uri.parse('$_backendUrl/api/personal-memory'),
          headers: await _authHeaders(),
          body: jsonEncode({'memory': text}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      await _authService.logout();
      throw Exception(
        'Your DOUGLAS AI session has expired. Please sign in again.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'DOUGLAS AI could not save the memory. HTTP ${response.statusCode}',
      );
    }
  }

  Future<void> clearPersonalMemories() async {
    final response = await http
        .delete(
          Uri.parse('$_backendUrl/api/personal-memory'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      await _authService.logout();
      throw Exception(
        'Your DOUGLAS AI session has expired. Please sign in again.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'DOUGLAS AI could not clear personal memories. HTTP ${response.statusCode}',
      );
    }
  }

  @override
  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    final text = message.trim();

    if (text.isEmpty) {
      return 'Please tell me what you would like me to do.';
    }

    final response = await http
        .post(
          Uri.parse('$_backendUrl/api/chat'),
          headers: await _authHeaders(),
          body: jsonEncode({'message': text}),
        )
        .timeout(const Duration(seconds: 180));

    if (response.statusCode == 401) {
      await _authService.logout();
      throw Exception(
        'Your DOUGLAS AI session has expired. Please sign in again.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'DOUGLAS AI backend returned HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final reply = (data['response'] as String?)?.trim();

    if (reply == null || reply.isEmpty) {
      throw Exception('DOUGLAS AI returned an empty response.');
    }

    return reply;
  }
}
