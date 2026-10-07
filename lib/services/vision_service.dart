import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Stage 5Q: real Douglas visual-understanding service.
///
/// Camera frames are sent to the authenticated backend.
/// The Groq API key never exists inside the Android application.
class DouglasVisionService {
  final AuthService _authService = AuthService();

  bool _ready = false;

  bool get isReady => _ready;

  String get _backendUrl => AuthService.backendUrl;

  Future<void> initialize() async {
    _ready = true;
  }

  Future<Map<String, String>> _authHeaders() async {
    await _authService.ensureGuestSession();

    final token = await _authService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'DOUGLAS AI could not create a guest session for vision.',
      );
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'image/jpeg',
    };
  }

  Future<String> analyzeImage({
    required Uint8List imageBytes,
  }) async {
    if (!_ready) {
      throw StateError(
        'Douglas vision service has not been initialized.',
      );
    }

    if (imageBytes.isEmpty) {
      throw ArgumentError(
        'Douglas vision received an empty camera frame.',
      );
    }

    final response = await http
        .post(
          Uri.parse('$_backendUrl/api/vision'),
          headers: await _authHeaders(),
          body: imageBytes,
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode == 401) {
      await _authService.logout();

      throw Exception(
        'Your DOUGLAS AI session has expired. Please sign in again.',
      );
    }

    if (response.statusCode != 200) {
      String detail =
          'DOUGLAS vision backend returned HTTP ${response.statusCode}.';

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          final serverDetail = decoded['detail'];

          if (serverDetail is String && serverDetail.trim().isNotEmpty) {
            detail = serverDetail.trim();
          }
        }
      } catch (_) {
        // Keep the generic HTTP error.
      }

      throw Exception(detail);
    }

    final body = response.body.trim();

    if (body.isEmpty) {
      throw Exception(
        'DOUGLAS vision returned an empty response.',
      );
    }

    final decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'DOUGLAS vision returned an invalid response.',
      );
    }

    final result = (decoded['response'] as String?)?.trim();

    if (result == null || result.isEmpty) {
      throw Exception(
        'DOUGLAS vision returned no interpretation.',
      );
    }

    return result;
  }

  void dispose() {
    _ready = false;
  }
}
