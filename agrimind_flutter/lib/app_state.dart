// ═══════════════════════════════════════════════════════════════════
// AgriMind — App State Provider
// ═══════════════════════════════════════════════════════════════════
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  final DateTime timestamp;
  ChatMessage({required this.role, required this.text})
      : timestamp = DateTime.now();
}

class AppState extends ChangeNotifier {
  // ── Session ───────────────────────────────────────────────────────
  String _sessionId = _genId();
  String get sessionId => _sessionId;

  // ── Chat ──────────────────────────────────────────────────────────
  final List<ChatMessage> messages = [];
  Map<String, dynamic> slots = {};
  List<Map<String, dynamic>> conflicts = [];
  double completionPct = 0;
  bool isComplete = false;
  bool isSending = false;
  String detectedLanguage = 'english';

  // ── LLM ───────────────────────────────────────────────────────────
  String llmProvider = 'local';

  // ── Dashboard ─────────────────────────────────────────────────────
  DashboardStats? stats;
  List<Requirement> requirements = [];
  bool dashboardLoading = false;
  String dashboardError = '';

  // ── Server ────────────────────────────────────────────────────────
  bool serverOnline = false;

  static String _genId() {
    final r = Random();
    final suffix = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
    return 'agm-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-$suffix';
  }

  // ────────────────────────────────────────────────────────────────
  // Init
  // ────────────────────────────────────────────────────────────────
  Future<void> init() async {
    serverOnline = await ApiService.checkHealth();
    notifyListeners();
    if (serverOnline) {
      try {
        final cfg = await ApiService.getLLMConfig();
        llmProvider = cfg['provider'] ?? 'local';
      } catch (_) {}
    }
    _addWelcome();
  }

  void _addWelcome() {
    messages.add(ChatMessage(
      role: 'assistant',
      text:
          'Welcome to AgriMind!\n\n'
          'I can understand Tamil, English, and Tanglish.\n'
          'Tell me about your farm — land area, crops, water source, motor HP, and irrigation needs — '
          'and I will help you create a verified requirement report.\n\n'
          'Try one of the quick prompts below or type naturally!',
    ));
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────
  // Chat
  // ────────────────────────────────────────────────────────────────
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || isSending) return;
    messages.add(ChatMessage(role: 'user', text: text.trim()));
    isSending = true;
    notifyListeners();

    try {
      final resp = await ApiService.chat(
        sessionId: _sessionId,
        message: text.trim(),
        llmProvider: llmProvider,
      );

      messages.add(ChatMessage(role: 'assistant', text: resp.reply));
      slots = resp.extractedSlots;
      conflicts = resp.conflicts;
      completionPct = resp.completionPct;
      isComplete = resp.isComplete;
      detectedLanguage = resp.languageDetected;
    } catch (e) {
      messages.add(ChatMessage(
        role: 'assistant',
        text: 'Connection error: ${e.toString().substring(0, e.toString().length.clamp(0, 120))}\n\n'
              'Make sure the AgriMind server is running on http://localhost:8000',
      ));
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> submitRequirement({
    required String name,
    String? phone,
  }) async {
    try {
      final result = await ApiService.submit(
        sessionId: _sessionId,
        farmerName: name,
        farmerPhone: phone,
      );
      messages.add(ChatMessage(
        role: 'assistant',
        text: 'Requirement submitted successfully!\n'
              'Report ID: AGM-${result['requirement_id'].toString().padLeft(4, '0')}\n'
              'Feasibility Score: ${result['feasibility_score']}/100\n'
              'Our team will contact you within 24 hours.',
      ));
      notifyListeners();
      return result;
    } catch (e) {
      return null;
    }
  }

  void startNewChat() {
    _sessionId = _genId();
    messages.clear();
    slots = {};
    conflicts = [];
    completionPct = 0;
    isComplete = false;
    detectedLanguage = 'english';
    _addWelcome();
  }

  // ────────────────────────────────────────────────────────────────
  // Dashboard
  // ────────────────────────────────────────────────────────────────
  Future<void> loadDashboard() async {
    dashboardLoading = true;
    dashboardError = '';
    notifyListeners();
    try {
      final results = await Future.wait([
        ApiService.getStats(),
        ApiService.getRequirements(),
      ]);
      stats = results[0] as DashboardStats;
      requirements = results[1] as List<Requirement>;
      serverOnline = true;
    } catch (e) {
      dashboardError = 'Could not load data. Is the server running?';
      serverOnline = false;
    } finally {
      dashboardLoading = false;
      notifyListeners();
    }
  }

  // ────────────────────────────────────────────────────────────────
  // LLM Config
  // ────────────────────────────────────────────────────────────────
  Future<void> setLLMProvider(String provider, {String? apiKey, String? model}) async {
    await ApiService.setLLMConfig(provider, apiKey: apiKey, model: model);
    llmProvider = provider;
    notifyListeners();
  }
}
