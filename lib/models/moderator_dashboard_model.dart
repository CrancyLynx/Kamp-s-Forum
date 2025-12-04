import 'package:cloud_firestore/cloud_firestore.dart';

/// Moderatör Dashboard Sistemi
class ModeratorDashboard {
  final String id;
  final String moderatorId;
  final String moderatorName;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final bool isActive;
  final String role; // "moderator", "admin", "super_admin"
  final List<String> assignedRooms; // Sorumlu chat rooms
  final ModeratorStats stats;

  ModeratorDashboard({
    required this.id,
    required this.moderatorId,
    required this.moderatorName,
    required this.createdAt,
    this.lastActiveAt,
    required this.isActive,
    required this.role,
    required this.assignedRooms,
    required this.stats,
  });

  factory ModeratorDashboard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final statsMap = data['stats'] as Map<String, dynamic>?;
    return ModeratorDashboard(
      id: doc.id,
      moderatorId: data['moderatorId'] ?? '',
      moderatorName: data['moderatorName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
      role: data['role'] ?? 'moderator',
      assignedRooms: List<String>.from(data['assignedRooms'] ?? []),
      stats: statsMap != null
          ? ModeratorStats.fromMap(statsMap)
          : ModeratorStats(
              reviewedMessages: 0,
              approvedMessages: 0,
              rejectedMessages: 0,
              bannedUsers: 0,
              warningsIssued: 0,
              averageReviewTime: 0,
            ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'moderatorId': moderatorId,
      'moderatorName': moderatorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'isActive': isActive,
      'role': role,
      'assignedRooms': assignedRooms,
      'stats': stats.toMap(),
    };
  }

  ModeratorDashboard copyWith({
    String? id,
    String? moderatorId,
    String? moderatorName,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? isActive,
    String? role,
    List<String>? assignedRooms,
    ModeratorStats? stats,
  }) {
    return ModeratorDashboard(
      id: id ?? this.id,
      moderatorId: moderatorId ?? this.moderatorId,
      moderatorName: moderatorName ?? this.moderatorName,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isActive: isActive ?? this.isActive,
      role: role ?? this.role,
      assignedRooms: assignedRooms ?? this.assignedRooms,
      stats: stats ?? this.stats,
    );
  }
}

/// Moderatör İstatistikleri
class ModeratorStats {
  final int reviewedMessages;
  final int approvedMessages;
  final int rejectedMessages;
  final int bannedUsers;
  final int warningsIssued;
  final int averageReviewTime; // Saniyeler

  ModeratorStats({
    required this.reviewedMessages,
    required this.approvedMessages,
    required this.rejectedMessages,
    required this.bannedUsers,
    required this.warningsIssued,
    required this.averageReviewTime,
  });

  factory ModeratorStats.fromMap(Map<String, dynamic> data) {
    return ModeratorStats(
      reviewedMessages: (data['reviewedMessages'] ?? 0).toInt(),
      approvedMessages: (data['approvedMessages'] ?? 0).toInt(),
      rejectedMessages: (data['rejectedMessages'] ?? 0).toInt(),
      bannedUsers: (data['bannedUsers'] ?? 0).toInt(),
      warningsIssued: (data['warningsIssued'] ?? 0).toInt(),
      averageReviewTime: (data['averageReviewTime'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reviewedMessages': reviewedMessages,
      'approvedMessages': approvedMessages,
      'rejectedMessages': rejectedMessages,
      'bannedUsers': bannedUsers,
      'warningsIssued': warningsIssued,
      'averageReviewTime': averageReviewTime,
    };
  }

  double get approvalRate {
    if (reviewedMessages == 0) return 0;
    return (approvedMessages / reviewedMessages) * 100;
  }

  ModeratorStats copyWith({
    int? reviewedMessages,
    int? approvedMessages,
    int? rejectedMessages,
    int? bannedUsers,
    int? warningsIssued,
    int? averageReviewTime,
  }) {
    return ModeratorStats(
      reviewedMessages: reviewedMessages ?? this.reviewedMessages,
      approvedMessages: approvedMessages ?? this.approvedMessages,
      rejectedMessages: rejectedMessages ?? this.rejectedMessages,
      bannedUsers: bannedUsers ?? this.bannedUsers,
      warningsIssued: warningsIssued ?? this.warningsIssued,
      averageReviewTime: averageReviewTime ?? this.averageReviewTime,
    );
  }
}

/// Moderatör Log
class ModeratorLog {
  final String id;
  final String moderatorId;
  final String action; // "approved", "rejected", "banned", "warned", "edited"
  final String targetId;
  final String targetType; // "message", "user", "post"
  final String? reason;
  final DateTime createdAt;
  final Map<String, dynamic> details;

  ModeratorLog({
    required this.id,
    required this.moderatorId,
    required this.action,
    required this.targetId,
    required this.targetType,
    this.reason,
    required this.createdAt,
    required this.details,
  });

  factory ModeratorLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ModeratorLog(
      id: doc.id,
      moderatorId: data['moderatorId'] ?? '',
      action: data['action'] ?? '',
      targetId: data['targetId'] ?? '',
      targetType: data['targetType'] ?? '',
      reason: data['reason'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      details: Map<String, dynamic>.from(data['details'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'moderatorId': moderatorId,
      'action': action,
      'targetId': targetId,
      'targetType': targetType,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
      'details': details,
    };
  }
}
