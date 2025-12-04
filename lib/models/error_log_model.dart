import 'package:cloud_firestore/cloud_firestore.dart';

/// Hata Log Sistemi
class ErrorLog {
  final String id;
  final String errorType; // "exception", "warning", "crash", "api_error"
  final String message;
  final String? stackTrace;
  final String? userId;
  final String? userName;
  final String platform; // "ios", "android", "web"
  final String appVersion;
  final String? deviceModel;
  final String? osVersion;
  final DateTime createdAt;
  final String severity; // "low", "medium", "high", "critical"
  final bool isResolved;
  final String? resolution;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final int occurrences;
  final Map<String, dynamic> additionalInfo;

  ErrorLog({
    required this.id,
    required this.errorType,
    required this.message,
    this.stackTrace,
    this.userId,
    this.userName,
    required this.platform,
    required this.appVersion,
    this.deviceModel,
    this.osVersion,
    required this.createdAt,
    required this.severity,
    required this.isResolved,
    this.resolution,
    this.resolvedBy,
    this.resolvedAt,
    required this.occurrences,
    required this.additionalInfo,
  });

  factory ErrorLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ErrorLog(
      id: doc.id,
      errorType: data['errorType'] ?? 'exception',
      message: data['message'] ?? '',
      stackTrace: data['stackTrace'],
      userId: data['userId'],
      userName: data['userName'],
      platform: data['platform'] ?? 'android',
      appVersion: data['appVersion'] ?? '',
      deviceModel: data['deviceModel'],
      osVersion: data['osVersion'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      severity: data['severity'] ?? 'medium',
      isResolved: data['isResolved'] ?? false,
      resolution: data['resolution'],
      resolvedBy: data['resolvedBy'],
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      occurrences: (data['occurrences'] ?? 1).toInt(),
      additionalInfo: Map<String, dynamic>.from(data['additionalInfo'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'errorType': errorType,
      'message': message,
      'stackTrace': stackTrace,
      'userId': userId,
      'userName': userName,
      'platform': platform,
      'appVersion': appVersion,
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'createdAt': Timestamp.fromDate(createdAt),
      'severity': severity,
      'isResolved': isResolved,
      'resolution': resolution,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'occurrences': occurrences,
      'additionalInfo': additionalInfo,
    };
  }

  ErrorLog copyWith({
    String? id,
    String? errorType,
    String? message,
    String? stackTrace,
    String? userId,
    String? userName,
    String? platform,
    String? appVersion,
    String? deviceModel,
    String? osVersion,
    DateTime? createdAt,
    String? severity,
    bool? isResolved,
    String? resolution,
    String? resolvedBy,
    DateTime? resolvedAt,
    int? occurrences,
    Map<String, dynamic>? additionalInfo,
  }) {
    return ErrorLog(
      id: id ?? this.id,
      errorType: errorType ?? this.errorType,
      message: message ?? this.message,
      stackTrace: stackTrace ?? this.stackTrace,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      platform: platform ?? this.platform,
      appVersion: appVersion ?? this.appVersion,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
      createdAt: createdAt ?? this.createdAt,
      severity: severity ?? this.severity,
      isResolved: isResolved ?? this.isResolved,
      resolution: resolution ?? this.resolution,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      occurrences: occurrences ?? this.occurrences,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  /// Hata kritik mi?
  bool get isCritical => severity == 'critical';

  /// Hata raporlanması için hazır mı?
  bool get isReportable => !isResolved && occurrences > 1;
}

/// Hata İstatistikleri
class ErrorStats {
  final String period; // "daily", "weekly", "monthly"
  final int totalErrors;
  final int criticalErrors;
  final int highErrors;
  final int mediumErrors;
  final int lowErrors;
  final int resolvedErrors;
  final DateTime date;

  ErrorStats({
    required this.period,
    required this.totalErrors,
    required this.criticalErrors,
    required this.highErrors,
    required this.mediumErrors,
    required this.lowErrors,
    required this.resolvedErrors,
    required this.date,
  });

  factory ErrorStats.fromMap(Map<String, dynamic> data) {
    return ErrorStats(
      period: data['period'] ?? 'daily',
      totalErrors: (data['totalErrors'] ?? 0).toInt(),
      criticalErrors: (data['criticalErrors'] ?? 0).toInt(),
      highErrors: (data['highErrors'] ?? 0).toInt(),
      mediumErrors: (data['mediumErrors'] ?? 0).toInt(),
      lowErrors: (data['lowErrors'] ?? 0).toInt(),
      resolvedErrors: (data['resolvedErrors'] ?? 0).toInt(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  double get resolutionRate {
    if (totalErrors == 0) return 0;
    return (resolvedErrors / totalErrors) * 100;
  }

  int get unresolvedErrors => totalErrors - resolvedErrors;
}
