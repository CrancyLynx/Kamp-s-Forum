import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// PHASE 3 - SYSTEM FEATURES (8 systems)
// ============================================================

/// 1. Sınav Takvimi
class ExamCalendarEntry {
  final String id;
  final String courseName;
  final String courseCode;
  final DateTime examDate;
  final String? location;
  final String? professor;
  final String university;
  final String examType; // "midterm", "final", "project"

  ExamCalendarEntry({
    required this.id,
    required this.courseName,
    required this.courseCode,
    required this.examDate,
    this.location,
    this.professor,
    required this.university,
    required this.examType,
  });

  factory ExamCalendarEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamCalendarEntry(
      id: doc.id,
      courseName: data['courseName'] ?? '',
      courseCode: data['courseCode'] ?? '',
      examDate: (data['examDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: data['location'],
      professor: data['professor'],
      university: data['university'] ?? '',
      examType: data['examType'] ?? 'final',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'courseName': courseName,
      'courseCode': courseCode,
      'examDate': Timestamp.fromDate(examDate),
      'location': location,
      'professor': professor,
      'university': university,
      'examType': examType,
    };
  }
}

/// 2. Vision API Quota Management
class VisionApiQuota {
  final String month; // "2025-12"
  final int monthlyLimit;
  final int usedCount;
  final int remainingCount;
  final double costPerImage;
  final DateTime resetDate;

  VisionApiQuota({
    required this.month,
    required this.monthlyLimit,
    required this.usedCount,
    required this.remainingCount,
    required this.costPerImage,
    required this.resetDate,
  });

  factory VisionApiQuota.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisionApiQuota(
      month: doc.id,
      monthlyLimit: (data['monthlyLimit'] ?? 10000).toInt(),
      usedCount: (data['usedCount'] ?? 0).toInt(),
      remainingCount: (data['remainingCount'] ?? 10000).toInt(),
      costPerImage: (data['costPerImage'] ?? 0.0015).toDouble(),
      resetDate: (data['resetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'monthlyLimit': monthlyLimit,
      'usedCount': usedCount,
      'remainingCount': remainingCount,
      'costPerImage': costPerImage,
      'resetDate': Timestamp.fromDate(resetDate),
    };
  }

  double getUsagePercentage() {
    return (usedCount / monthlyLimit) * 100;
  }
}

/// 3. Admin Audit Log
class AuditLog {
  final String id;
  final String adminId;
  final String adminName;
  final String action; // "create", "update", "delete", "ban", "unban"
  final String targetType; // "user", "post", "poll", "room"
  final String targetId;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  AuditLog({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.timestamp,
    required this.details,
  });

  factory AuditLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditLog(
      id: doc.id,
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'] ?? '',
      action: data['action'] ?? '',
      targetType: data['targetType'] ?? '',
      targetId: data['targetId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      details: data['details'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'adminId': adminId,
      'adminName': adminName,
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'timestamp': Timestamp.fromDate(timestamp),
      'details': details,
    };
  }
}

/// 4. Error Log
class ErrorLog {
  final String id;
  final String errorMessage;
  final String stackTrace;
  final String severity; // "low", "medium", "high", "critical"
  final String? userId;
  final DateTime timestamp;
  final String platform; // "ios", "android", "web"
  final Map<String, dynamic> metadata;

  ErrorLog({
    required this.id,
    required this.errorMessage,
    required this.stackTrace,
    required this.severity,
    this.userId,
    required this.timestamp,
    required this.platform,
    required this.metadata,
  });

  factory ErrorLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ErrorLog(
      id: doc.id,
      errorMessage: data['errorMessage'] ?? '',
      stackTrace: data['stackTrace'] ?? '',
      severity: data['severity'] ?? 'low',
      userId: data['userId'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      platform: data['platform'] ?? 'unknown',
      metadata: data['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'errorMessage': errorMessage,
      'stackTrace': stackTrace,
      'severity': severity,
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'platform': platform,
      'metadata': metadata,
    };
  }
}

/// 5. Feedback & Suggestions
class UserFeedback {
  final String id;
  final String userId;
  final String userName;
  final String subject;
  final String message;
  final String category; // "bug", "feature", "ui", "performance", "other"
  final DateTime createdAt;
  final String status; // "open", "reviewing", "responded", "closed"
  final String? response;

  UserFeedback({
    required this.id,
    required this.userId,
    required this.userName,
    required this.subject,
    required this.message,
    required this.category,
    required this.createdAt,
    required this.status,
    this.response,
  });

  factory UserFeedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserFeedback(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      subject: data['subject'] ?? '',
      message: data['message'] ?? '',
      category: data['category'] ?? 'other',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'open',
      response: data['response'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'subject': subject,
      'message': message,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'response': response,
    };
  }
}

/// 6. Ring Photo Approval
class RingPhotoApproval {
  final String id;
  final String ringId;
  final String uploadedByUserId;
  final String photoUrl;
  final DateTime uploadedAt;
  final String status; // "pending", "approved", "rejected"
  final String? rejectionReason;
  final String? approvedByAdminId;

  RingPhotoApproval({
    required this.id,
    required this.ringId,
    required this.uploadedByUserId,
    required this.photoUrl,
    required this.uploadedAt,
    required this.status,
    this.rejectionReason,
    this.approvedByAdminId,
  });

  factory RingPhotoApproval.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RingPhotoApproval(
      id: doc.id,
      ringId: data['ringId'] ?? '',
      uploadedByUserId: data['uploadedByUserId'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      rejectionReason: data['rejectionReason'],
      approvedByAdminId: data['approvedByAdminId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ringId': ringId,
      'uploadedByUserId': uploadedByUserId,
      'photoUrl': photoUrl,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'status': status,
      'rejectionReason': rejectionReason,
      'approvedByAdminId': approvedByAdminId,
    };
  }
}

/// 7. System Bot/User
class SystemBot {
  final String id;
  final String botName;
  final String botAvatarUrl;
  final String role; // "welcome", "announcer", "moderator"
  final bool isActive;
  final List<String> capabilities; // ["send_messages", "moderate", "announce"]

  SystemBot({
    required this.id,
    required this.botName,
    required this.botAvatarUrl,
    required this.role,
    required this.isActive,
    required this.capabilities,
  });

  factory SystemBot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SystemBot(
      id: doc.id,
      botName: data['botName'] ?? 'System Bot',
      botAvatarUrl: data['botAvatarUrl'] ?? '',
      role: data['role'] ?? 'announcer',
      isActive: data['isActive'] ?? true,
      capabilities: List<String>.from(data['capabilities'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'botName': botName,
      'botAvatarUrl': botAvatarUrl,
      'role': role,
      'isActive': isActive,
      'capabilities': capabilities,
    };
  }
}
