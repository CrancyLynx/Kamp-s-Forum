import 'package:cloud_firestore/cloud_firestore.dart';

// PHASE 2 - 10 SYSTEMS

/// 1. Haber & Duyurular
class News {
  final String id;
  final String title;
  final String content;
  final String category; // "akademik", "etkinlik", "bildirim", "ozel"
  final String imageUrl;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isPinned;
  final int viewCount;

  News({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.imageUrl,
    required this.createdAt,
    this.expiresAt,
    required this.isPinned,
    required this.viewCount,
  });

  factory News.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return News(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] ?? 'bildirim',
      imageUrl: data['imageUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      isPinned: data['isPinned'] ?? false,
      viewCount: (data['viewCount'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'category': category,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isPinned': isPinned,
      'viewCount': viewCount,
    };
  }
}

/// 2. Location Markers
class LocationMarker {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String iconType; // "canteen", "library", "classroom", "event", "custom"
  final String category;
  final String description;
  final bool isActive;
  final String? openingHours;

  LocationMarker({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.iconType,
    required this.category,
    required this.description,
    required this.isActive,
    this.openingHours,
  });

  factory LocationMarker.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationMarker(
      id: doc.id,
      name: data['name'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      iconType: data['iconType'] ?? 'custom',
      category: data['category'] ?? 'general',
      description: data['description'] ?? '',
      isActive: data['isActive'] ?? true,
      openingHours: data['openingHours'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'iconType': iconType,
      'category': category,
      'description': description,
      'isActive': isActive,
      'openingHours': openingHours,
    };
  }
}

/// 3. Emoji & Sticker Pack
class EmojiPack {
  final String id;
  final String packName;
  final List<String> emojis;
  final String category;
  final bool isFeatured;
  final int downloadCount;

  EmojiPack({
    required this.id,
    required this.packName,
    required this.emojis,
    required this.category,
    required this.isFeatured,
    required this.downloadCount,
  });

  factory EmojiPack.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmojiPack(
      id: doc.id,
      packName: data['packName'] ?? '',
      emojis: List<String>.from(data['emojis'] ?? []),
      category: data['category'] ?? 'general',
      isFeatured: data['isFeatured'] ?? false,
      downloadCount: (data['downloadCount'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'packName': packName,
      'emojis': emojis,
      'category': category,
      'isFeatured': isFeatured,
      'downloadCount': downloadCount,
    };
  }
}

/// 4. Chat Moderation
class ChatModeration {
  final String id;
  final String roomId;
  final String userId;
  final String action; // "mute", "kick", "ban", "warn"
  final DateTime appliedAt;
  final DateTime? expiresAt;
  final String reason;

  ChatModeration({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.action,
    required this.appliedAt,
    this.expiresAt,
    required this.reason,
  });

  factory ChatModeration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModeration(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      userId: data['userId'] ?? '',
      action: data['action'] ?? 'warn',
      appliedAt: (data['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      reason: data['reason'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'roomId': roomId,
      'userId': userId,
      'action': action,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'reason': reason,
    };
  }
}

/// 5. Notification Preferences
class NotificationPreference {
  final String userId;
  final bool pushEnabled;
  final bool emailEnabled;
  final bool inAppEnabled;
  final String quietHoursStart; // "22:00"
  final String quietHoursEnd; // "08:00"
  final List<String> enabledChannels; // "messages", "news", "events", etc.

  NotificationPreference({
    required this.userId,
    required this.pushEnabled,
    required this.emailEnabled,
    required this.inAppEnabled,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.enabledChannels,
  });

  factory NotificationPreference.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationPreference(
      userId: doc.id,
      pushEnabled: data['pushEnabled'] ?? true,
      emailEnabled: data['emailEnabled'] ?? true,
      inAppEnabled: data['inAppEnabled'] ?? true,
      quietHoursStart: data['quietHoursStart'] ?? '22:00',
      quietHoursEnd: data['quietHoursEnd'] ?? '08:00',
      enabledChannels: List<String>.from(data['enabledChannels'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pushEnabled': pushEnabled,
      'emailEnabled': emailEnabled,
      'inAppEnabled': inAppEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'enabledChannels': enabledChannels,
    };
  }
}

/// 6. Message Archive
class MessageArchive {
  final String id;
  final String roomId;
  final String messageId;
  final String userId;
  final String content;
  final DateTime archivedAt;
  final String tags;

