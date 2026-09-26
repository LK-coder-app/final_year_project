class RequirementSummary {
  final int id;
  final String sessionId;
  final String? farmerName;
  final String? farmerPhone;
  final String? district;
  final String? language;
  final double? landSize;
  final String? landUnit;
  final List<String>? cropTypes;
  final String? waterSource;
  final double? motorHp;
  final String? irrigationType;
  final double? feasibilityScore;
  final String status;
  final int pdfVersion;
  final String? createdAt;
  final String? followUpToken;
  final String? followUpFilledAt;
  final Map<String, dynamic>? lastSubmittedFormData;
  final Map<String, dynamic> extractedSlots;
  final List<Map<String, dynamic>> conflicts;
  final bool pdfDeliveredToFarmer;
  final String? pdfDeliveredAt;
  final bool formSentToAccount;

  RequirementSummary({
    required this.id,
    required this.sessionId,
    this.farmerName,
    this.farmerPhone,
    this.district,
    this.language,
    this.landSize,
    this.landUnit,
    this.cropTypes,
    this.waterSource,
    this.motorHp,
    this.irrigationType,
    this.feasibilityScore,
    required this.status,
    required this.pdfVersion,
    this.createdAt,
    this.followUpToken,
    this.followUpFilledAt,
    this.lastSubmittedFormData,
    required this.extractedSlots,
    required this.conflicts,
    this.pdfDeliveredToFarmer = false,
    this.pdfDeliveredAt,
    this.formSentToAccount = false,
  });

  factory RequirementSummary.fromJson(Map<String, dynamic> j) {
    return RequirementSummary(
      id: j['id'] ?? 0,
      sessionId: j['session_id'] ?? '',
      farmerName: j['farmer_name'],
      farmerPhone: j['farmer_phone'],
      district: j['district'],
      language: j['language'],
      landSize: (j['land_size'] as num?)?.toDouble(),
      landUnit: j['land_unit'],
      cropTypes: (j['crop_types'] as List?)?.map((e) => e.toString()).toList(),
      waterSource: j['water_source'],
      motorHp: (j['motor_hp'] as num?)?.toDouble(),
      irrigationType: j['irrigation_type'],
      feasibilityScore: (j['feasibility_score'] as num?)?.toDouble(),
      status: j['status'] ?? 'pending',
      pdfVersion: j['pdf_version'] ?? 1,
      createdAt: j['created_at'],
      followUpToken: j['follow_up_token'],
      followUpFilledAt: j['follow_up_filled_at'],
      lastSubmittedFormData: j['last_submitted_form_data'] != null
          ? Map<String, dynamic>.from(j['last_submitted_form_data'])
          : null,
      extractedSlots: Map<String, dynamic>.from(j['extracted_slots'] ?? {}),
      conflicts: (j['conflicts'] as List? ?? []).map((c) => Map<String, dynamic>.from(c)).toList(),
      pdfDeliveredToFarmer: j['pdf_delivered_to_farmer'] ?? false,
      pdfDeliveredAt: j['pdf_delivered_at'],
      formSentToAccount: j['form_sent_to_account'] ?? false,
    );
  }
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

  factory DashboardStats.fromJson(Map<String, dynamic> j) {
    return DashboardStats(
      total: j['total_requirements'] ?? 0,
      pending: j['pending'] ?? 0,
      underReview: j['under_review'] ?? 0,
      feasible: j['feasible'] ?? 0,
      quoted: j['quoted'] ?? 0,
      avgScore: (j['avg_feasibility_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AnalysisResult {
  final int requirementId;
  final List<Map<String, dynamic>> presentFields;
  final List<Map<String, dynamic>> missingRequired;
  final List<Map<String, dynamic>> missingOptional;
  final List<Map<String, dynamic>> warnings;
  final String analysisText;

  AnalysisResult({
    required this.requirementId,
    required this.presentFields,
    required this.missingRequired,
    required this.missingOptional,
    required this.warnings,
    required this.analysisText,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> j) {
    return AnalysisResult(
      requirementId: j['requirement_id'] ?? 0,
      presentFields: (j['present_fields'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList(),
      missingRequired: (j['missing_required'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList(),
      missingOptional: (j['missing_optional'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList(),
      warnings: (j['warnings'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList(),
      analysisText: j['analysis_text'] ?? '',
    );
  }
}

class RequestMissingResult {
  final bool success;
  final int requirementId;
  final String followUpToken;
  final String formUrl;
  final bool smsSent;
  final String message;

  RequestMissingResult({
    required this.success,
    required this.requirementId,
    required this.followUpToken,
    required this.formUrl,
    required this.smsSent,
    required this.message,
  });

  factory RequestMissingResult.fromJson(Map<String, dynamic> j) {
    return RequestMissingResult(
      success: j['success'] ?? false,
      requirementId: j['requirement_id'] ?? 0,
      followUpToken: j['follow_up_token'] ?? '',
      formUrl: j['form_url'] ?? '',
      smsSent: j['sms_sent'] ?? false,
      message: j['message'] ?? '',
    );
  }
}

class AdminUser {
  final int id;
  final String email;
  final String? phone;
  final String fullName;
  final String role;
  final bool isActive;

  AdminUser({
    required this.id,
    required this.email,
    this.phone,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: j['id'] ?? 0,
    email: j['email'] ?? '',
    phone: j['phone'],
    fullName: j['full_name'] ?? 'Administrator',
    role: j['role'] ?? 'admin',
    isActive: j['is_active'] ?? true,
  );
}

class AdminAuthResponse {
  final bool success;
  final String accessToken;
  final AdminUser user;
  final String message;

  AdminAuthResponse({
    required this.success,
    required this.accessToken,
    required this.user,
    required this.message,
  });

  factory AdminAuthResponse.fromJson(Map<String, dynamic> j) => AdminAuthResponse(
    success: j['success'] ?? false,
    accessToken: j['access_token'] ?? '',
    user: AdminUser.fromJson(j['user'] ?? {}),
    message: j['message'] ?? '',
  );
}

class FarmerAccount {
  final int id;
  final String email;
  final String? phone;
  final String fullName;
  final String role;
  final String? firebaseUid;
  final bool isActive;
  final String? createdAt;
  final String? lastLogin;

  FarmerAccount({
    required this.id,
    required this.email,
    this.phone,
    required this.fullName,
    required this.role,
    this.firebaseUid,
    required this.isActive,
    this.createdAt,
    this.lastLogin,
  });

  factory FarmerAccount.fromJson(Map<String, dynamic> j) => FarmerAccount(
    id: j['id'] ?? 0,
    email: j['email'] ?? '',
    phone: j['phone'],
    fullName: j['full_name'] ?? 'Farmer',
    role: j['role'] ?? 'farmer',
    firebaseUid: j['firebase_uid'],
    isActive: j['is_active'] ?? true,
    createdAt: j['created_at'],
    lastLogin: j['last_login'],
  );
}
