import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  // Configurable base URL: can point to localhost:8000 or Render 24/7 cloud URL
  static String baseUrl = 'http://localhost:8000/api';

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
