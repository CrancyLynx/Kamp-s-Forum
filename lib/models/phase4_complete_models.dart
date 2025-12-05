// lib/models/phase4_complete_models.dart
// ============================================================
// PHASE 4 - Advanced System Models
// ============================================================

// ============================================================
// 1. ADVANCED CACHE ENTRY MODEL
// ============================================================
class CacheEntry {
  final String id;
  final String dataType;
  final dynamic cachedData;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int hitCount;
  final String priority;
  final bool isCompressed;

  CacheEntry({
    required this.id,
    required this.dataType,
    required this.cachedData,
    required this.createdAt,
    required this.expiresAt,
    this.hitCount = 0,
    this.priority = 'normal',
    this.isCompressed = false,
  });

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      id: json['id'] ?? '',
      dataType: json['dataType'] ?? '',
      cachedData: json['cachedData'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expiresAt'] ?? '') ?? DateTime.now(),
      hitCount: json['hitCount'] ?? 0,
      priority: json['priority'] ?? 'normal',
      isCompressed: json['isCompressed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dataType': dataType,
    'cachedData': cachedData,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'hitCount': hitCount,
    'priority': priority,
    'isCompressed': isCompressed,
  };

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

// ============================================================
// 2. AI RECOMMENDATION MODEL
// ============================================================
class AIRecommendation {
  final String id;
  final String userId;
  final String recommendationType;
  final String targetId;
  final String targetTitle;
  final double confidenceScore;
  final String reason;
  final DateTime generatedAt;
  final bool userAccepted;

  AIRecommendation({
    required this.id,
    required this.userId,
    required this.recommendationType,
    required this.targetId,
    required this.targetTitle,
    required this.confidenceScore,
    required this.reason,
    required this.generatedAt,
    this.userAccepted = false,
  });

  factory AIRecommendation.fromJson(Map<String, dynamic> json) {
    return AIRecommendation(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      recommendationType: json['recommendationType'] ?? '',
      targetId: json['targetId'] ?? '',
      targetTitle: json['targetTitle'] ?? '',
      confidenceScore: (json['confidenceScore'] ?? 0.0).toDouble(),
      reason: json['reason'] ?? '',
      generatedAt: DateTime.tryParse(json['generatedAt'] ?? '') ?? DateTime.now(),
      userAccepted: json['userAccepted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'recommendationType': recommendationType,
    'targetId': targetId,
    'targetTitle': targetTitle,
    'confidenceScore': confidenceScore,
    'reason': reason,
    'generatedAt': generatedAt.toIso8601String(),
    'userAccepted': userAccepted,
  };
}

// ============================================================
// 3. ANALYTICS EVENT MODEL
// ============================================================
class AnalyticsEvent {
  final String id;
  final String userId;
  final String eventName;
  final String screenName;
  final Map<String, dynamic> eventData;
  final DateTime timestamp;
  final String deviceId;
  final String appVersion;

  AnalyticsEvent({
    required this.id,
    required this.userId,
    required this.eventName,
    required this.screenName,
    required this.eventData,
    required this.timestamp,
    required this.deviceId,
    required this.appVersion,
  });

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      eventName: json['eventName'] ?? '',
      screenName: json['screenName'] ?? '',
      eventData: Map<String, dynamic>.from(json['eventData'] ?? {}),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      deviceId: json['deviceId'] ?? '',
      appVersion: json['appVersion'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'eventName': eventName,
    'screenName': screenName,
    'eventData': eventData,
    'timestamp': timestamp.toIso8601String(),
    'deviceId': deviceId,
    'appVersion': appVersion,
  };
}

// ============================================================
// 4. USER ENGAGEMENT METRIC MODEL
// ============================================================
class UserEngagementMetric {
  final String userId;
  final int totalVisits;
  final int postCount;
  final int commentCount;
  final int likeCount;
  final double engagementScore;
  final DateTime lastActiveAt;
  final List<String> preferredCategories;
  final String userSegment;

  UserEngagementMetric({
    required this.userId,
    this.totalVisits = 0,
    this.postCount = 0,
    this.commentCount = 0,
    this.likeCount = 0,
    this.engagementScore = 0.0,
    required this.lastActiveAt,
    required this.preferredCategories,
    this.userSegment = 'casual',
  });

  factory UserEngagementMetric.fromJson(Map<String, dynamic> json) {
    return UserEngagementMetric(
      userId: json['userId'] ?? '',
      totalVisits: json['totalVisits'] ?? 0,
      postCount: json['postCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      likeCount: json['likeCount'] ?? 0,
      engagementScore: (json['engagementScore'] ?? 0.0).toDouble(),
      lastActiveAt: DateTime.tryParse(json['lastActiveAt'] ?? '') ?? DateTime.now(),
      preferredCategories: List<String>.from(json['preferredCategories'] ?? []),
      userSegment: json['userSegment'] ?? 'casual',
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'totalVisits': totalVisits,
    'postCount': postCount,
    'commentCount': commentCount,
    'likeCount': likeCount,
    'engagementScore': engagementScore,
    'lastActiveAt': lastActiveAt.toIso8601String(),
    'preferredCategories': preferredCategories,
    'userSegment': userSegment,
  };
}

// ============================================================
// 5. SYSTEM PERFORMANCE METRIC MODEL
// ============================================================
class SystemPerformanceMetric {
  final String id;
  final DateTime timestamp;
  final double cpuUsage;
  final double memoryUsage;
  final double storageUsage;
  final int activeUsers;
  final double apiResponseTime;
  final int errorCount;
  final int requestsPerSecond;

  SystemPerformanceMetric({
    required this.id,
    required this.timestamp,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.storageUsage,
    required this.activeUsers,
    required this.apiResponseTime,
    required this.errorCount,
    required this.requestsPerSecond,
  });

  factory SystemPerformanceMetric.fromJson(Map<String, dynamic> json) {
    return SystemPerformanceMetric(
      id: json['id'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      cpuUsage: (json['cpuUsage'] ?? 0.0).toDouble(),
      memoryUsage: (json['memoryUsage'] ?? 0.0).toDouble(),
      storageUsage: (json['storageUsage'] ?? 0.0).toDouble(),
      activeUsers: json['activeUsers'] ?? 0,
      apiResponseTime: (json['apiResponseTime'] ?? 0.0).toDouble(),
      errorCount: json['errorCount'] ?? 0,
      requestsPerSecond: json['requestsPerSecond'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'cpuUsage': cpuUsage,
    'memoryUsage': memoryUsage,
    'storageUsage': storageUsage,
    'activeUsers': activeUsers,
    'apiResponseTime': apiResponseTime,
    'errorCount': errorCount,
    'requestsPerSecond': requestsPerSecond,
  };
}

// ============================================================
// 6. SECURITY ALERT MODEL
// ============================================================
class SecurityAlert {
  final String id;
  final String alertType;
  final String severity;
  final String description;
  final String targetUserId;
  final String? suspiciousActivityDetails;
  final DateTime detectedAt;
  final bool isResolved;
  final String? resolutionNotes;

  SecurityAlert({
    required this.id,
    required this.alertType,
    required this.severity,
    required this.description,
    required this.targetUserId,
    this.suspiciousActivityDetails,
    required this.detectedAt,
    this.isResolved = false,
    this.resolutionNotes,
  });

  factory SecurityAlert.fromJson(Map<String, dynamic> json) {
    return SecurityAlert(
      id: json['id'] ?? '',
      alertType: json['alertType'] ?? '',
      severity: json['severity'] ?? 'medium',
      description: json['description'] ?? '',
      targetUserId: json['targetUserId'] ?? '',
      suspiciousActivityDetails: json['suspiciousActivityDetails'],
      detectedAt: DateTime.tryParse(json['detectedAt'] ?? '') ?? DateTime.now(),
      isResolved: json['isResolved'] ?? false,
      resolutionNotes: json['resolutionNotes'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'alertType': alertType,
    'severity': severity,
    'description': description,
    'targetUserId': targetUserId,
    'suspiciousActivityDetails': suspiciousActivityDetails,
    'detectedAt': detectedAt.toIso8601String(),
    'isResolved': isResolved,
    'resolutionNotes': resolutionNotes,
  };
}

// ============================================================
// 7. CONTENT MODERATION QUEUE MODEL
// ============================================================
class ModerationQueueItem {
  final String id;
  final String contentId;
  final String contentType;
  final String contentPreview;
  final String submittedByUserId;
  final String reportReason;
  final List<String> reportedByUserIds;
  final DateTime submittedAt;
  final String status;
  final String? moderatorNotes;
  final String? decision;

  ModerationQueueItem({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.contentPreview,
    required this.submittedByUserId,
    required this.reportReason,
    required this.reportedByUserIds,
    required this.submittedAt,
    this.status = 'pending',
    this.moderatorNotes,
    this.decision,
  });

  factory ModerationQueueItem.fromJson(Map<String, dynamic> json) {
    return ModerationQueueItem(
      id: json['id'] ?? '',
      contentId: json['contentId'] ?? '',
      contentType: json['contentType'] ?? '',
      contentPreview: json['contentPreview'] ?? '',
      submittedByUserId: json['submittedByUserId'] ?? '',
      reportReason: json['reportReason'] ?? '',
      reportedByUserIds: List<String>.from(json['reportedByUserIds'] ?? []),
      submittedAt: DateTime.tryParse(json['submittedAt'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'pending',
      moderatorNotes: json['moderatorNotes'],
      decision: json['decision'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'contentId': contentId,
    'contentType': contentType,
    'contentPreview': contentPreview,
    'submittedByUserId': submittedByUserId,
    'reportReason': reportReason,
    'reportedByUserIds': reportedByUserIds,
    'submittedAt': submittedAt.toIso8601String(),
    'status': status,
    'moderatorNotes': moderatorNotes,
    'decision': decision,
  };
}
