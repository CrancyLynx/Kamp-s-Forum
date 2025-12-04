import 'package:cloud_firestore/cloud_firestore.dart';

/// Vision API Kota Sistemi - Google Vision API kullanım izleme
class VisionQuota {
  final String id;
  final String monthYear; // "2024-01" format
  final int totalRequests;
  final int usedRequests;
  final int remainingRequests;
  final double costPerRequest;
  final double totalCost;
  final double monthlyBudget;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isLimited;
  final int requestsPerDay;
  final int currentDayRequests;
  final DateTime lastResetDate;

  VisionQuota({
    required this.id,
    required this.monthYear,
    required this.totalRequests,
    required this.usedRequests,
    required this.remainingRequests,
    required this.costPerRequest,
    required this.totalCost,
    required this.monthlyBudget,
    required this.createdAt,
    this.updatedAt,
    required this.isLimited,
    required this.requestsPerDay,
    required this.currentDayRequests,
    required this.lastResetDate,
  });

  factory VisionQuota.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisionQuota(
      id: doc.id,
      monthYear: data['monthYear'] ?? '',
      totalRequests: (data['totalRequests'] ?? 10000).toInt(),
      usedRequests: (data['usedRequests'] ?? 0).toInt(),
      remainingRequests: (data['remainingRequests'] ?? 10000).toInt(),
      costPerRequest: (data['costPerRequest'] ?? 0.0).toDouble(),
      totalCost: (data['totalCost'] ?? 0.0).toDouble(),
      monthlyBudget: (data['monthlyBudget'] ?? 100.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isLimited: data['isLimited'] ?? true,
      requestsPerDay: (data['requestsPerDay'] ?? 1000).toInt(),
      currentDayRequests: (data['currentDayRequests'] ?? 0).toInt(),
      lastResetDate: (data['lastResetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'monthYear': monthYear,
      'totalRequests': totalRequests,
      'usedRequests': usedRequests,
      'remainingRequests': remainingRequests,
      'costPerRequest': costPerRequest,
      'totalCost': totalCost,
      'monthlyBudget': monthlyBudget,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isLimited': isLimited,
      'requestsPerDay': requestsPerDay,
      'currentDayRequests': currentDayRequests,
      'lastResetDate': Timestamp.fromDate(lastResetDate),
    };
  }

  VisionQuota copyWith({
    String? id,
    String? monthYear,
    int? totalRequests,
    int? usedRequests,
    int? remainingRequests,
    double? costPerRequest,
    double? totalCost,
    double? monthlyBudget,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isLimited,
    int? requestsPerDay,
    int? currentDayRequests,
    DateTime? lastResetDate,
  }) {
    return VisionQuota(
      id: id ?? this.id,
      monthYear: monthYear ?? this.monthYear,
      totalRequests: totalRequests ?? this.totalRequests,
      usedRequests: usedRequests ?? this.usedRequests,
      remainingRequests: remainingRequests ?? this.remainingRequests,
      costPerRequest: costPerRequest ?? this.costPerRequest,
      totalCost: totalCost ?? this.totalCost,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLimited: isLimited ?? this.isLimited,
      requestsPerDay: requestsPerDay ?? this.requestsPerDay,
      currentDayRequests: currentDayRequests ?? this.currentDayRequests,
      lastResetDate: lastResetDate ?? this.lastResetDate,
    );
  }

  /// Kullanılan yüzde
  double get usagePercentage => (usedRequests / totalRequests) * 100;

  /// Günlük limit kalanı
  bool get isDailyLimitExceeded => currentDayRequests >= requestsPerDay;

  /// Bütçe kalanı
  double get budgetRemaining => monthlyBudget - totalCost;

  /// Bütçe aşıldı mı
  bool get isBudgetExceeded => totalCost >= monthlyBudget;
}

/// Vision API Kullanım Kaydı
class VisionUsageLog {
  final String id;
  final String featureId;
  final String featureName;
  final String imagePath;
  final String analysisType; // "OCR", "LABEL_DETECTION", "FACE_DETECTION", etc.
  final double cost;
  final int tokensUsed;
  final DateTime createdAt;
  final bool success;
  final String? errorMessage;

  VisionUsageLog({
    required this.id,
    required this.featureId,
    required this.featureName,
    required this.imagePath,
    required this.analysisType,
    required this.cost,
    required this.tokensUsed,
    required this.createdAt,
    required this.success,
    this.errorMessage,
  });

  factory VisionUsageLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisionUsageLog(
      id: doc.id,
      featureId: data['featureId'] ?? '',
      featureName: data['featureName'] ?? '',
      imagePath: data['imagePath'] ?? '',
      analysisType: data['analysisType'] ?? '',
      cost: (data['cost'] ?? 0.0).toDouble(),
      tokensUsed: (data['tokensUsed'] ?? 0).toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      success: data['success'] ?? false,
      errorMessage: data['errorMessage'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'featureId': featureId,
      'featureName': featureName,
      'imagePath': imagePath,
      'analysisType': analysisType,
      'cost': cost,
      'tokensUsed': tokensUsed,
      'createdAt': Timestamp.fromDate(createdAt),
      'success': success,
      'errorMessage': errorMessage,
    };
  }
}
