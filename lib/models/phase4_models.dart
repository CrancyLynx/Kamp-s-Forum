import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// PHASE 4 - ADVANCED FEATURES (7 systems)
// ============================================================

/// 1. Engellenen Kullanıcılar
class BlockedUser {
  final String id;
  final String blockedUserId;
  final String blockerUserId;
  final DateTime blockedAt;
  final String? reason;

  BlockedUser({
    required this.id,
    required this.blockedUserId,
    required this.blockerUserId,
    required this.blockedAt,
    this.reason,
  });

  factory BlockedUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlockedUser(
      id: doc.id,
      blockedUserId: data['blockedUserId'] ?? '',
      blockerUserId: data['blockerUserId'] ?? '',
      blockedAt: (data['blockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: data['reason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'blockedUserId': blockedUserId,
      'blockerUserId': blockerUserId,
      'blockedAt': Timestamp.fromDate(blockedAt),
      'reason': reason,
    };
  }
}

/// 2. Kaydedilmiş Gönderiler
class SavedPost {
  final String id;
  final String userId;
  final String postId;
  final String postType; // "poll", "forum", "news", "chat"
  final String postTitle;
  final String postAuthorId;
  final DateTime savedAt;
  final String? collectionName; // Folder name for saves

  SavedPost({
    required this.id,
    required this.userId,
    required this.postId,
    required this.postType,
    required this.postTitle,
    required this.postAuthorId,
    required this.savedAt,
    this.collectionName,
  });

  factory SavedPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedPost(
      id: doc.id,
      userId: data['userId'] ?? '',
      postId: data['postId'] ?? '',
      postType: data['postType'] ?? 'poll',
      postTitle: data['postTitle'] ?? '',
      postAuthorId: data['postAuthorId'] ?? '',
      savedAt: (data['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      collectionName: data['collectionName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'postId': postId,
      'postType': postType,
      'postTitle': postTitle,
      'postAuthorId': postAuthorId,
      'savedAt': Timestamp.fromDate(savedAt),
      'collectionName': collectionName,
    };
  }
}

/// 3. Değişiklik Talepleri (Feature Requests)
class ChangeRequest {
  final String id;
  final String userId;
  final String userName;
  final String targetType; // "user", "post", "content"
  final String targetId;
  final String changeType; // "edit", "delete", "restore"
  final String reason;
  final Map<String, dynamic> proposedChanges;
  final DateTime createdAt;
  final String status; // "pending", "approved", "rejected"
  final String? reviewedByAdminId;

  ChangeRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.targetType,
    required this.targetId,
    required this.changeType,
    required this.reason,
    required this.proposedChanges,
    required this.createdAt,
    required this.status,
    this.reviewedByAdminId,
  });

  factory ChangeRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChangeRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      targetType: data['targetType'] ?? 'post',
      targetId: data['targetId'] ?? '',
      changeType: data['changeType'] ?? 'edit',
      reason: data['reason'] ?? '',
      proposedChanges: data['proposedChanges'] ?? {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      reviewedByAdminId: data['reviewedByAdminId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'targetType': targetType,
      'targetId': targetId,
      'changeType': changeType,
      'reason': reason,
      'proposedChanges': proposedChanges,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'reviewedByAdminId': reviewedByAdminId,
    };
  }
}

/// 4. Raporlama Sistemi
class ReportComplaint {
  final String id;
  final String reportedByUserId;
  final String reportedUserId;
  final String reportType; // "harassment", "spam", "inappropriate", "fraud", "other"
  final String description;
  final List<String> evidenceUrls;
  final DateTime reportedAt;
  final String status; // "pending", "investigating", "resolved", "dismissed"
  final String? resolution;
  final String? reviewedByAdminId;

  ReportComplaint({
    required this.id,
    required this.reportedByUserId,
    required this.reportedUserId,
    required this.reportType,
    required this.description,
    required this.evidenceUrls,
    required this.reportedAt,
    required this.status,
    this.resolution,
    this.reviewedByAdminId,
  });

