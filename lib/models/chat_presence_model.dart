import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcı Yazma Durumu (Typing Indicator)
class UserTypingStatus {
  final String userId;
  final String userName;
  final DateTime typingStartedAt;
  final bool isTyping;

  UserTypingStatus({
    required this.userId,
    required this.userName,
    required this.typingStartedAt,
    required this.isTyping,
  });

  factory UserTypingStatus.fromFirestore(Map<String, dynamic> data) {
    return UserTypingStatus(
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Kullanıcı',
      typingStartedAt: (data['typingStartedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isTyping: data['isTyping'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'typingStartedAt': Timestamp.fromDate(typingStartedAt),
      'isTyping': isTyping,
    };
  }

  // Timeout kontrol (30 saniye timeout)
  bool isTimedOut() {
    return isTyping &&
        DateTime.now().difference(typingStartedAt).inSeconds > 30;
  }
}

/// Kullanıcı Çevrimiçi Durumu
class UserPresence {
  final String userId;
  final String userName;
  final String userProfilePhotoUrl;
  final bool isOnline;
  final DateTime lastSeenAt;
  final String? currentRoomId;
  final String deviceType; // "mobile", "web", "desktop"

  UserPresence({
    required this.userId,
    required this.userName,
    required this.userProfilePhotoUrl,
    required this.isOnline,
    required this.lastSeenAt,
    this.currentRoomId,
    required this.deviceType,
  });

  factory UserPresence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserPresence(
      userId: doc.id,
      userName: data['userName'] ?? 'Kullanıcı',
      userProfilePhotoUrl: data['userProfilePhotoUrl'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentRoomId: data['currentRoomId'],
      deviceType: data['deviceType'] ?? 'mobile',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userName': userName,
      'userProfilePhotoUrl': userProfilePhotoUrl,
      'isOnline': isOnline,
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'currentRoomId': currentRoomId,
      'deviceType': deviceType,
    };
  }

  // İdle Detection (5 dakika)
  bool isIdle() {
    return isOnline &&
        DateTime.now().difference(lastSeenAt).inMinutes >= 5;
  }
}

/// Mesaj Reaksiyonu
class MessageReaction {
  final String userId;
  final String emoji;
  final DateTime createdAt;

  MessageReaction({
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReaction.fromMap(Map<String, dynamic> data) {
    return MessageReaction(
      userId: data['userId'] ?? '',
      emoji: data['emoji'] ?? '👍',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'emoji': emoji,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Reaksiyon Özeti (Emoji + Count)
class ReactionSummary {
  final String emoji;
  final int count;
  final List<String> userIds; // Kimin eklediği

  ReactionSummary({
    required this.emoji,
    required this.count,
    required this.userIds,
  });

  factory ReactionSummary.fromMap(Map<String, dynamic> data) {
    return ReactionSummary(
      emoji: data['emoji'] ?? '👍',
      count: (data['count'] ?? 0).toInt(),
      userIds: List<String>.from(data['userIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emoji': emoji,
      'count': count,
      'userIds': userIds,
    };
  }

  bool hasUserReacted(String userId) {
    return userIds.contains(userId);
  }
}
