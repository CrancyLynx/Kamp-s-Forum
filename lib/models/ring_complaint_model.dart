import 'package:cloud_firestore/cloud_firestore.dart';

/// Halka Şikayetleri Sistemi
class RingComplaint {
  final String id;
  final String ringId;
  final String ringName;
  final String complaintType; // "behavior", "moderation", "fraud", "spam", "harassment", "other"
  final String complainantId;
  final String complainantName;
  final String targetUserId;
  final String targetUserName;
  final String subject;
  final String description;
  final List<String> evidenceUrls;
  final DateTime submittedAt;
  final String status; // "new", "under_review", "resolved", "dismissed"
  final int priority; // 1-5
  final String? reviewedBy;
  final String? reviewerName;
  final DateTime? reviewedAt;
  final String? resolution;
  final String? resolutionDetails;
  final bool hasConsequences;
  final List<String> consequences; // Yapılan işlemler
  final int similarComplaints; // Benzer şikayetler
  final List<String> tags;
  final Map<String, dynamic> metadata;

  RingComplaint({
    required this.id,
    required this.ringId,
    required this.ringName,
    required this.complaintType,
    required this.complainantId,
    required this.complainantName,
    required this.targetUserId,
    required this.targetUserName,
    required this.subject,
    required this.description,
    required this.evidenceUrls,
    required this.submittedAt,
    required this.status,
    required this.priority,
    this.reviewedBy,
    this.reviewerName,
    this.reviewedAt,
    this.resolution,
    this.resolutionDetails,
    required this.hasConsequences,
    required this.consequences,
    required this.similarComplaints,
    required this.tags,
    required this.metadata,
  });

  factory RingComplaint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RingComplaint(
      id: doc.id,
      ringId: data['ringId'] ?? '',
      ringName: data['ringName'] ?? '',
      complaintType: data['complaintType'] ?? 'other',
      complainantId: data['complainantId'] ?? '',
      complainantName: data['complainantName'] ?? '',
      targetUserId: data['targetUserId'] ?? '',
      targetUserName: data['targetUserName'] ?? '',
      subject: data['subject'] ?? '',
      description: data['description'] ?? '',
      evidenceUrls: List<String>.from(data['evidenceUrls'] ?? []),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'new',
      priority: (data['priority'] ?? 1).toInt(),
      reviewedBy: data['reviewedBy'],
      reviewerName: data['reviewerName'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      resolution: data['resolution'],
      resolutionDetails: data['resolutionDetails'],
      hasConsequences: data['hasConsequences'] ?? false,
      consequences: List<String>.from(data['consequences'] ?? []),
      similarComplaints: (data['similarComplaints'] ?? 0).toInt(),
      tags: List<String>.from(data['tags'] ?? []),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ringId': ringId,
      'ringName': ringName,
      'complaintType': complaintType,
      'complainantId': complainantId,
      'complainantName': complainantName,
      'targetUserId': targetUserId,
      'targetUserName': targetUserName,
      'subject': subject,
      'description': description,
      'evidenceUrls': evidenceUrls,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'status': status,
      'priority': priority,
      'reviewedBy': reviewedBy,
      'reviewerName': reviewerName,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'resolution': resolution,
      'resolutionDetails': resolutionDetails,
      'hasConsequences': hasConsequences,
      'consequences': consequences,
      'similarComplaints': similarComplaints,
      'tags': tags,
      'metadata': metadata,
    };
  }

  RingComplaint copyWith({
    String? id,
    String? ringId,
    String? ringName,
    String? complaintType,
    String? complainantId,
    String? complainantName,
    String? targetUserId,
    String? targetUserName,
    String? subject,
    String? description,
    List<String>? evidenceUrls,
    DateTime? submittedAt,
    String? status,
    int? priority,
    String? reviewedBy,
    String? reviewerName,
    DateTime? reviewedAt,
    String? resolution,
    String? resolutionDetails,
    bool? hasConsequences,
    List<String>? consequences,
    int? similarComplaints,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return RingComplaint(
      id: id ?? this.id,
      ringId: ringId ?? this.ringId,
      ringName: ringName ?? this.ringName,
      complaintType: complaintType ?? this.complaintType,
      complainantId: complainantId ?? this.complainantId,
      complainantName: complainantName ?? this.complainantName,
      targetUserId: targetUserId ?? this.targetUserId,
      targetUserName: targetUserName ?? this.targetUserName,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      evidenceUrls: evidenceUrls ?? this.evidenceUrls,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      resolution: resolution ?? this.resolution,
      resolutionDetails: resolutionDetails ?? this.resolutionDetails,
      hasConsequences: hasConsequences ?? this.hasConsequences,
      consequences: consequences ?? this.consequences,
      similarComplaints: similarComplaints ?? this.similarComplaints,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Acil mi?
  bool get isUrgent => priority >= 4;

  /// Zaman aşımı değilmi? (30 gün)
  bool get isExpired {
    final expiryDate = submittedAt.add(Duration(days: 30));
    return DateTime.now().isAfter(expiryDate);
  }

  /// Çözüldü mü?
  bool get isResolved => status == 'resolved';

  /// İncelemede mi?
  bool get isUnderReview => status == 'under_review';

  /// Tekrar eden şikayet mi?
  bool get isRecurring => similarComplaints > 2;
}

/// Halka Şikayet İstatistikleri
class RingComplaintStatistics {
  final String ringId;
  final int totalComplaints;
  final int unresolvedComplaints;
  final int resolvedComplaints;
  final Map<String, int> complaintsByType;
  final String mostCommonComplaint;
  final List<String> frequentTargets;
  final DateTime period;
  final double resolutionRate;

  RingComplaintStatistics({
    required this.ringId,
    required this.totalComplaints,
    required this.unresolvedComplaints,
    required this.resolvedComplaints,
    required this.complaintsByType,
    required this.mostCommonComplaint,
    required this.frequentTargets,
    required this.period,
    required this.resolutionRate,
  });

  factory RingComplaintStatistics.fromMap(Map<String, dynamic> data) {
    return RingComplaintStatistics(
      ringId: data['ringId'] ?? '',
      totalComplaints: (data['totalComplaints'] ?? 0).toInt(),
      unresolvedComplaints: (data['unresolvedComplaints'] ?? 0).toInt(),
      resolvedComplaints: (data['resolvedComplaints'] ?? 0).toInt(),
      complaintsByType: Map<String, int>.from(data['complaintsByType'] ?? {}),
      mostCommonComplaint: data['mostCommonComplaint'] ?? '',
      frequentTargets: List<String>.from(data['frequentTargets'] ?? []),
      period: (data['period'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolutionRate: (data['resolutionRate'] ?? 0.0).toDouble(),
    );
  }

  int get pendingComplaints => totalComplaints - resolvedComplaints;

  bool get hasHighComplaints => totalComplaints > 10;

  bool get hasLowResolutionRate => resolutionRate < 50;
}
