import 'package:cloud_firestore/cloud_firestore.dart';

/// Gelişmiş Moderasyon Sistemi
class AdvancedModeration {
  final String id;
  final String targetUserId;
  final String targetUserName;
  final String actionType; // "warning", "mute", "suspend", "ban", "restricted"
  final String reason;
  final DateTime createdAt;
  final DateTime? expiredAt;
  final bool isPermanent;
  final String moderatorId;
  final String moderatorName;
  final int severity; // 1-5
  final String status; // "active", "appealed", "lifted", "expired"
  final List<String> restrictions; // Hangi özelliklere kısıtlama
  final int appealCount;
  final DateTime? lastAppealDate;
  final String? appealReason;
  final String? appealResponse;
  final bool allowAppeal;
  final Map<String, dynamic> metadata;

  AdvancedModeration({
    required this.id,
    required this.targetUserId,
    required this.targetUserName,
    required this.actionType,
    required this.reason,
    required this.createdAt,
    this.expiredAt,
    required this.isPermanent,
    required this.moderatorId,
    required this.moderatorName,
    required this.severity,
    required this.status,
    required this.restrictions,
    required this.appealCount,
    this.lastAppealDate,
    this.appealReason,
    this.appealResponse,
    required this.allowAppeal,
    required this.metadata,
  });

  factory AdvancedModeration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdvancedModeration(
      id: doc.id,
      targetUserId: data['targetUserId'] ?? '',
      targetUserName: data['targetUserName'] ?? '',
      actionType: data['actionType'] ?? '',
      reason: data['reason'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiredAt: (data['expiredAt'] as Timestamp?)?.toDate(),
      isPermanent: data['isPermanent'] ?? false,
      moderatorId: data['moderatorId'] ?? '',
      moderatorName: data['moderatorName'] ?? '',
      severity: (data['severity'] ?? 1).toInt(),
      status: data['status'] ?? 'active',
      restrictions: List<String>.from(data['restrictions'] ?? []),
      appealCount: (data['appealCount'] ?? 0).toInt(),
      lastAppealDate: (data['lastAppealDate'] as Timestamp?)?.toDate(),
      appealReason: data['appealReason'],
      appealResponse: data['appealResponse'],
      allowAppeal: data['allowAppeal'] ?? true,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'targetUserId': targetUserId,
      'targetUserName': targetUserName,
      'actionType': actionType,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiredAt': expiredAt != null ? Timestamp.fromDate(expiredAt!) : null,
      'isPermanent': isPermanent,
      'moderatorId': moderatorId,
      'moderatorName': moderatorName,
      'severity': severity,
      'status': status,
      'restrictions': restrictions,
      'appealCount': appealCount,
      'lastAppealDate': lastAppealDate != null ? Timestamp.fromDate(lastAppealDate!) : null,
      'appealReason': appealReason,
      'appealResponse': appealResponse,
      'allowAppeal': allowAppeal,
      'metadata': metadata,
    };
  }

  AdvancedModeration copyWith({
    String? id,
    String? targetUserId,
    String? targetUserName,
    String? actionType,
    String? reason,
    DateTime? createdAt,
    DateTime? expiredAt,
    bool? isPermanent,
    String? moderatorId,
    String? moderatorName,
    int? severity,
    String? status,
    List<String>? restrictions,
    int? appealCount,
    DateTime? lastAppealDate,
    String? appealReason,
    String? appealResponse,
    bool? allowAppeal,
    Map<String, dynamic>? metadata,
  }) {
    return AdvancedModeration(
      id: id ?? this.id,
      targetUserId: targetUserId ?? this.targetUserId,
      targetUserName: targetUserName ?? this.targetUserName,
      actionType: actionType ?? this.actionType,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      expiredAt: expiredAt ?? this.expiredAt,
      isPermanent: isPermanent ?? this.isPermanent,
      moderatorId: moderatorId ?? this.moderatorId,
      moderatorName: moderatorName ?? this.moderatorName,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      restrictions: restrictions ?? this.restrictions,
      appealCount: appealCount ?? this.appealCount,
      lastAppealDate: lastAppealDate ?? this.lastAppealDate,
      appealReason: appealReason ?? this.appealReason,
      appealResponse: appealResponse ?? this.appealResponse,
      allowAppeal: allowAppeal ?? this.allowAppeal,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Ceza hala aktif mi?
  bool get isActive {
    if (status != 'active') return false;
    if (isPermanent) return true;
    if (expiredAt == null) return false;
    return DateTime.now().isBefore(expiredAt!);
  }

  /// Gün cinsinden kalan süre
  int? get daysRemaining {
    if (expiredAt == null) return null;
    return expiredAt!.difference(DateTime.now()).inDays;
  }

  /// Ciddi mi?
  bool get isSevere => severity >= 4;

  /// İtiraz edilmiş mi?
  bool get isAppealed => status == 'appealed';

  /// İtiraz hakkı var mı?
  bool get canAppeal => allowAppeal && (appealCount < 3);
}

/// İtiraz
class ModerationAppeal {
  final String id;
  final String moderationId;
  final String userId;
  final String appealReason;
  final DateTime appealdAt;
  final String status; // "pending", "approved", "rejected"
  final String? responseBy;
  final String? response;
  final DateTime? respondedAt;

  ModerationAppeal({
    required this.id,
    required this.moderationId,
    required this.userId,
    required this.appealReason,
    required this.appealdAt,
    required this.status,
    this.responseBy,
    this.response,
    this.respondedAt,
  });

  factory ModerationAppeal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ModerationAppeal(
      id: doc.id,
      moderationId: data['moderationId'] ?? '',
      userId: data['userId'] ?? '',
      appealReason: data['appealReason'] ?? '',
      appealdAt: (data['appealdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      responseBy: data['responseBy'],
      response: data['response'],
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'moderationId': moderationId,
      'userId': userId,
      'appealReason': appealReason,
      'appealdAt': Timestamp.fromDate(appealdAt),
      'status': status,
      'responseBy': responseBy,
      'response': response,
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }
}
