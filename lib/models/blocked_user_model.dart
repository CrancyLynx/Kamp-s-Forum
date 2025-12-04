import 'package:cloud_firestore/cloud_firestore.dart';

/// Engellenen Kullanıcılar Sistemi
class BlockedUser {
  final String id;
  final String userId; // Englleyen kullanıcı
  final String blockedUserId; // Engellenen kullanıcı
  final String blockedUserName;
  final String? blockedUserAvatar;
  final DateTime blockedAt;
  final String? reason;
  final bool canMessage;
  final bool canViewProfile;
  final bool canViewPosts;
  final bool canSeeActivity;
  final bool permanent;
  final DateTime? unblockAt;
  final Map<String, dynamic> metadata;

  BlockedUser({
    required this.id,
    required this.userId,
    required this.blockedUserId,
    required this.blockedUserName,
    this.blockedUserAvatar,
    required this.blockedAt,
    this.reason,
    required this.canMessage,
    required this.canViewProfile,
    required this.canViewPosts,
    required this.canSeeActivity,
    required this.permanent,
    this.unblockAt,
    required this.metadata,
  });

  factory BlockedUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlockedUser(
      id: doc.id,
      userId: data['userId'] ?? '',
      blockedUserId: data['blockedUserId'] ?? '',
      blockedUserName: data['blockedUserName'] ?? '',
      blockedUserAvatar: data['blockedUserAvatar'],
      blockedAt: (data['blockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: data['reason'],
      canMessage: data['canMessage'] ?? false,
      canViewProfile: data['canViewProfile'] ?? false,
      canViewPosts: data['canViewPosts'] ?? false,
      canSeeActivity: data['canSeeActivity'] ?? false,
      permanent: data['permanent'] ?? true,
      unblockAt: (data['unblockAt'] as Timestamp?)?.toDate(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'blockedUserId': blockedUserId,
      'blockedUserName': blockedUserName,
      'blockedUserAvatar': blockedUserAvatar,
      'blockedAt': Timestamp.fromDate(blockedAt),
      'reason': reason,
      'canMessage': canMessage,
      'canViewProfile': canViewProfile,
      'canViewPosts': canViewPosts,
      'canSeeActivity': canSeeActivity,
      'permanent': permanent,
      'unblockAt': unblockAt != null ? Timestamp.fromDate(unblockAt!) : null,
      'metadata': metadata,
    };
  }

  BlockedUser copyWith({
    String? id,
    String? userId,
    String? blockedUserId,
    String? blockedUserName,
    String? blockedUserAvatar,
    DateTime? blockedAt,
    String? reason,
    bool? canMessage,
    bool? canViewProfile,
    bool? canViewPosts,
    bool? canSeeActivity,
    bool? permanent,
    DateTime? unblockAt,
    Map<String, dynamic>? metadata,
  }) {
    return BlockedUser(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      blockedUserId: blockedUserId ?? this.blockedUserId,
      blockedUserName: blockedUserName ?? this.blockedUserName,
      blockedUserAvatar: blockedUserAvatar ?? this.blockedUserAvatar,
      blockedAt: blockedAt ?? this.blockedAt,
      reason: reason ?? this.reason,
      canMessage: canMessage ?? this.canMessage,
      canViewProfile: canViewProfile ?? this.canViewProfile,
      canViewPosts: canViewPosts ?? this.canViewPosts,
      canSeeActivity: canSeeActivity ?? this.canSeeActivity,
      permanent: permanent ?? this.permanent,
      unblockAt: unblockAt ?? this.unblockAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Engelleme hala aktif mi?
  bool get isActive {
    if (permanent) return true;
    if (unblockAt == null) return true;
    return DateTime.now().isBefore(unblockAt!);
  }

  /// Otomatik açılacak mı?
  bool get willAutoUnblock => !permanent && unblockAt != null;
}

/// Engelleme İstatistikleri
class BlockStatistics {
  final String userId;
  final int totalBlocked;
  final int activeBlocks;
  final int temporaryBlocks;
  final int permanentBlocks;
  final DateTime lastBlockDate;

  BlockStatistics({
    required this.userId,
    required this.totalBlocked,
    required this.activeBlocks,
    required this.temporaryBlocks,
    required this.permanentBlocks,
    required this.lastBlockDate,
  });

  factory BlockStatistics.fromMap(Map<String, dynamic> data) {
    return BlockStatistics(
      userId: data['userId'] ?? '',
      totalBlocked: (data['totalBlocked'] ?? 0).toInt(),
      activeBlocks: (data['activeBlocks'] ?? 0).toInt(),
      temporaryBlocks: (data['temporaryBlocks'] ?? 0).toInt(),
      permanentBlocks: (data['permanentBlocks'] ?? 0).toInt(),
      lastBlockDate: (data['lastBlockDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  double get permanentBlockPercentage {
    if (totalBlocked == 0) return 0;
    return (permanentBlocks / totalBlocked) * 100;
  }
}
