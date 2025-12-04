import 'package:cloud_firestore/cloud_firestore.dart';

/// İçerik Filtresi Ayarları
class ContentFilter {
  final String id;
  final String filterType; // "keyword", "pattern", "regex"
  final String filterValue;
  final String category; // "spam", "hate_speech", "explicit", "other"
  final int severity; // 1-5
  final String action; // "block", "flag", "warn"
  final bool isActive;
  final DateTime createdAt;
  final List<String> exceptions; // İstisnalar (user id'leri)

  ContentFilter({
    required this.id,
    required this.filterType,
    required this.filterValue,
    required this.category,
    required this.severity,
    required this.action,
    required this.isActive,
    required this.createdAt,
    required this.exceptions,
  });

  factory ContentFilter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContentFilter(
      id: doc.id,
      filterType: data['filterType'] ?? 'keyword',
      filterValue: data['filterValue'] ?? '',
      category: data['category'] ?? 'spam',
      severity: (data['severity'] ?? 1).toInt(),
      action: data['action'] ?? 'flag',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      exceptions: List<String>.from(data['exceptions'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'filterType': filterType,
      'filterValue': filterValue,
      'category': category,
      'severity': severity,
      'action': action,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'exceptions': exceptions,
    };
  }

  bool shouldApplyToUser(String userId) {
    return !exceptions.contains(userId) && isActive;
  }
}

/// İçerik Kontrolü Sonucu
class ContentCheckResult {
  final bool passed;
  final List<String> violatedFilters;
  final String highestSeverity;
  final String recommendedAction;
  final String violationReason;

  ContentCheckResult({
    required this.passed,
    required this.violatedFilters,
    required this.highestSeverity,
    required this.recommendedAction,
    required this.violationReason,
  });

  factory ContentCheckResult.clean() {
    return ContentCheckResult(
      passed: true,
      violatedFilters: [],
      highestSeverity: 'none',
      recommendedAction: 'none',
      violationReason: '',
    );
  }

  factory ContentCheckResult.violation({
    required List<String> violatedFilters,
    required int maxSeverity,
    required String reason,
  }) {
    final severityMap = {5: 'critical', 4: 'high', 3: 'medium', 2: 'low', 1: 'minimal'};
    final actionMap = {5: 'block', 4: 'flag', 3: 'warn', 2: 'warn', 1: 'monitor'};

    return ContentCheckResult(
      passed: false,
      violatedFilters: violatedFilters,
      highestSeverity: severityMap[maxSeverity] ?? 'unknown',
      recommendedAction: actionMap[maxSeverity] ?? 'review',
      violationReason: reason,
    );
  }

  bool isCritical() {
    return highestSeverity == 'critical' || highestSeverity == 'high';
  }
}

/// İçerik Uyarısı
class ContentWarning {
  final String id;
  final String userId;
  final String contentId;
  final String contentType; // "message", "post", "comment"
  final String reason;
  final DateTime createdAt;
  final String status; // "active", "acknowledged", "expired"
  final bool isAutomatic;

  ContentWarning({
    required this.id,
    required this.userId,
    required this.contentId,
    required this.contentType,
    required this.reason,
    required this.createdAt,
    required this.status,
    required this.isAutomatic,
  });

  factory ContentWarning.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContentWarning(
      id: doc.id,
      userId: data['userId'] ?? '',
      contentId: data['contentId'] ?? '',
      contentType: data['contentType'] ?? 'message',
      reason: data['reason'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'active',
      isAutomatic: data['isAutomatic'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'contentId': contentId,
      'contentType': contentType,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'isAutomatic': isAutomatic,
    };
  }

  bool isExpired() {
    return DateTime.now().difference(createdAt).inDays > 30;
  }
}

/// Otomatik İçerik Raporlama
class AutomaticContentReport {
  final String id;
  final String contentId;
  final String contentType;
  final String detectionType; // "spam", "hate_speech", "explicit"
  final double confidenceScore; // 0-1
  final String detectedBy; // "keyword_filter", "pattern_match", "model_detection"
  final DateTime createdAt;
  final bool reviewed;

  AutomaticContentReport({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.detectionType,
    required this.confidenceScore,
    required this.detectedBy,
    required this.createdAt,
    required this.reviewed,
  });

  factory AutomaticContentReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AutomaticContentReport(
      id: doc.id,
      contentId: data['contentId'] ?? '',
      contentType: data['contentType'] ?? '',
      detectionType: data['detectionType'] ?? '',
      confidenceScore: (data['confidenceScore'] ?? 0.0).toDouble(),
      detectedBy: data['detectedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewed: data['reviewed'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'contentId': contentId,
      'contentType': contentType,
      'detectionType': detectionType,
      'confidenceScore': confidenceScore,
      'detectedBy': detectedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewed': reviewed,
    };
  }

  bool isHighConfidence() {
    return confidenceScore >= 0.8;
  }
}
