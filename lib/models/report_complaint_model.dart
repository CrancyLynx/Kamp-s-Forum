import 'package:cloud_firestore/cloud_firestore.dart';

/// Şikayet / Rapor Sistemi
class Report {
  final String id;
  final String reporterId;
  final String reporterName;
  final String targetType; // "user", "post", "comment", "chatroom"
  final String targetId;
  final String targetAuthorId;
  final String targetAuthorName;
  final String reason; // "harassment", "spam", "inappropriate", "fraud", "other"
  final String description;
  final List<String> evidenceUrls;
  final DateTime reportedAt;
  final String status; // "new", "under_review", "resolved", "dismissed", "forwarded"
  final int priority; // 1-5
  final String? investigatorId;
  final String? investigatorName;
  final DateTime? investigationStartedAt;
  final String? resolution;
  final DateTime? resolvedAt;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  Report({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.targetType,
    required this.targetId,
    required this.targetAuthorId,
    required this.targetAuthorName,
    required this.reason,
    required this.description,
    required this.evidenceUrls,
    required this.reportedAt,
    required this.status,
    required this.priority,
    this.investigatorId,
    this.investigatorName,
    this.investigationStartedAt,
    this.resolution,
    this.resolvedAt,
    required this.tags,
    required this.metadata,
  });

  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Report(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? '',
      targetType: data['targetType'] ?? '',
      targetId: data['targetId'] ?? '',
      targetAuthorId: data['targetAuthorId'] ?? '',
      targetAuthorName: data['targetAuthorName'] ?? '',
      reason: data['reason'] ?? '',
      description: data['description'] ?? '',
      evidenceUrls: List<String>.from(data['evidenceUrls'] ?? []),
      reportedAt: (data['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'new',
      priority: (data['priority'] ?? 1).toInt(),
      investigatorId: data['investigatorId'],
      investigatorName: data['investigatorName'],
      investigationStartedAt: (data['investigationStartedAt'] as Timestamp?)?.toDate(),
      resolution: data['resolution'],
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      tags: List<String>.from(data['tags'] ?? []),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reporterName': reporterName,
      'targetType': targetType,
      'targetId': targetId,
      'targetAuthorId': targetAuthorId,
      'targetAuthorName': targetAuthorName,
      'reason': reason,
      'description': description,
      'evidenceUrls': evidenceUrls,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'status': status,
      'priority': priority,
      'investigatorId': investigatorId,
      'investigatorName': investigatorName,
      'investigationStartedAt': investigationStartedAt != null ? Timestamp.fromDate(investigationStartedAt!) : null,
      'resolution': resolution,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'tags': tags,
      'metadata': metadata,
    };
  }

  Report copyWith({
    String? id,
    String? reporterId,
    String? reporterName,
    String? targetType,
    String? targetId,
    String? targetAuthorId,
    String? targetAuthorName,
    String? reason,
    String? description,
    List<String>? evidenceUrls,
    DateTime? reportedAt,
    String? status,
    int? priority,
    String? investigatorId,
    String? investigatorName,
    DateTime? investigationStartedAt,
    String? resolution,
    DateTime? resolvedAt,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return Report(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      targetAuthorId: targetAuthorId ?? this.targetAuthorId,
      targetAuthorName: targetAuthorName ?? this.targetAuthorName,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      evidenceUrls: evidenceUrls ?? this.evidenceUrls,
      reportedAt: reportedAt ?? this.reportedAt,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      investigatorId: investigatorId ?? this.investigatorId,
      investigatorName: investigatorName ?? this.investigatorName,
      investigationStartedAt: investigationStartedAt ?? this.investigationStartedAt,
      resolution: resolution ?? this.resolution,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Acil mi?
  bool get isUrgent => priority >= 4;

  /// İnceleme yapılıyor mu?
  bool get isUnderReview => status == 'under_review';

  /// Çözüldü mü?
  bool get isResolved => status == 'resolved';
}

/// Şikayet İstatistikleri
class ReportStatistics {
  final int totalReports;
  final int urgentReports;
  final int resolvedReports;
  final int underReviewReports;
  final Map<String, int> reportsByReason;
  final Map<String, int> reportsByTargetType;
  final double averageResolutionTime;
  final DateTime period;

  ReportStatistics({
    required this.totalReports,
    required this.urgentReports,
    required this.resolvedReports,
    required this.underReviewReports,
    required this.reportsByReason,
    required this.reportsByTargetType,
    required this.averageResolutionTime,
    required this.period,
  });

  factory ReportStatistics.fromMap(Map<String, dynamic> data) {
    return ReportStatistics(
      totalReports: (data['totalReports'] ?? 0).toInt(),
      urgentReports: (data['urgentReports'] ?? 0).toInt(),
      resolvedReports: (data['resolvedReports'] ?? 0).toInt(),
      underReviewReports: (data['underReviewReports'] ?? 0).toInt(),
      reportsByReason: Map<String, int>.from(data['reportsByReason'] ?? {}),
      reportsByTargetType: Map<String, int>.from(data['reportsByTargetType'] ?? {}),
      averageResolutionTime: (data['averageResolutionTime'] ?? 0.0).toDouble(),
      period: (data['period'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  double get resolutionRate {
    if (totalReports == 0) return 0;
    return (resolvedReports / totalReports) * 100;
  }

  int get pendingReports => totalReports - resolvedReports;
}