  MessageArchive({
    required this.id,
    required this.roomId,
    required this.messageId,
    required this.userId,
    required this.content,
    required this.archivedAt,
    required this.tags,
  });

  factory MessageArchive.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageArchive(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      messageId: data['messageId'] ?? '',
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: data['tags'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'roomId': roomId,
      'messageId': messageId,
      'userId': userId,
      'content': content,
      'archivedAt': Timestamp.fromDate(archivedAt),
      'tags': tags,
    };
  }
}

/// 7. User Activity Timeline
class ActivityTimeline {
  final String id;
  final String userId;
  final String activityType; // "post", "comment", "vote", "join", "achievement"
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  ActivityTimeline({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.description,
    required this.timestamp,
    required this.metadata,
  });

  factory ActivityTimeline.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityTimeline(
      id: doc.id,
      userId: data['userId'] ?? '',
      activityType: data['activityType'] ?? 'post',
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'activityType': activityType,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
}

/// 8. Harita & Konum Sistemi (Konumlara ek)
class PlaceReview {
  final String id;
  final String placeId;
  final String reviewerId;
  final String reviewerName;
  final double rating; // 1-5
  final String comment;
  final List<String> photoUrls;
  final DateTime createdAt;
  final int likeCount;

  PlaceReview({
    required this.id,
    required this.placeId,
    required this.reviewerId,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.photoUrls,
    required this.createdAt,
    required this.likeCount,
  });

  factory PlaceReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlaceReview(
      id: doc.id,
      placeId: data['placeId'] ?? '',
      reviewerId: data['reviewerId'] ?? '',
      reviewerName: data['reviewerName'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      comment: data['comment'] ?? '',
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: (data['likeCount'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'placeId': placeId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'photoUrls': photoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
    };
  }
}

/// 9. İstatistik & Analytics Dashboard
class UserStatistics {
  final String userId;
  final int postsCount;
  final int pollsCreated;
  final int pollsVoted;
  final int forumsParticipated;
  final int messagesCount;
  final int ringsCompleted;
  final int totalXP;
  final DateTime lastActiveAt;

  UserStatistics({
    required this.userId,
    required this.postsCount,
    required this.pollsCreated,
    required this.pollsVoted,
    required this.forumsParticipated,
    required this.messagesCount,
    required this.ringsCompleted,
    required this.totalXP,
    required this.lastActiveAt,
  });

  factory UserStatistics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserStatistics(
      userId: doc.id,
      postsCount: (data['postsCount'] ?? 0).toInt(),
      pollsCreated: (data['pollsCreated'] ?? 0).toInt(),
      pollsVoted: (data['pollsVoted'] ?? 0).toInt(),
      forumsParticipated: (data['forumsParticipated'] ?? 0).toInt(),
      messagesCount: (data['messagesCount'] ?? 0).toInt(),
      ringsCompleted: (data['ringsCompleted'] ?? 0).toInt(),
      totalXP: (data['totalXP'] ?? 0).toInt(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postsCount': postsCount,
      'pollsCreated': pollsCreated,
      'pollsVoted': pollsVoted,
      'forumsParticipated': forumsParticipated,
      'messagesCount': messagesCount,
      'ringsCompleted': ringsCompleted,
      'totalXP': totalXP,
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
    };
  }
}

/// 10. Sistem Bildirimleri Özelleştirmesi
class NotificationTemplate {
  final String id;
  final String templateName;
  final String messageTemplate; // Placeholder: {userNames}, {count}, {action}
  final String? actionUrl;
  final String notificationType; // "new_post", "new_message", "new_poll", "mention"
  final bool isActive;

  NotificationTemplate({
    required this.id,
    required this.templateName,
    required this.messageTemplate,
    this.actionUrl,
    required this.notificationType,
    required this.isActive,
  });

  factory NotificationTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationTemplate(
      id: doc.id,
      templateName: data['templateName'] ?? '',
      messageTemplate: data['messageTemplate'] ?? '',
      actionUrl: data['actionUrl'],
      notificationType: data['notificationType'] ?? 'new_post',
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'templateName': templateName,
      'messageTemplate': messageTemplate,
      'actionUrl': actionUrl,
      'notificationType': notificationType,
      'isActive': isActive,
    };
  }
}
