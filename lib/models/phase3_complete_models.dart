// lib/models/phase3_complete_models.dart
// ============================================================
// PHASE 3 - System & Admin Models
// ============================================================

// ============================================================
// 1. EXAM CALENDAR MODEL
// ============================================================
class ExamCalendar {
  final String id;
  final String courseName;
  final String courseCode;
  final DateTime examDate;
  final String examTime;
  final String location;
  final String building;
  final String classroom;
  final int duration;
  final String instructorName;
  final String examType;

  ExamCalendar({
    required this.id,
    required this.courseName,
    required this.courseCode,
    required this.examDate,
    required this.examTime,
    required this.location,
    required this.building,
    required this.classroom,
    required this.duration,
    required this.instructorName,
    this.examType = 'midterm',
  });

  factory ExamCalendar.fromJson(Map<String, dynamic> json) {
    return ExamCalendar(
      id: json['id'] ?? '',
      courseName: json['courseName'] ?? '',
      courseCode: json['courseCode'] ?? '',
      examDate: DateTime.tryParse(json['examDate'] ?? '') ?? DateTime.now(),
      examTime: json['examTime'] ?? '09:00',
      location: json['location'] ?? '',
      building: json['building'] ?? '',
      classroom: json['classroom'] ?? '',
      duration: json['duration'] ?? 60,
      instructorName: json['instructorName'] ?? '',
      examType: json['examType'] ?? 'midterm',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseName': courseName,
    'courseCode': courseCode,
    'examDate': examDate.toIso8601String(),
    'examTime': examTime,
    'location': location,
    'building': building,
    'classroom': classroom,
    'duration': duration,
    'instructorName': instructorName,
    'examType': examType,
  };
}

// ============================================================
// 2. VISION API QUOTA MODEL
// ============================================================
class VisionQuota {
  final String userId;
  final int monthlyLimit;
  final int usedThisMonth;
  final int remainingQuota;
  final DateTime resetDate;
  final List<String> usageHistory;
  final bool isLimitedUser;

  VisionQuota({
    required this.userId,
    this.monthlyLimit = 100,
    this.usedThisMonth = 0,
    this.remainingQuota = 100,
    required this.resetDate,
    required this.usageHistory,
    this.isLimitedUser = false,
  });

