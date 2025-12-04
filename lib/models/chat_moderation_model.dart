import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat Moderation Sistemi - Sohbetlerde içerik kontrolü
class ChatModeration {
  final String id;
  final String chatRoomId;
  final String messageId;
  final String userId;
  final String messageContent;
  final String status; // "pending", "approved", "rejected", "flagged"
  final String? reason;
  final List<String> flags; // "spam", "inappropriate", "harassment", "ads"
  final String? moderatorId;
  final String? moderatorNote;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final int severity; // 1-5

  ChatModeration({
    required this.id,
    required this.chatRoomId,
    required this.messageId,
    required this.userId,
    required this.messageContent,
    required this.status,
    this.reason,
    required this.flags,
    this.moderatorId,
    this.moderatorNote,
    required this.createdAt,
    this.resolvedAt,
    required this.severity,
  });

  factory ChatModeration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModeration(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      messageId: data['messageId'] ?? '',
      userId: data['userId'] ?? '',
      messageContent: data['messageContent'] ?? '',
      status: data['status'] ?? 'pending',
      reason: data['reason'],
      flags: List<String>.from(data['flags'] ?? []),
      moderatorId: data['moderatorId'],
      moderatorNote: data['moderatorNote'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      severity: (data['severity'] ?? 1).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatRoomId': chatRoomId,
      'messageId': messageId,
      'userId': userId,
      'messageContent': messageContent,
      'status': status,
      'reason': reason,
      'flags': flags,
      'moderatorId': moderatorId,
      'moderatorNote': moderatorNote,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'severity': severity,
    };
  }

  ChatModeration copyWith({
    String? id,
    String? chatRoomId,
    String? messageId,
    String? userId,
    String? messageContent,
    String? status,
    String? reason,
    List<String>? flags,
    String? moderatorId,
    String? moderatorNote,
    DateTime? createdAt,
    DateTime? resolvedAt,
    int? severity,
  }) {
    return ChatModeration(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      messageContent: messageContent ?? this.messageContent,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      flags: flags ?? this.flags,
      moderatorId: moderatorId ?? this.moderatorId,
      moderatorNote: moderatorNote ?? this.moderatorNote,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      severity: severity ?? this.severity,
    );
  }
}

/// Moderation Rule - İçerik kuralları
class ModerationRule {
  final String id;
  final String pattern;
  final String? replacement;
  final String category;
  final int severity; // 1-5
  final bool isActive;
  final String? description;

  ModerationRule({
    required this.id,
    required this.pattern,
    this.replacement,
    required this.category,
    required this.severity,
    required this.isActive,
    this.description,
  });

  factory ModerationRule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ModerationRule(
      id: doc.id,
      pattern: data['pattern'] ?? '',
      replacement: data['replacement'],
      category: data['category'] ?? 'general',
      severity: (data['severity'] ?? 1).toInt(),
      isActive: data['isActive'] ?? true,
      description: data['description'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pattern': pattern,
      'replacement': replacement,
      'category': category,
      'severity': severity,
      'isActive': isActive,
      'description': description,
    };
  }
}
