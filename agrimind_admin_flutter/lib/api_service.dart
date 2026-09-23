import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

class AdminApiService {
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
      if (origin.startsWith('http://') || origin.startsWith('https://')) {
        if (!origin.contains('localhost') && !origin.contains('127.0.0.1')) {
          return '$origin/api';
        }
        if (Uri.base.port == 8000) {
          return '$origin/api';
        }
      }
    }
    return 'http://127.0.0.1:8000/api';
  }

  static Future<DashboardStats> getStats() async {
    final res = await http.get(Uri.parse('$baseUrl/stats')).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('Failed to load stats');
    return DashboardStats.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  static Future<List<RequirementSummary>> getRequirements({
    String? status,
    String? district,
    int skip = 0,
    int limit = 100,
  }) async {
    final uri = Uri.parse('$baseUrl/requirements').replace(queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (district != null && district.isNotEmpty) 'district': district,
      'skip': skip.toString(),
      'limit': limit.toString(),
    });

    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('Failed to load requirements');

    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final items = (data['items'] as List? ?? []);
    return items.map((i) => RequirementSummary.fromJson(Map<String, dynamic>.from(i))).toList();
  }

  static Future<AnalysisResult> analyzeRequirement(int reqId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/requirements/$reqId/analyze'),
    ).timeout(const Duration(seconds: 35));

    if (res.statusCode != 200) throw Exception('Analysis failed: ${res.statusCode}');
    return AnalysisResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  static Future<RequestMissingResult> requestMissingData(int reqId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/requirements/$reqId/request-missing'),
    ).timeout(const Duration(seconds: 25));

    if (res.statusCode != 200) throw Exception('Request missing data failed: ${res.statusCode}');
    return RequestMissingResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  static Future<Map<String, dynamic>> regeneratePdf(int reqId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/requirements/$reqId/regenerate-pdf'),
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) throw Exception('Regenerate PDF failed: ${res.statusCode}');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<void> updateStatus(int reqId, String status, [String? notes]) async {
    final res = await http.post(
      Uri.parse('$baseUrl/requirements/$reqId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'status': status,
        if (notes != null) 'company_notes': notes,
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) throw Exception('Status update failed: ${res.statusCode}');
  }

  static String getPdfUrl(int reqId) {
    return '$baseUrl/requirements/$reqId/pdf';
  }
}