  factory ReportComplaint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportComplaint(
      id: doc.id,
      reportedByUserId: data['reportedByUserId'] ?? '',
      reportedUserId: data['reportedUserId'] ?? '',
      reportType: data['reportType'] ?? 'other',
      description: data['description'] ?? '',
      evidenceUrls: List<String>.from(data['evidenceUrls'] ?? []),
      reportedAt: (data['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      resolution: data['resolution'],
      reviewedByAdminId: data['reviewedByAdminId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reportedByUserId': reportedByUserId,
      'reportedUserId': reportedUserId,
      'reportType': reportType,
      'description': description,
      'evidenceUrls': evidenceUrls,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'status': status,
      'resolution': resolution,
      'reviewedByAdminId': reviewedByAdminId,
    };
  }
}

/// 5. Konum İkonları
class LocationIcon {
  final String id;
  final String name;
  final String category; // "university", "library", "cafe", "restaurant", "dorm", "other"
  final String iconUrl;
  final String color;
  final bool isDefault;

  LocationIcon({
    required this.id,
    required this.name,
    required this.category,
    required this.iconUrl,
    required this.color,
    required this.isDefault,
  });

  factory LocationIcon.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationIcon(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'other',
      iconUrl: data['iconUrl'] ?? '',
      color: data['color'] ?? '#000000',
      isDefault: data['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'iconUrl': iconUrl,
      'color': color,
      'isDefault': isDefault,
    };
  }
}

/// 6. Gelişmiş Moderasyon
class AdvancedModeration {
  final String id;
  final String actionType; // "warn", "mute", "kick", "ban", "timeout"
  final String targetUserId;
  final String reason;
  final DateTime appliedAt;
  final DateTime? expiresAt; // null = permanent
  final String appliedByAdminId;
  final bool isActive;

  AdvancedModeration({
    required this.id,
    required this.actionType,
    required this.targetUserId,
    required this.reason,
    required this.appliedAt,
    this.expiresAt,
    required this.appliedByAdminId,
    required this.isActive,
  });

  factory AdvancedModeration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdvancedModeration(
      id: doc.id,
      actionType: data['actionType'] ?? 'warn',
      targetUserId: data['targetUserId'] ?? '',
      reason: data['reason'] ?? '',
      appliedAt: (data['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      appliedByAdminId: data['appliedByAdminId'] ?? '',
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'actionType': actionType,
      'targetUserId': targetUserId,
      'reason': reason,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'appliedByAdminId': appliedByAdminId,
      'isActive': isActive,
    };
  }

  bool isExpired() {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

/// 7. Ring İtiraz Sistemi
class RingComplaint {
  final String id;
  final String ringId;
  final String complainantUserId;
  final String respondentUserId;
  final String complaintType; // "safety", "behavior", "damage", "late", "cancellation"
  final String description;
  final List<String> evidenceUrls;
  final DateTime createdAt;
  final String status; // "pending", "investigating", "resolved", "dismissed"
  final int? compensationRequestedAmount;
  final String? resolution;

  RingComplaint({
    required this.id,
    required this.ringId,
    required this.complainantUserId,
    required this.respondentUserId,
    required this.complaintType,
    required this.description,
    required this.evidenceUrls,
    required this.createdAt,
    required this.status,
    this.compensationRequestedAmount,
    this.resolution,
  });

  factory RingComplaint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RingComplaint(
      id: doc.id,
      ringId: data['ringId'] ?? '',
      complainantUserId: data['complainantUserId'] ?? '',
      respondentUserId: data['respondentUserId'] ?? '',
      complaintType: data['complaintType'] ?? 'behavior',
      description: data['description'] ?? '',
      evidenceUrls: List<String>.from(data['evidenceUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      compensationRequestedAmount: data['compensationRequestedAmount'],
      resolution: data['resolution'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ringId': ringId,
      'complainantUserId': complainantUserId,
      'respondentUserId': respondentUserId,
      'complaintType': complaintType,
      'description': description,
      'evidenceUrls': evidenceUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'compensationRequestedAmount': compensationRequestedAmount,
      'resolution': resolution,
    };
  }
}
