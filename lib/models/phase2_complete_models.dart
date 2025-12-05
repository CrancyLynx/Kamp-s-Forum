// lib/models/phase2_models.dart
// ============================================================
// PHASE 2 - Advanced Features & System Models
// ============================================================

// ============================================================
// 1. NEWS & ANNOUNCEMENTS MODEL
// ============================================================
class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String sourceUrl;
  final String category;
  final DateTime publishedAt;
  final String sourceName;
  final int views;
  final bool isBookmarked;

  NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.sourceUrl,
    required this.category,
    required this.publishedAt,
    required this.sourceName,
    this.views = 0,
    this.isBookmarked = false,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Başlık Yok',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      sourceUrl: json['sourceUrl'] ?? '',
      category: json['category'] ?? 'genel',
      publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
      sourceName: json['sourceName'] ?? 'Kaynak',
      views: json['views'] ?? 0,
      isBookmarked: json['isBookmarked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'imageUrl': imageUrl,
    'sourceUrl': sourceUrl,
    'category': category,
    'publishedAt': publishedAt.toIso8601String(),
    'sourceName': sourceName,
    'views': views,
    'isBookmarked': isBookmarked,
  };
}

// ============================================================
// 2. LOCATION MARKERS MODEL
// ============================================================
class LocationMarker {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String category;
  final String iconUrl;
  final List<String> imageUrls;
  final String createdBy;
  final DateTime createdAt;
  final int rating;

  LocationMarker({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.iconUrl,
    required this.imageUrls,
    required this.createdBy,
    required this.createdAt,
    this.rating = 0,
  });

  factory LocationMarker.fromJson(Map<String, dynamic> json) {
    return LocationMarker(
      id: json['id'] ?? '',
      name: json['name'] ?? 'İsimsiz Yer',
      description: json['description'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      category: json['category'] ?? 'diğer',
      iconUrl: json['iconUrl'] ?? '',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      createdBy: json['createdBy'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      rating: json['rating'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'category': category,
    'iconUrl': iconUrl,
    'imageUrls': imageUrls,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'rating': rating,
  };
}

// ============================================================
// 3. EMOJI & STICKER PACK MODEL
// ============================================================
class EmojiStickerPack {
  final String id;
  final String name;
  final String description;
  final String packageIcon;
  final List<String> stickerUrls;
  final String category;
  final int downloads;
  final bool isOfficial;
  final String createdBy;

  EmojiStickerPack({
    required this.id,
    required this.name,
    required this.description,
    required this.packageIcon,
    required this.stickerUrls,
    required this.category,
    this.downloads = 0,
    this.isOfficial = false,
    required this.createdBy,
  });

  factory EmojiStickerPack.fromJson(Map<String, dynamic> json) {
    return EmojiStickerPack(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Paket',
      description: json['description'] ?? '',
      packageIcon: json['packageIcon'] ?? '',
      stickerUrls: List<String>.from(json['stickerUrls'] ?? []),
      category: json['category'] ?? 'genel',
      downloads: json['downloads'] ?? 0,
      isOfficial: json['isOfficial'] ?? false,
      createdBy: json['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'packageIcon': packageIcon,
    'stickerUrls': stickerUrls,
    'category': category,
    'downloads': downloads,
    'isOfficial': isOfficial,
    'createdBy': createdBy,
  };
}

// ============================================================
// 4. CHAT MODERATION MODEL
// ============================================================
class ChatModerationLog {
  final String id;
  final String messageId;
  final String senderId;
  final String senderName;
  final String messageContent;
  final String reason;
  final String action;
  final String moderatorId;
  final DateTime actionDate;
  final String status;

  ChatModerationLog({
    required this.id,
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.messageContent,
    required this.reason,
    required this.action,
    required this.moderatorId,
    required this.actionDate,
    this.status = 'completed',
  });

  factory ChatModerationLog.fromJson(Map<String, dynamic> json) {
    return ChatModerationLog(
      id: json['id'] ?? '',
      messageId: json['messageId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Bilinmeyen',
      messageContent: json['messageContent'] ?? '',
      reason: json['reason'] ?? '',
      action: json['action'] ?? 'review',
      moderatorId: json['moderatorId'] ?? '',
      actionDate: DateTime.tryParse(json['actionDate'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'completed',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'messageId': messageId,
    'senderId': senderId,
    'senderName': senderName,
    'messageContent': messageContent,
    'reason': reason,
    'action': action,
    'moderatorId': moderatorId,
    'actionDate': actionDate.toIso8601String(),
    'status': status,
  };
}

// ============================================================
// 5. MESSAGE ARCHIVE MODEL
// ============================================================
class MessageArchive {
  final String id;
  final String chatId;
  final String userId;
  final String messageContent;
  final List<String> attachmentUrls;
  final DateTime archivedAt;
  final DateTime originalSentAt;
  final String senderName;

  MessageArchive({
    required this.id,
    required this.chatId,
    required this.userId,
    required this.messageContent,
    required this.attachmentUrls,
    required this.archivedAt,
    required this.originalSentAt,
    required this.senderName,
  });

  factory MessageArchive.fromJson(Map<String, dynamic> json) {
    return MessageArchive(
      id: json['id'] ?? '',
      chatId: json['chatId'] ?? '',
      userId: json['userId'] ?? '',
      messageContent: json['messageContent'] ?? '',
      attachmentUrls: List<String>.from(json['attachmentUrls'] ?? []),
      archivedAt: DateTime.tryParse(json['archivedAt'] ?? '') ?? DateTime.now(),
      originalSentAt: DateTime.tryParse(json['originalSentAt'] ?? '') ?? DateTime.now(),
      senderName: json['senderName'] ?? 'Bilinmeyen',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'chatId': chatId,
    'userId': userId,
    'messageContent': messageContent,
    'attachmentUrls': attachmentUrls,
    'archivedAt': archivedAt.toIso8601String(),
    'originalSentAt': originalSentAt.toIso8601String(),
    'senderName': senderName,
  };
}

// ============================================================
// 6. NOTIFICATION PREFERENCE MODEL
// ============================================================
class NotificationPreference {
  final String userId;
  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;
  final List<String> enabledCategories;
  final bool muteAll;
  final DateTime quietHoursStart;
  final DateTime quietHoursEnd;
  final bool dosNotDisturbEnabled;

  NotificationPreference({
    required this.userId,
    this.pushEnabled = true,
    this.emailEnabled = false,
    this.smsEnabled = false,
    required this.enabledCategories,
    this.muteAll = false,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    this.dosNotDisturbEnabled = false,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      userId: json['userId'] ?? '',
      pushEnabled: json['pushEnabled'] ?? true,
      emailEnabled: json['emailEnabled'] ?? false,
      smsEnabled: json['smsEnabled'] ?? false,
      enabledCategories: List<String>.from(json['enabledCategories'] ?? []),
      muteAll: json['muteAll'] ?? false,
      quietHoursStart: DateTime.tryParse(json['quietHoursStart'] ?? '10:00') ?? DateTime.now(),
      quietHoursEnd: DateTime.tryParse(json['quietHoursEnd'] ?? '22:00') ?? DateTime.now(),
      dosNotDisturbEnabled: json['dosNotDisturbEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'pushEnabled': pushEnabled,
    'emailEnabled': emailEnabled,
    'smsEnabled': smsEnabled,
    'enabledCategories': enabledCategories,
    'muteAll': muteAll,
    'quietHoursStart': quietHoursStart.toString(),
    'quietHoursEnd': quietHoursEnd.toString(),
    'dosNotDisturbEnabled': dosNotDisturbEnabled,
  };
}
