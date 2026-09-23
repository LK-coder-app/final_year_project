// ═══════════════════════════════════════════════════════════════════
// AgriMind — API Service & Data Models
// ═══════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Config ──────────────────────────────────────────────────────
const String kApiBase = 'http://localhost:8000/api';

// ─── Models ──────────────────────────────────────────────────────

class ChatResponse {
  final String sessionId;
  final String reply;
  final String languageDetected;
  final Map<String, dynamic> extractedSlots;
  final List<String> missingSlots;
  final List<Map<String, dynamic>> conflicts;
  final double completionPct;
  final bool isComplete;
  final int turnIndex;

  ChatResponse({
    required this.sessionId,
    required this.reply,
    required this.languageDetected,
    required this.extractedSlots,
    required this.missingSlots,
    required this.conflicts,
    required this.completionPct,
    required this.isComplete,
    required this.turnIndex,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> j) => ChatResponse(
    sessionId: j['session_id'] ?? '',
    reply: j['reply'] ?? '',
    languageDetected: j['language_detected'] ?? 'english',
    extractedSlots: Map<String, dynamic>.from(j['extracted_slots'] ?? {}),
    missingSlots: List<String>.from(j['missing_slots'] ?? []),
    conflicts: List<Map<String, dynamic>>.from(j['conflicts'] ?? []),
    completionPct: (j['completion_pct'] ?? 0).toDouble(),
    isComplete: j['is_complete'] ?? false,
    turnIndex: j['turn_index'] ?? 0,
  );
}

class Requirement {
  final int id;
  final String sessionId;
  final String? farmerName;
  final String? farmerPhone;
  final String? district;
  final String? language;
  final double? landSize;
  final String? landUnit;
  final List<String>? cropTypes;
  final String? soilType;
  final String? waterSource;
  final double? borewellDepthFt;
  final double? motorHp;
  final String? powerSupplyPhase;
  final double? powerHoursPerDay;
  final String? irrigationType;
  final double? budgetInr;
  final List<dynamic>? conflicts;
  final double? feasibilityScore;
  final Map<String, dynamic>? feasibilityDetails;
  final String? status;
  final String? createdAt;

  Requirement({
    required this.id,
    required this.sessionId,
    this.farmerName,
    this.farmerPhone,
    this.district,
    this.language,
    this.landSize,
    this.landUnit,
    this.cropTypes,
    this.soilType,
    this.waterSource,
    this.borewellDepthFt,
    this.motorHp,
    this.powerSupplyPhase,
    this.powerHoursPerDay,
    this.irrigationType,
    this.budgetInr,
    this.conflicts,
    this.feasibilityScore,
    this.feasibilityDetails,
    this.status,
    this.createdAt,
  });

  factory Requirement.fromJson(Map<String, dynamic> j) => Requirement(
    id: j['id'],
    sessionId: j['session_id'] ?? '',
    farmerName: j['farmer_name'],
    farmerPhone: j['farmer_phone'],
    district: j['district'],
    language: j['language'],
    landSize: (j['land_size'] as num?)?.toDouble(),
    landUnit: j['land_unit'],
    cropTypes: j['crop_types'] != null ? List<String>.from(j['crop_types']) : null,
    soilType: j['soil_type'],
    waterSource: j['water_source'],
    borewellDepthFt: (j['borewell_depth_ft'] as num?)?.toDouble(),
    motorHp: (j['motor_hp'] as num?)?.toDouble(),
    powerSupplyPhase: j['power_supply_phase'],
    powerHoursPerDay: (j['power_hours_per_day'] as num?)?.toDouble(),
    irrigationType: j['irrigation_type'],
    budgetInr: (j['budget_inr'] as num?)?.toDouble(),
    conflicts: j['conflicts'],
    feasibilityScore: (j['feasibility_score'] as num?)?.toDouble(),
    feasibilityDetails: j['feasibility_details'] != null
        ? Map<String, dynamic>.from(j['feasibility_details'])
        : null,
    status: j['status'],
    createdAt: j['created_at'],
  );

