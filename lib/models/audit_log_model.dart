import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin Audit Log Sistemi - Tüm admin işlemlerinin kaydı
class AdminAuditLog {
  final String id;
  final String adminId;
  final String adminName;
  final String action; // "create", "update", "delete", "approve", "reject", "ban"
  final String targetType; // "user", "post", "comment", "news", "exam"
  final String targetId;
  final String status; // "success", "failed"
  final DateTime createdAt;
  final String? reason;
  final Map<String, dynamic> changes; // Önceki ve sonraki değerler
  final String ipAddress;
  final String userAgent;
  final bool flagged; // İstisnai durumlar için

  AdminAuditLog({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.status,
    required this.createdAt,
    this.reason,
    required this.changes,
    required this.ipAddress,
    required this.userAgent,
    required this.flagged,
  });

  factory AdminAuditLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminAuditLog(
      id: doc.id,
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'] ?? '',
      action: data['action'] ?? '',
      targetType: data['targetType'] ?? '',
      targetId: data['targetId'] ?? '',
      status: data['status'] ?? 'success',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: data['reason'],
      changes: Map<String, dynamic>.from(data['changes'] ?? {}),
      ipAddress: data['ipAddress'] ?? '',
      userAgent: data['userAgent'] ?? '',
      flagged: data['flagged'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'adminId': adminId,
      'adminName': adminName,
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'reason': reason,
      'changes': changes,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'flagged': flagged,
    };
  }

  AdminAuditLog copyWith({
    String? id,
    String? adminId,
    String? adminName,
    String? action,
    String? targetType,
    String? targetId,
    String? status,
    DateTime? createdAt,
    String? reason,
    Map<String, dynamic>? changes,
    String? ipAddress,
    String? userAgent,
    bool? flagged,
  }) {
    return AdminAuditLog(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      adminName: adminName ?? this.adminName,
      action: action ?? this.action,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      reason: reason ?? this.reason,
      changes: changes ?? this.changes,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      flagged: flagged ?? this.flagged,
    );
  }
}

/// Audit Log Özeti
class AuditLogSummary {
  final String adminId;
  final String adminName;
  final int totalActions;
  final int successfulActions;
  final int failedActions;
  final int flaggedActions;
  final DateTime lastAction;
  final Map<String, int> actionCounts;

  AuditLogSummary({
    required this.adminId,
    required this.adminName,
    required this.totalActions,
    required this.successfulActions,
    required this.failedActions,
    required this.flaggedActions,
    required this.lastAction,
    required this.actionCounts,
  });

  factory AuditLogSummary.fromMap(Map<String, dynamic> data) {
    return AuditLogSummary(
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'] ?? '',
      totalActions: (data['totalActions'] ?? 0).toInt(),
      successfulActions: (data['successfulActions'] ?? 0).toInt(),
      failedActions: (data['failedActions'] ?? 0).toInt(),
      flaggedActions: (data['flaggedActions'] ?? 0).toInt(),
      lastAction: (data['lastAction'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actionCounts: Map<String, int>.from(data['actionCounts'] ?? {}),
    );
  }

  double get successRate {
    if (totalActions == 0) return 0;
    return (successfulActions / totalActions) * 100;
  }
}