  factory VisionQuota.fromJson(Map<String, dynamic> json) {
    return VisionQuota(
      userId: json['userId'] ?? '',
      monthlyLimit: json['monthlyLimit'] ?? 100,
      usedThisMonth: json['usedThisMonth'] ?? 0,
      remainingQuota: json['remainingQuota'] ?? 100,
      resetDate: DateTime.tryParse(json['resetDate'] ?? '') ?? DateTime.now(),
      usageHistory: List<String>.from(json['usageHistory'] ?? []),
      isLimitedUser: json['isLimitedUser'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'monthlyLimit': monthlyLimit,
    'usedThisMonth': usedThisMonth,
    'remainingQuota': remainingQuota,
    'resetDate': resetDate.toIso8601String(),
    'usageHistory': usageHistory,
    'isLimitedUser': isLimitedUser,
  };
}

// ============================================================
// 3. ADMIN AUDIT LOG MODEL
// ============================================================
class AuditLog {
  final String id;
  final String adminId;
  final String adminName;
  final String action;
  final String targetId;
  final String targetType;
  final String details;
  final DateTime timestamp;
  final String ipAddress;
  final String status;

  AuditLog({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.targetId,
    required this.targetType,
    required this.details,
    required this.timestamp,
    required this.ipAddress,
    this.status = 'completed',
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] ?? '',
      adminId: json['adminId'] ?? '',
      adminName: json['adminName'] ?? 'Admin',
      action: json['action'] ?? '',
      targetId: json['targetId'] ?? '',
      targetType: json['targetType'] ?? '',
      details: json['details'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      ipAddress: json['ipAddress'] ?? '',
      status: json['status'] ?? 'completed',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'adminId': adminId,
    'adminName': adminName,
    'action': action,
    'targetId': targetId,
    'targetType': targetType,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
    'ipAddress': ipAddress,
    'status': status,
  };
}

// ============================================================
// 4. ERROR LOGS MODEL
// ============================================================
class ErrorLog {
  final String id;
  final String errorType;
  final String errorMessage;
  final String stackTrace;
  final String userId;
  final String screenName;
  final DateTime timestamp;
  final String appVersion;
  final String severity;
  final bool isResolved;

  ErrorLog({
    required this.id,
    required this.errorType,
    required this.errorMessage,
    required this.stackTrace,
    required this.userId,
    required this.screenName,
    required this.timestamp,
    required this.appVersion,
    this.severity = 'normal',
    this.isResolved = false,
  });

  factory ErrorLog.fromJson(Map<String, dynamic> json) {
    return ErrorLog(
      id: json['id'] ?? '',
      errorType: json['errorType'] ?? '',
      errorMessage: json['errorMessage'] ?? '',
      stackTrace: json['stackTrace'] ?? '',
      userId: json['userId'] ?? '',
      screenName: json['screenName'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      appVersion: json['appVersion'] ?? '',
      severity: json['severity'] ?? 'normal',
      isResolved: json['isResolved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'errorType': errorType,
    'errorMessage': errorMessage,
    'stackTrace': stackTrace,
    'userId': userId,
    'screenName': screenName,
    'timestamp': timestamp.toIso8601String(),
    'appVersion': appVersion,
    'severity': severity,
    'isResolved': isResolved,
  };
}

// ============================================================
// 5. FEEDBACK MODEL
// ============================================================
class Feedback {
  final String id;
  final String userId;
  final String userName;
  final String feedbackType;
  final String content;
  final List<String> attachmentUrls;
  final DateTime submittedAt;
  final String status;
  final int rating;
  final String category;

  Feedback({
    required this.id,
    required this.userId,
    required this.userName,
    required this.feedbackType,
    required this.content,
    required this.attachmentUrls,
    required this.submittedAt,
    this.status = 'new',
    this.rating = 0,
    this.category = 'general',
  });

  factory Feedback.fromJson(Map<String, dynamic> json) {
    return Feedback(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Bilinmeyen',
      feedbackType: json['feedbackType'] ?? 'suggestion',
      content: json['content'] ?? '',
      attachmentUrls: List<String>.from(json['attachmentUrls'] ?? []),
      submittedAt: DateTime.tryParse(json['submittedAt'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'new',
      rating: json['rating'] ?? 0,
      category: json['category'] ?? 'general',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'feedbackType': feedbackType,
    'content': content,
    'attachmentUrls': attachmentUrls,
    'submittedAt': submittedAt.toIso8601String(),
    'status': status,
    'rating': rating,
    'category': category,
  };
}

// ============================================================
// 6. RING PHOTO APPROVAL MODEL
// ============================================================
class RingPhotoApproval {
  final String id;
  final String universityName;
  final String uploadedByUserId;
  final String uploaderName;
  final String photoStoragePath;
  final DateTime submittedAt;
  final String status;
  final String? approvedByAdminId;
  final DateTime? approvalDate;
  final String? rejectionReason;

  RingPhotoApproval({
    required this.id,
    required this.universityName,
    required this.uploadedByUserId,
    required this.uploaderName,
    required this.photoStoragePath,
    required this.submittedAt,
    this.status = 'pending',
    this.approvedByAdminId,
    this.approvalDate,
    this.rejectionReason,
  });

  factory RingPhotoApproval.fromJson(Map<String, dynamic> json) {
    return RingPhotoApproval(
      id: json['id'] ?? '',
      universityName: json['universityName'] ?? '',
      uploadedByUserId: json['uploadedByUserId'] ?? '',
      uploaderName: json['uploaderName'] ?? '',
      photoStoragePath: json['photoStoragePath'] ?? '',
      submittedAt: DateTime.tryParse(json['submittedAt'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'pending',
      approvedByAdminId: json['approvedByAdminId'],
      approvalDate: json['approvalDate'] != null ? DateTime.tryParse(json['approvalDate']) : null,
      rejectionReason: json['rejectionReason'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'universityName': universityName,
    'uploadedByUserId': uploadedByUserId,
    'uploaderName': uploaderName,
    'photoStoragePath': photoStoragePath,
    'submittedAt': submittedAt.toIso8601String(),
    'status': status,
    'approvedByAdminId': approvedByAdminId,
    'approvalDate': approvalDate?.toIso8601String(),
    'rejectionReason': rejectionReason,
  };
}

// ============================================================
// 7. SYSTEM BOT MODEL
// ============================================================
class SystemBot {
  final String id;
  final String botName;
  final String description;
  final String avatarUrl;
  final List<String> functions;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final int successfulActions;
  final String status;

  SystemBot({
    required this.id,
    required this.botName,
    required this.description,
    required this.avatarUrl,
    required this.functions,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    this.successfulActions = 0,
    this.status = 'active',
  });

  factory SystemBot.fromJson(Map<String, dynamic> json) {
    return SystemBot(
      id: json['id'] ?? '',
      botName: json['botName'] ?? '',
      description: json['description'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      functions: List<String>.from(json['functions'] ?? []),
      isActive: json['isActive'] ?? true,
      createdBy: json['createdBy'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      successfulActions: json['successfulActions'] ?? 0,
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'botName': botName,
    'description': description,
    'avatarUrl': avatarUrl,
    'functions': functions,
    'isActive': isActive,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'successfulActions': successfulActions,
    'status': status,
  };
}
