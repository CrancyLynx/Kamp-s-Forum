import 'package:cloud_firestore/cloud_firestore.dart';

/// Halka Fotoğrafı Onay Sistemi
class RingPhotoApproval {
  final String id;
  final String photoUrl;
  final String userId;
  final String userName;
  final String userEmail;
  final String ringId;
  final String ringName;
  final String category; // "profile", "cover", "post", "event"
  final String description;
  final DateTime submittedAt;
  final String status; // "pending", "approved", "rejected", "flagged"
  final String? reason;
  final String? reviewedBy;
  final String? reviewNote;
  final DateTime? reviewedAt;
  final int reportCount;
  final List<String> reportReasons;
  final Map<String, dynamic> metadata;

  RingPhotoApproval({
    required this.id,
    required this.photoUrl,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.ringId,
    required this.ringName,
    required this.category,
    required this.description,
    required this.submittedAt,
    required this.status,
    this.reason,
    this.reviewedBy,
    this.reviewNote,
    this.reviewedAt,
    required this.reportCount,
    required this.reportReasons,
    required this.metadata,
  });

  factory RingPhotoApproval.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RingPhotoApproval(
      id: doc.id,
      photoUrl: data['photoUrl'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      ringId: data['ringId'] ?? '',
      ringName: data['ringName'] ?? '',
      category: data['category'] ?? 'post',
      description: data['description'] ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      reason: data['reason'],
      reviewedBy: data['reviewedBy'],
      reviewNote: data['reviewNote'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reportCount: (data['reportCount'] ?? 0).toInt(),
      reportReasons: List<String>.from(data['reportReasons'] ?? []),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'photoUrl': photoUrl,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'ringId': ringId,
      'ringName': ringName,
      'category': category,
      'description': description,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'status': status,
      'reason': reason,
      'reviewedBy': reviewedBy,
      'reviewNote': reviewNote,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reportCount': reportCount,
      'reportReasons': reportReasons,
      'metadata': metadata,
    };
  }

  RingPhotoApproval copyWith({
    String? id,
    String? photoUrl,
    String? userId,
    String? userName,
    String? userEmail,
    String? ringId,
    String? ringName,
    String? category,
    String? description,
    DateTime? submittedAt,
    String? status,
    String? reason,
    String? reviewedBy,
    String? reviewNote,
    DateTime? reviewedAt,
    int? reportCount,
    List<String>? reportReasons,
    Map<String, dynamic>? metadata,
  }) {
    return RingPhotoApproval(
      id: id ?? this.id,
      photoUrl: photoUrl ?? this.photoUrl,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      ringId: ringId ?? this.ringId,
      ringName: ringName ?? this.ringName,
      category: category ?? this.category,
      description: description ?? this.description,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewNote: reviewNote ?? this.reviewNote,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reportCount: reportCount ?? this.reportCount,
      reportReasons: reportReasons ?? this.reportReasons,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Onay bekleyen mi?
  bool get isPending => status == 'pending';

  /// Onanmış mı?
  bool get isApproved => status == 'approved';

  /// Reddedilmiş mi?
  bool get isRejected => status == 'rejected';

  /// Bayrak konulmuş mu?
  bool get isFlagged => reportCount > 3;
}

/// Fotoğraf İncelemesi
class PhotoReview {
  final String id;
  final String approvalId;
  final String reviewerId;
  final String reviewerName;
  final String decision; // "approved", "rejected"
  final String reason;
  final String note;
  final DateTime createdAt;
  final Map<String, dynamic> reviewDetails;

  PhotoReview({
    required this.id,
    required this.approvalId,
    required this.reviewerId,
    required this.reviewerName,
    required this.decision,
    required this.reason,
    required this.note,
    required this.createdAt,
    required this.reviewDetails,
  });

  factory PhotoReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PhotoReview(
      id: doc.id,
      approvalId: data['approvalId'] ?? '',
      reviewerId: data['reviewerId'] ?? '',
      reviewerName: data['reviewerName'] ?? '',
      decision: data['decision'] ?? '',
      reason: data['reason'] ?? '',
      note: data['note'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewDetails: Map<String, dynamic>.from(data['reviewDetails'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'approvalId': approvalId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'decision': decision,
      'reason': reason,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewDetails': reviewDetails,
    };
  }
}