  String get statusLabel => (status ?? 'pending').replaceAll('_', ' ');
  String get cropsLabel => cropTypes?.join(', ') ?? 'N/A';
  String get landLabel => landSize != null ? '${landSize} ${landUnit ?? "acres"}' : 'N/A';
  int get conflictCount => conflicts?.length ?? 0;
}

class DashboardStats {
  final int total;
  final int pending;
  final int underReview;
  final int feasible;
  final int quoted;
  final double avgScore;

  DashboardStats({
    required this.total,
    required this.pending,
    required this.underReview,
    required this.feasible,
    required this.quoted,
    required this.avgScore,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
    total: j['total_requirements'] ?? 0,
    pending: j['pending'] ?? 0,
    underReview: j['under_review'] ?? 0,
    feasible: j['feasible'] ?? 0,
    quoted: j['quoted'] ?? 0,
    avgScore: (j['avg_feasibility_score'] ?? 0).toDouble(),
  );
}

// ─── API Service ─────────────────────────────────────────────────

class ApiService {
  static final _client = http.Client();

  static Future<ChatResponse> chat({
    required String sessionId,
    required String message,
    String llmProvider = 'local',
  }) async {
    final resp = await _client.post(
      Uri.parse('$kApiBase/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'message': message,
        'language': 'auto',
        'llm_provider': llmProvider,
      }),
    ).timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) throw Exception('Chat API error ${resp.statusCode}');
    return ChatResponse.fromJson(jsonDecode(resp.body));
  }

  static Future<Map<String, dynamic>> submit({
    required String sessionId,
    required String farmerName,
    String? farmerPhone,
  }) async {
    final resp = await _client.post(
      Uri.parse('$kApiBase/requirements/submit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'farmer_name': farmerName,
        'farmer_phone': farmerPhone,
        'confirm': true,
      }),
    ).timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) throw Exception('Submit error ${resp.statusCode}');
    return jsonDecode(resp.body);
  }

  static Future<DashboardStats> getStats() async {
    final resp = await _client
        .get(Uri.parse('$kApiBase/stats'))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Stats error');
    return DashboardStats.fromJson(jsonDecode(resp.body));
  }

  static Future<List<Requirement>> getRequirements({String? status}) async {
    final uri = Uri.parse('$kApiBase/requirements').replace(
      queryParameters: {if (status != null && status.isNotEmpty) 'status': status, 'limit': '100'},
    );
    final resp = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Requirements error');
    final data = jsonDecode(resp.body);
    return (data['items'] as List).map((e) => Requirement.fromJson(e)).toList();
  }

  static Future<Requirement> getRequirement(int id) async {
    final resp = await _client
        .get(Uri.parse('$kApiBase/requirements/$id'))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Requirement $id not found');
    return Requirement.fromJson(jsonDecode(resp.body));
  }

  static Future<void> updateStatus(int id, String status, {String? notes}) async {
    await _client.post(
      Uri.parse('$kApiBase/requirements/$id/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status, 'company_notes': notes}),
    );
  }

  static Future<Map<String, dynamic>> getLLMConfig() async {
    final resp = await _client
        .get(Uri.parse('$kApiBase/config/llm'))
        .timeout(const Duration(seconds: 5));
    return jsonDecode(resp.body);
  }

  static Future<void> setLLMConfig(String provider, {String? apiKey, String? model}) async {
    await _client.post(
      Uri.parse('$kApiBase/config/llm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'provider': provider, 'api_key': apiKey, 'model': model}),
    );
  }

  static String getPdfUrl(int id) => '$kApiBase/requirements/$id/pdf';

  static Future<bool> checkHealth() async {
    try {
      final resp = await _client
          .get(Uri.parse('$kApiBase/health'))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
