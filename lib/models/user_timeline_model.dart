import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcı Zaman Çizelgesi - Sistem seviyesinde kullanıcı hareketlerini takip eder
class UserTimeline {
  final String id;
  final String userId;
  final String eventType; // "login", "logout", "post_created", "badge_earned", "level_up", "purchase"
  final String title;
  final String? description;
  final String? relatedItemId;
  final String? relatedItemType;
  final DateTime createdAt;
  final String deviceType; // "ios", "android", "web"
  final String? ipAddress;
  final String? location;
  final String? deviceModel;
  final int duration; // Oturum süresi (saniyeler)
  final Map<String, dynamic> metadata;

  UserTimeline({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.title,
    this.description,
    this.relatedItemId,
    this.relatedItemType,
    required this.createdAt,
    required this.deviceType,
    this.ipAddress,
    this.location,
    this.deviceModel,
    required this.duration,
    required this.metadata,
  });

  factory UserTimeline.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserTimeline(
      id: doc.id,
      userId: data['userId'] ?? '',
      eventType: data['eventType'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      relatedItemId: data['relatedItemId'],
      relatedItemType: data['relatedItemType'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deviceType: data['deviceType'] ?? 'android',
      ipAddress: data['ipAddress'],
      location: data['location'],
      deviceModel: data['deviceModel'],
      duration: (data['duration'] ?? 0).toInt(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'eventType': eventType,
      'title': title,
      'description': description,
      'relatedItemId': relatedItemId,
      'relatedItemType': relatedItemType,
      'createdAt': Timestamp.fromDate(createdAt),
      'deviceType': deviceType,
      'ipAddress': ipAddress,
      'location': location,
      'deviceModel': deviceModel,
      'duration': duration,
      'metadata': metadata,
    };
  }

  UserTimeline copyWith({
    String? id,
    String? userId,
    String? eventType,
    String? title,
    String? description,
    String? relatedItemId,
    String? relatedItemType,
    DateTime? createdAt,
    String? deviceType,
    String? ipAddress,
    String? location,
    String? deviceModel,
    int? duration,
    Map<String, dynamic>? metadata,
  }) {
    return UserTimeline(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventType: eventType ?? this.eventType,
      title: title ?? this.title,
      description: description ?? this.description,
      relatedItemId: relatedItemId ?? this.relatedItemId,
      relatedItemType: relatedItemType ?? this.relatedItemType,
      createdAt: createdAt ?? this.createdAt,
      deviceType: deviceType ?? this.deviceType,
      ipAddress: ipAddress ?? this.ipAddress,
      location: location ?? this.location,
      deviceModel: deviceModel ?? this.deviceModel,
      duration: duration ?? this.duration,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Oturum Bilgisi
class UserSession {
  final String id;
  final String userId;
  final DateTime loginAt;
  final DateTime? logoutAt;
  final String deviceType;
  final String? deviceModel;
  final String? deviceId;
  final String? ipAddress;
  final String? location;
  final bool isActive;
  final String appVersion;
  final int activityCount;
  final List<String> activityLog;

  UserSession({
    required this.id,
    required this.userId,
    required this.loginAt,
    this.logoutAt,
    required this.deviceType,
    this.deviceModel,
    this.deviceId,
    this.ipAddress,
    this.location,
    required this.isActive,
    required this.appVersion,
    required this.activityCount,
    required this.activityLog,
  });

  factory UserSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserSession(
      id: doc.id,
      userId: data['userId'] ?? '',
      loginAt: (data['loginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      logoutAt: (data['logoutAt'] as Timestamp?)?.toDate(),
      deviceType: data['deviceType'] ?? 'android',
      deviceModel: data['deviceModel'],
      deviceId: data['deviceId'],
      ipAddress: data['ipAddress'],
      location: data['location'],
      isActive: data['isActive'] ?? true,
      appVersion: data['appVersion'] ?? '',
      activityCount: (data['activityCount'] ?? 0).toInt(),
      activityLog: List<String>.from(data['activityLog'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'loginAt': Timestamp.fromDate(loginAt),
      'logoutAt': logoutAt != null ? Timestamp.fromDate(logoutAt!) : null,
      'deviceType': deviceType,
      'deviceModel': deviceModel,
      'deviceId': deviceId,
      'ipAddress': ipAddress,
      'location': location,
      'isActive': isActive,
      'appVersion': appVersion,
      'activityCount': activityCount,
      'activityLog': activityLog,
    };
  }

  Duration get sessionDuration {
    final endTime = logoutAt ?? DateTime.now();
    return endTime.difference(loginAt);
  }

  int get sessionMinutes => sessionDuration.inMinutes;
}

/// Kullanıcı İstatistikleri
class UserTimelineStats {
  final String userId;
  final int totalLogins;
  final int totalLogouts;
  final Duration totalScreenTime;
  final int totalActions;
  final DateTime lastLoginDate;
  final DateTime? lastLogoutDate;
  final List<String> deviceTypes;
  final List<String> locations;
  final double averageSessionDuration;

  UserTimelineStats({
    required this.userId,
    required this.totalLogins,
    required this.totalLogouts,
    required this.totalScreenTime,
    required this.totalActions,
    required this.lastLoginDate,
    this.lastLogoutDate,
    required this.deviceTypes,
    required this.locations,
    required this.averageSessionDuration,
  });

  factory UserTimelineStats.fromMap(Map<String, dynamic> data) {
    return UserTimelineStats(
      userId: data['userId'] ?? '',
      totalLogins: (data['totalLogins'] ?? 0).toInt(),
      totalLogouts: (data['totalLogouts'] ?? 0).toInt(),
      totalScreenTime: Duration(seconds: (data['totalScreenTime'] ?? 0).toInt()),
      totalActions: (data['totalActions'] ?? 0).toInt(),
      lastLoginDate: (data['lastLoginDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogoutDate: (data['lastLogoutDate'] as Timestamp?)?.toDate(),
      deviceTypes: List<String>.from(data['deviceTypes'] ?? []),
      locations: List<String>.from(data['locations'] ?? []),
      averageSessionDuration: (data['averageSessionDuration'] ?? 0.0).toDouble(),
    );
  }

  bool get isActiveUser => DateTime.now().difference(lastLoginDate).inDays < 7;
}
