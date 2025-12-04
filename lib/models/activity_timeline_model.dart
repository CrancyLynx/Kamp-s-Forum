import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcı Aktivite Zaman Çizelgesi
class ActivityTimeline {
  final String id;
  final String userId;
  final String activityType; // "post", "comment", "badge_earned", "level_up", "achievement", "joined", "liked"
  final String title;
  final String? description;
  final String? targetId; // İlgili post, comment vs. ID
  final String? targetType; // "post", "comment", "badge", "achievement"
  final String? imageUrl;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  ActivityTimeline({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.title,
    this.description,
    this.targetId,
    this.targetType,
    this.imageUrl,
    required this.createdAt,
    required this.metadata,
  });

  factory ActivityTimeline.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityTimeline(
      id: doc.id,
      userId: data['userId'] ?? '',
      activityType: data['activityType'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      targetId: data['targetId'],
      targetType: data['targetType'],
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'activityType': activityType,
      'title': title,
      'description': description,
      'targetId': targetId,
      'targetType': targetType,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  ActivityTimeline copyWith({
    String? id,
    String? userId,
    String? activityType,
    String? title,
    String? description,
    String? targetId,
    String? targetType,
    String? imageUrl,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return ActivityTimeline(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      activityType: activityType ?? this.activityType,
      title: title ?? this.title,
      description: description ?? this.description,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Aktivite Filtresi
class ActivityFilter {
  final String userId;
  final List<String> activityTypes;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int limit;

  ActivityFilter({
    required this.userId,
    required this.activityTypes,
    this.fromDate,
    this.toDate,
    required this.limit,
  });
}

/// Aktivite İstatistikleri
class ActivityStats {
  final String userId;
  final int totalPosts;
  final int totalComments;
  final int totalBadges;
  final int totalLikes;
  final int followersCount;
  final int followingCount;
  final DateTime? lastActivityDate;
  final int streakDays; // Kaç gün ard arda aktif

  ActivityStats({
    required this.userId,
    required this.totalPosts,
    required this.totalComments,
    required this.totalBadges,
    required this.totalLikes,
    required this.followersCount,
    required this.followingCount,
    this.lastActivityDate,
    required this.streakDays,
  });

  factory ActivityStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityStats(
      userId: data['userId'] ?? '',
      totalPosts: (data['totalPosts'] ?? 0).toInt(),
      totalComments: (data['totalComments'] ?? 0).toInt(),
      totalBadges: (data['totalBadges'] ?? 0).toInt(),
      totalLikes: (data['totalLikes'] ?? 0).toInt(),
      followersCount: (data['followersCount'] ?? 0).toInt(),
      followingCount: (data['followingCount'] ?? 0).toInt(),
      lastActivityDate: (data['lastActivityDate'] as Timestamp?)?.toDate(),
      streakDays: (data['streakDays'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'totalPosts': totalPosts,
      'totalComments': totalComments,
      'totalBadges': totalBadges,
      'totalLikes': totalLikes,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'lastActivityDate': lastActivityDate != null ? Timestamp.fromDate(lastActivityDate!) : null,
      'streakDays': streakDays,
    };
  }
}
