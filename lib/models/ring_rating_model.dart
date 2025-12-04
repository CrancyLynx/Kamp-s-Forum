import 'package:cloud_firestore/cloud_firestore.dart';

/// Ring Sefer Rating
class SeferRating {
  final String id;
  final String seferId;
  final String driverId;
  final String driverName;
  final String passengerIds; // Virgülle ayrılmış
  final double rating; // 1-5
  final String comment;
  final DateTime createdAt;
  final Map<String, dynamic> categories; // Güvenlik, temizlik, vs.

  SeferRating({
    required this.id,
    required this.seferId,
    required this.driverId,
    required this.driverName,
    required this.passengerIds,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.categories,
  });

  factory SeferRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SeferRating(
      id: doc.id,
      seferId: data['seferId'] ?? '',
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? 'Sürücü',
      passengerIds: data['passengerIds'] ?? '',
      rating: (data['rating'] ?? 5.0).toDouble(),
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categories: data['categories'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'seferId': seferId,
      'driverId': driverId,
      'driverName': driverName,
      'passengerIds': passengerIds,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'categories': categories,
    };
  }
}

/// Ring Sürücü İstatistikleri
class DriverStats {
  final String driverId;
  final String driverName;
  final double averageRating;
  final int totalRatings;
  final int totalCompletedSefers;
  final int totalPassengers;
  final double cancellationRate;
  final DateTime memberSince;
  final Map<String, double> categoryAverages; // Güvenlik, temizlik, vs.

  DriverStats({
    required this.driverId,
    required this.driverName,
    required this.averageRating,
    required this.totalRatings,
    required this.totalCompletedSefers,
    required this.totalPassengers,
    required this.cancellationRate,
    required this.memberSince,
    required this.categoryAverages,
  });

  factory DriverStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DriverStats(
      driverId: doc.id,
      driverName: data['driverName'] ?? 'Sürücü',
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      totalRatings: (data['totalRatings'] ?? 0).toInt(),
      totalCompletedSefers: (data['totalCompletedSefers'] ?? 0).toInt(),
      totalPassengers: (data['totalPassengers'] ?? 0).toInt(),
      cancellationRate: (data['cancellationRate'] ?? 0.0).toDouble(),
      memberSince: (data['memberSince'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categoryAverages: Map<String, double>.from(
          data['categoryAverages']?.cast<String, double>() ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'driverName': driverName,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'totalCompletedSefers': totalCompletedSefers,
      'totalPassengers': totalPassengers,
      'cancellationRate': cancellationRate,
      'memberSince': Timestamp.fromDate(memberSince),
      'categoryAverages': categoryAverages,
    };
  }

  bool isTrustedDriver() {
    return averageRating >= 4.5 && totalRatings >= 10;
  }

  String getRatingBadge() {
    if (averageRating >= 4.8) return '⭐⭐⭐⭐⭐';
    if (averageRating >= 4.5) return '⭐⭐⭐⭐';
    if (averageRating >= 4.0) return '⭐⭐⭐';
    if (averageRating >= 3.5) return '⭐⭐';
    return '⭐';
  }
}

/// Ring Sefer Komplenti (Şikayet)
class SeferComplaint {
  final String id;
  final String seferId;
  final String complainantId;
  final String complainantName;
  final String defendantId;
  final String defendantName;
  final String complaintType; // "rude", "unsafe", "dirty", "other"
  final String description;
  final DateTime createdAt;
  final String status; // "open", "investigating", "resolved", "dismissed"
  final String? resolution;

  SeferComplaint({
    required this.id,
    required this.seferId,
    required this.complainantId,
    required this.complainantName,
    required this.defendantId,
    required this.defendantName,
    required this.complaintType,
    required this.description,
    required this.createdAt,
    required this.status,
    this.resolution,
  });

  factory SeferComplaint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SeferComplaint(
      id: doc.id,
      seferId: data['seferId'] ?? '',
      complainantId: data['complainantId'] ?? '',
      complainantName: data['complainantName'] ?? 'Kullanıcı',
      defendantId: data['defendantId'] ?? '',
      defendantName: data['defendantName'] ?? 'Kullanıcı',
      complaintType: data['complaintType'] ?? 'other',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'open',
      resolution: data['resolution'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'seferId': seferId,
      'complainantId': complainantId,
      'complainantName': complainantName,
      'defendantId': defendantId,
      'defendantName': defendantName,
      'complaintType': complaintType,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'resolution': resolution,
    };
  }

  bool isResolved() {
    return status == 'resolved' || status == 'dismissed';
  }
}
