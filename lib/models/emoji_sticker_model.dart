import 'package:cloud_firestore/cloud_firestore.dart';

/// Emoji & Sticker Pack Sistemi
class EmojiPack {
  final String id;
  final String name;
  final String category; // "emoji", "sticker", "reaction"
  final List<Emoji> items;
  final String authorId;
  final String? imageUrl;
  final int downloadCount;
  final double rating;
  final bool isOfficial;
  final DateTime createdAt;
  final bool isActive;

  EmojiPack({
    required this.id,
    required this.name,
    required this.category,
    required this.items,
    required this.authorId,
    this.imageUrl,
    required this.downloadCount,
    required this.rating,
    required this.isOfficial,
    required this.createdAt,
    required this.isActive,
  });

  factory EmojiPack.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final itemsList = (data['items'] as List?)
        ?.map((item) => Emoji.fromMap(item as Map<String, dynamic>))
        .toList() ?? [];
    return EmojiPack(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'emoji',
      items: itemsList,
      authorId: data['authorId'] ?? '',
      imageUrl: data['imageUrl'],
      downloadCount: (data['downloadCount'] ?? 0).toInt(),
      rating: (data['rating'] ?? 0.0).toDouble(),
      isOfficial: data['isOfficial'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'items': items.map((e) => e.toMap()).toList(),
      'authorId': authorId,
      'imageUrl': imageUrl,
      'downloadCount': downloadCount,
      'rating': rating,
      'isOfficial': isOfficial,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}

/// Tekil Emoji/Sticker
class Emoji {
  final String id;
  final String unicode; // Unicode veya custom ID
  final String name;
  final String? imageUrl;
  final List<String> keywords;
  final String category;

  Emoji({
    required this.id,
    required this.unicode,
    required this.name,
    this.imageUrl,
    required this.keywords,
    required this.category,
  });

  factory Emoji.fromMap(Map<String, dynamic> data) {
    return Emoji(
      id: data['id'] ?? '',
      unicode: data['unicode'] ?? '',
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'],
      keywords: List<String>.from(data['keywords'] ?? []),
      category: data['category'] ?? 'general',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unicode': unicode,
      'name': name,
      'imageUrl': imageUrl,
      'keywords': keywords,
      'category': category,
    };
  }
}

/// Emoji Reaction - Mesajlara reaksiyon
class EmojiReaction {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  EmojiReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory EmojiReaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmojiReaction(
      id: doc.id,
      messageId: data['messageId'] ?? '',
      userId: data['userId'] ?? '',
      emoji: data['emoji'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'messageId': messageId,
      'userId': userId,
      'emoji': emoji,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
