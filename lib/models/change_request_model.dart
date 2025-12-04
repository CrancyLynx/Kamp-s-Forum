import 'package:cloud_firestore/cloud_firestore.dart';

/// Değişiklik Talebi Sistemi - Kullanıcıların bilgilerini düzeltmesi için
class ChangeRequest {
  final String id;
  final String userId;
  final String userName;
  final String requestType; // "profile", "email", "password", "phone", "university_info"
  final String fieldName;
  final String currentValue;
  final String newValue;
  final String reason;
  final DateTime requestedAt;
  final String status; // "pending", "approved", "rejected", "expired"
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final bool requiresVerification;
  final String? verificationCode;
  final DateTime? verificationExpiry;
  final int retryCount;
  final Map<String, dynamic> supportingDocuments;

  ChangeRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.requestType,
    required this.fieldName,
    required this.currentValue,
    required this.newValue,
    required this.reason,
    required this.requestedAt,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    required this.requiresVerification,
    this.verificationCode,
    this.verificationExpiry,
    required this.retryCount,
    required this.supportingDocuments,
  });

  factory ChangeRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChangeRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      requestType: data['requestType'] ?? '',
      fieldName: data['fieldName'] ?? '',
      currentValue: data['currentValue'] ?? '',
      newValue: data['newValue'] ?? '',
      reason: data['reason'] ?? '',
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      approvedBy: data['approvedBy'],
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'],
      requiresVerification: data['requiresVerification'] ?? false,
      verificationCode: data['verificationCode'],
      verificationExpiry: (data['verificationExpiry'] as Timestamp?)?.toDate(),
      retryCount: (data['retryCount'] ?? 0).toInt(),
      supportingDocuments: Map<String, dynamic>.from(data['supportingDocuments'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'requestType': requestType,
      'fieldName': fieldName,
      'currentValue': currentValue,
      'newValue': newValue,
      'reason': reason,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'status': status,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
      'requiresVerification': requiresVerification,
      'verificationCode': verificationCode,
      'verificationExpiry': verificationExpiry != null ? Timestamp.fromDate(verificationExpiry!) : null,
      'retryCount': retryCount,
      'supportingDocuments': supportingDocuments,
    };
  }

  ChangeRequest copyWith({
    String? id,
    String? userId,
    String? userName,
    String? requestType,
    String? fieldName,
    String? currentValue,
    String? newValue,
    String? reason,
    DateTime? requestedAt,
    String? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    bool? requiresVerification,
    String? verificationCode,
    DateTime? verificationExpiry,
    int? retryCount,
    Map<String, dynamic>? supportingDocuments,
  }) {
    return ChangeRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      requestType: requestType ?? this.requestType,
      fieldName: fieldName ?? this.fieldName,
      currentValue: currentValue ?? this.currentValue,
      newValue: newValue ?? this.newValue,
      reason: reason ?? this.reason,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      requiresVerification: requiresVerification ?? this.requiresVerification,
      verificationCode: verificationCode ?? this.verificationCode,
      verificationExpiry: verificationExpiry ?? this.verificationExpiry,
      retryCount: retryCount ?? this.retryCount,
      supportingDocuments: supportingDocuments ?? this.supportingDocuments,
    );
  }

  /// Doğrulama kodu geçerli mi?
  bool get isVerificationCodeValid {
    if (verificationExpiry == null) return false;
    return DateTime.now().isBefore(verificationExpiry!);
  }

  /// Talep süresi doldu mu?
  bool get isExpired {
    final expiryDate = requestedAt.add(Duration(days: 30));
    return DateTime.now().isAfter(expiryDate);
  }
}
