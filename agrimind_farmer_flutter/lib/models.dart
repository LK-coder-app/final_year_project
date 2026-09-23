class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ConflictItem {
  final String type;
  final String severity;
  final String message;
  final String recommendation;

  ConflictItem({
    required this.type,
    required this.severity,
    required this.message,
    required this.recommendation,
  });

  factory ConflictItem.fromJson(Map<String, dynamic> json) => ConflictItem(
    type: json['type'] ?? '',
    severity: json['severity'] ?? 'medium',
    message: json['message'] ?? '',
    recommendation: json['recommendation'] ?? '',
  );
}

class ChatResponse {
  final String sessionId;
  final String reply;
  final String languageDetected;
  final Map<String, dynamic> extractedSlots;
  final List<String> missingSlots;
  final List<ConflictItem> conflicts;
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
    conflicts: (j['conflicts'] as List? ?? [])
        .map((c) => ConflictItem.fromJson(Map<String, dynamic>.from(c)))
        .toList(),
    completionPct: (j['completion_pct'] ?? 0).toDouble(),
    isComplete: j['is_complete'] ?? false,
    turnIndex: j['turn_index'] ?? 0,
  );
}

class SubmitResult {
  final bool success;
  final int requirementId;
  final String sessionId;
  final String message;
  final double feasibilityScore;
  final int conflictsCount;
  final bool pdfAvailable;

  SubmitResult({
    required this.success,
    required this.requirementId,
    required this.sessionId,
    required this.message,
    required this.feasibilityScore,
    required this.conflictsCount,
    required this.pdfAvailable,
  });

  factory SubmitResult.fromJson(Map<String, dynamic> j) => SubmitResult(
    success: j['success'] ?? false,
    requirementId: j['requirement_id'] ?? 0,
    sessionId: j['session_id'] ?? '',
    message: j['message'] ?? '',
    feasibilityScore: (j['feasibility_score'] ?? 0).toDouble(),
    conflictsCount: j['conflicts_count'] ?? 0,
    pdfAvailable: j['pdf_available'] ?? false,
  );
}

class AuthUser {
  final int id;
  final String email;
  final String? phone;
  final String fullName;
  final String role;
  final bool isActive;

  AuthUser({
    required this.id,
    required this.email,
    this.phone,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] ?? 0,
    email: j['email'] ?? '',
    phone: j['phone'],
    fullName: j['full_name'] ?? 'Farmer',
    role: j['role'] ?? 'farmer',
    isActive: j['is_active'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'phone': phone,
    'full_name': fullName,
    'role': role,
    'is_active': isActive,
  };
}

class AuthResponse {
  final bool success;
  final String accessToken;
  final AuthUser user;
  final String message;

  AuthResponse({
    required this.success,
    required this.accessToken,
    required this.user,
    required this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
    success: j['success'] ?? false,
    accessToken: j['access_token'] ?? '',
    user: AuthUser.fromJson(j['user'] ?? {}),
    message: j['message'] ?? '',
  );
}
