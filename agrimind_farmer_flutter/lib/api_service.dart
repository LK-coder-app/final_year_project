import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  static String? _customBaseUrl;

  static void setBaseUrl(String url) {
    _customBaseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (kIsWeb) {
      final origin = Uri.base.origin;
      // If hosted on Render (e.g. https://xxx.onrender.com) or any remote domain or port 8000
      if (origin.startsWith('http://') || origin.startsWith('https://')) {
        if (!origin.contains('localhost') && !origin.contains('127.0.0.1')) {
          return '$origin/api';
        }
        if (Uri.base.port == 8000) {
          return '$origin/api';
        }
      }
    }
    // Fallback for local development (127.0.0.1 is more reliable on Windows than localhost)
    return 'http://127.0.0.1:8000/api';
  }

  static AuthUser? currentUser;
  static String? authToken;

  static bool get isAuthenticated => currentUser != null;

  static void logout() {
    currentUser = null;
    authToken = null;
  }

  static Future<AuthResponse> loginFarmer(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/farmer/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw Exception(err['detail'] ?? 'Login failed (${res.statusCode})');
    }

    final authRes = AuthResponse.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    currentUser = authRes.user;
    authToken = authRes.accessToken;
    return authRes;
  }

  static Future<AuthResponse> registerFarmer({
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/farmer/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw Exception(err['detail'] ?? 'Registration failed (${res.statusCode})');
    }

    final authRes = AuthResponse.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    currentUser = authRes.user;
    authToken = authRes.accessToken;
    return authRes;
  }

  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {'status': 'error'};
  }

  static Future<ChatResponse> sendChat({
    required String sessionId,
    required String message,
    String language = 'auto',
    String? llmProvider,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'message': message,
        'language': language,
        if (llmProvider != null) 'llm_provider': llmProvider,
      }),
    ).timeout(const Duration(seconds: 35));

    if (res.statusCode != 200) {
      throw Exception('Server error: ${res.statusCode} ${res.body}');
    }

    return ChatResponse.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  static Future<SubmitResult> submitRequirement({
    required String sessionId,
    required String farmerName,
    String? farmerPhone,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/requirements/submit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'farmer_name': farmerName,
        'farmer_phone': farmerPhone,
        'confirm': true,
      }),
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('Submit error: ${res.statusCode} ${res.body}');
    }

    return SubmitResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  static Future<Map<String, dynamic>> getFormByToken(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/form/$token'),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Invalid or expired token (${res.statusCode})');
    }

    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<Map<String, dynamic>> fillMissingData({
    required int reqId,
    required String token,
    required Map<String, dynamic> filledData,
  }) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/requirements/$reqId/fill-missing'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'filled_data': filledData,
      }),
    ).timeout(const Duration(seconds: 25));

    if (res.statusCode != 200) {
      throw Exception('Failed to update: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static String getPdfUrl(int reqId) {
    return '$baseUrl/requirements/$reqId/pdf';
  }
}
