import 'package:cloud_firestore/cloud_firestore.dart';

/// Yazma İndikatörü - Kullanıcının yazıyor olduğunu gösterir
class TypingIndicator {
  final String id;
  final String chatRoomId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final DateTime startedAt;
  final DateTime lastActivity;
  final bool isTyping;

  TypingIndicator({
    required this.id,
    required this.chatRoomId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.startedAt,
    required this.lastActivity,
    required this.isTyping,
  });

  factory TypingIndicator.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TypingIndicator(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'],
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActivity: (data['lastActivity'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isTyping: data['isTyping'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatRoomId': chatRoomId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'startedAt': Timestamp.fromDate(startedAt),
      'lastActivity': Timestamp.fromDate(lastActivity),
      'isTyping': isTyping,
    };
  }

  TypingIndicator copyWith({
    String? id,
    String? chatRoomId,
    String? userId,
    String? userName,
    String? userAvatar,
    DateTime? startedAt,
    DateTime? lastActivity,
    bool? isTyping,
  }) {
    return TypingIndicator(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      startedAt: startedAt ?? this.startedAt,
      lastActivity: lastActivity ?? this.lastActivity,
      isTyping: isTyping ?? this.isTyping,
    );
  }

  /// Yazma timeout süresi (15 saniye)
  bool get isExpired {
    return DateTime.now().difference(lastActivity).inSeconds > 15;
  }
}
