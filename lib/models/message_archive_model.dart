import 'package:cloud_firestore/cloud_firestore.dart';

/// Mesaj Arşivi Sistemi
class MessageArchive {
  final String id;
  final String messageId;
  final String chatRoomId;
  final String userId;
  final String content;
  final String? imageUrl;
  final List<String> attachmentUrls;
  final DateTime originalCreatedAt;
  final DateTime archivedAt;
  final String archivedBy;
  final String? reason;
  final String status; // "archived", "restored", "deleted"
  final Map<String, dynamic> metadata;

  MessageArchive({
    required this.id,
    required this.messageId,
    required this.chatRoomId,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.attachmentUrls,
    required this.originalCreatedAt,
    required this.archivedAt,
    required this.archivedBy,
    this.reason,
    required this.status,
    required this.metadata,
  });

  factory MessageArchive.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageArchive(
      id: doc.id,
      messageId: data['messageId'] ?? '',
      chatRoomId: data['chatRoomId'] ?? '',
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      originalCreatedAt: (data['originalCreatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      archivedBy: data['archivedBy'] ?? '',
      reason: data['reason'],
      status: data['status'] ?? 'archived',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'messageId': messageId,
      'chatRoomId': chatRoomId,
      'userId': userId,
      'content': content,
      'imageUrl': imageUrl,
      'attachmentUrls': attachmentUrls,
      'originalCreatedAt': Timestamp.fromDate(originalCreatedAt),
      'archivedAt': Timestamp.fromDate(archivedAt),
      'archivedBy': archivedBy,
      'reason': reason,
      'status': status,
      'metadata': metadata,
    };
  }

  MessageArchive copyWith({
    String? id,
    String? messageId,
    String? chatRoomId,
    String? userId,
    String? content,
    String? imageUrl,
    List<String>? attachmentUrls,
    DateTime? originalCreatedAt,
    DateTime? archivedAt,
    String? archivedBy,
    String? reason,
    String? status,
    Map<String, dynamic>? metadata,
  }) {
    return MessageArchive(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      originalCreatedAt: originalCreatedAt ?? this.originalCreatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedBy: archivedBy ?? this.archivedBy,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Arşiv Ayarları
class ArchiveSettings {
  final String id;
  final String chatRoomId;
  final bool autoArchive;
  final int autoArchiveDays; // Kaç gün sonra arşivlensin
  final int retentionDays; // Arşiv ne kadar süre tutulacak
  final bool notifyOnArchive;
  final DateTime lastAutoArchiveRun;

  ArchiveSettings({
    required this.id,
    required this.chatRoomId,
    required this.autoArchive,
    required this.autoArchiveDays,
    required this.retentionDays,
    required this.notifyOnArchive,
    required this.lastAutoArchiveRun,
  });

  factory ArchiveSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ArchiveSettings(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      autoArchive: data['autoArchive'] ?? false,
      autoArchiveDays: (data['autoArchiveDays'] ?? 30).toInt(),
      retentionDays: (data['retentionDays'] ?? 365).toInt(),
      notifyOnArchive: data['notifyOnArchive'] ?? false,
      lastAutoArchiveRun: (data['lastAutoArchiveRun'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatRoomId': chatRoomId,
      'autoArchive': autoArchive,
      'autoArchiveDays': autoArchiveDays,
      'retentionDays': retentionDays,
      'notifyOnArchive': notifyOnArchive,
      'lastAutoArchiveRun': Timestamp.fromDate(lastAutoArchiveRun),
    };
  }
}
