import 'package:cloud_firestore/cloud_firestore.dart';

/// Geri Bildirim Sistemi
class Feedback {
  final String id;
  final String userId;
  final String userName;
  final String? userEmail;
  final String feedbackType; // "bug", "suggestion", "complaint", "praise"
  final String subject;
  final String message;
  final String category;
  final List<String> attachmentUrls;
  final int rating; // 1-5
  final DateTime createdAt;
  final String status; // "new", "in_review", "responded", "resolved", "closed"
  final String? response;
  final String? respondedBy;
  final DateTime? respondedAt;
  final bool isAnonymous;
  final int viewCount;
  final Map<String, dynamic> metadata;

  Feedback({
    required this.id,
    required this.userId,
    required this.userName,
    this.userEmail,
    required this.feedbackType,
    required this.subject,
    required this.message,
    required this.category,
    required this.attachmentUrls,
    required this.rating,
    required this.createdAt,
    required this.status,
    this.response,
    this.respondedBy,
    this.respondedAt,
    required this.isAnonymous,
    required this.viewCount,
    required this.metadata,
  });

  factory Feedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Feedback(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'],
      feedbackType: data['feedbackType'] ?? 'suggestion',
      subject: data['subject'] ?? '',
      message: data['message'] ?? '',
      category: data['category'] ?? 'general',
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      rating: (data['rating'] ?? 0).toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'new',
      response: data['response'],
      respondedBy: data['respondedBy'],
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      isAnonymous: data['isAnonymous'] ?? false,
      viewCount: (data['viewCount'] ?? 0).toInt(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'feedbackType': feedbackType,
      'subject': subject,
      'message': message,
      'category': category,
      'attachmentUrls': attachmentUrls,
      'rating': rating,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'response': response,
      'respondedBy': respondedBy,
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'isAnonymous': isAnonymous,
      'viewCount': viewCount,
      'metadata': metadata,
    };
  }

  Feedback copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? feedbackType,
    String? subject,
    String? message,
    String? category,
    List<String>? attachmentUrls,
    int? rating,
    DateTime? createdAt,
    String? status,
    String? response,
    String? respondedBy,
    DateTime? respondedAt,
    bool? isAnonymous,
    int? viewCount,
    Map<String, dynamic>? metadata,
  }) {
    return Feedback(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      feedbackType: feedbackType ?? this.feedbackType,
      subject: subject ?? this.subject,
      message: message ?? this.message,
      category: category ?? this.category,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      response: response ?? this.response,
      respondedBy: respondedBy ?? this.respondedBy,
      respondedAt: respondedAt ?? this.respondedAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      viewCount: viewCount ?? this.viewCount,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Yanıt alınmış mı?
  bool get hasResponse => response != null && response!.isNotEmpty;

  /// Yeni geri bildirim mi?
  bool get isNew => status == 'new';
}

/// Feedback Özeti
class FeedbackSummary {
  final int totalFeedback;
  final int bugReports;
  final int suggestions;
  final int complaints;
  final int praise;
  final double averageRating;
  final int resolvedCount;
  final int pendingCount;
  final DateTime period;

  FeedbackSummary({
    required this.totalFeedback,
    required this.bugReports,
    required this.suggestions,
    required this.complaints,
    required this.praise,
    required this.averageRating,
    required this.resolvedCount,
    required this.pendingCount,
    required this.period,
  });

  factory FeedbackSummary.fromMap(Map<String, dynamic> data) {
    return FeedbackSummary(
      totalFeedback: (data['totalFeedback'] ?? 0).toInt(),
      bugReports: (data['bugReports'] ?? 0).toInt(),
      suggestions: (data['suggestions'] ?? 0).toInt(),
      complaints: (data['complaints'] ?? 0).toInt(),
      praise: (data['praise'] ?? 0).toInt(),
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      resolvedCount: (data['resolvedCount'] ?? 0).toInt(),
      pendingCount: (data['pendingCount'] ?? 0).toInt(),
      period: (data['period'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  double get resolutionRate {
    if (totalFeedback == 0) return 0;
    return (resolvedCount / totalFeedback) * 100;
  }
}
