import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// PHASE 4 - İLERİ ÖZELLİKLER MODELLERI
// Tüm Türkiye'ye açık, üniversiteye özel sistemler
// ============================================================

// ============================================================
// 1. RIDE ŞİKAYETLERİ (Sürüş Güvenliği)
// ============================================================
class RideComplaint {
  final String id;
  final String ringId;
  final String seferId;
  final String complainantUserId;
  final String complainantName;
  final String driverId;
  final String driverName;
  final String universityName;
  final String category;
  final String description;
  final int severity;
  final List<String> witnessIds;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolutionNote;

  RideComplaint({
    required this.id,
    required this.ringId,
    required this.seferId,
    required this.complainantUserId,
    required this.complainantName,
    required this.driverId,
    required this.driverName,
    required this.universityName,
    required this.category,
    required this.description,
    required this.severity,
    this.witnessIds = const [],
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.resolutionNote,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'ringId': ringId,
      'seferId': seferId,
      'complainantUserId': complainantUserId,
      'complainantName': complainantName,
      'driverId': driverId,
      'driverName': driverName,
      'universityName': universityName,
      'category': category,
      'description': description,
      'severity': severity,
      'witnessIds': witnessIds,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolutionNote': resolutionNote,
    };
  }

  factory RideComplaint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RideComplaint(
      id: doc.id,
      ringId: data['ringId'] ?? '',
      seferId: data['seferId'] ?? '',
      complainantUserId: data['complainantUserId'] ?? '',
      complainantName: data['complainantName'] ?? '',
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      universityName: data['universityName'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      severity: data['severity'] ?? 1,
      witnessIds: List<String>.from(data['witnessIds'] ?? []),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      resolutionNote: data['resolutionNote'],
    );
  }
}

// ============================================================
// 2. PUAN SİSTEMİ (Leveling, Experience)
// ============================================================
class UserPoints {
  final String userId;
  final String userName;
  final String universityName;
  final int totalPoints;
  final int level;
  final int nextLevelRequirement;
  final DateTime lastPointUpdateAt;
  final Map<String, int> pointsByCategory;

  UserPoints({
    required this.userId,
    required this.userName,
    required this.universityName,
    required this.totalPoints,
    required this.level,
    required this.nextLevelRequirement,
    required this.lastPointUpdateAt,
    this.pointsByCategory = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userName': userName,
      'universityName': universityName,
      'totalPoints': totalPoints,
      'level': level,
      'nextLevelRequirement': nextLevelRequirement,
      'lastPointUpdateAt': Timestamp.fromDate(lastPointUpdateAt),
      'pointsByCategory': pointsByCategory,
    };
  }

  factory UserPoints.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserPoints(
      userId: doc.id,
      userName: data['userName'] ?? '',
      universityName: data['universityName'] ?? '',
      totalPoints: data['totalPoints'] ?? 0,
      level: data['level'] ?? 1,
      nextLevelRequirement: data['nextLevelRequirement'] ?? 100,
      lastPointUpdateAt: (data['lastPointUpdateAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pointsByCategory: Map<String, int>.from(data['pointsByCategory'] ?? {}),
    );
  }
}

// ============================================================
// 3. BAŞARILAR (Achievements)
// ============================================================
class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final int pointReward;
  final String category;
  final String rarity;
  final bool isSecret;
  final DateTime createdAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.pointReward,
    required this.category,
    required this.rarity,
    required this.isSecret,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'emoji': emoji,
      'pointReward': pointReward,
      'category': category,
      'rarity': rarity,
      'isSecret': isSecret,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Achievement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Achievement(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      emoji: data['emoji'] ?? '⭐',
      pointReward: data['pointReward'] ?? 0,
      category: data['category'] ?? 'general',
      rarity: data['rarity'] ?? 'common',
      isSecret: data['isSecret'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class UserAchievement {
  final String userId;
  final String achievementId;
  final String achievementTitle;
  final String achievementEmoji;
  final DateTime unlockedAt;

  UserAchievement({
    required this.userId,
    required this.achievementId,
    required this.achievementTitle,
    required this.achievementEmoji,
    required this.unlockedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'achievementId': achievementId,
      'achievementTitle': achievementTitle,
      'achievementEmoji': achievementEmoji,
      'unlockedAt': Timestamp.fromDate(unlockedAt),
    };
  }

  factory UserAchievement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserAchievement(
      userId: doc.id,
      achievementId: data['achievementId'] ?? '',
      achievementTitle: data['achievementTitle'] ?? '',
      achievementEmoji: data['achievementEmoji'] ?? '⭐',
      unlockedAt: (data['unlockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ============================================================
// 4. ÖDÜLLER (Rewards Shop)
// ============================================================
class Reward {
  final String id;
  final String title;
  final String description;
  final int pointCost;
  final String category;
  final String type;
  final String emoji;
  final int stock;
  final DateTime createdAt;
  final bool isActive;

  Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.pointCost,
    required this.category,
    required this.type,
    required this.emoji,
    required this.stock,
    required this.createdAt,
    required this.isActive,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'pointCost': pointCost,
      'category': category,
      'type': type,
      'emoji': emoji,
      'stock': stock,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  factory Reward.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reward(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      pointCost: data['pointCost'] ?? 0,
      category: data['category'] ?? 'general',
      type: data['type'] ?? 'badge',
      emoji: data['emoji'] ?? '🎁',
      stock: data['stock'] ?? -1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }
}

class UserRewardPurchase {
  final String id;
  final String userId;
  final String userName;
  final String universityName;
  final String rewardId;
  final String rewardTitle;
  final int pointsSpent;
  final DateTime purchasedAt;

  UserRewardPurchase({
    required this.id,
    required this.userId,
    required this.userName,
    required this.universityName,
    required this.rewardId,
    required this.rewardTitle,
    required this.pointsSpent,
    required this.purchasedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'universityName': universityName,
      'rewardId': rewardId,
      'rewardTitle': rewardTitle,
      'pointsSpent': pointsSpent,
      'purchasedAt': Timestamp.fromDate(purchasedAt),
    };
  }

  factory UserRewardPurchase.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserRewardPurchase(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      universityName: data['universityName'] ?? '',
      rewardId: data['rewardId'] ?? '',
      rewardTitle: data['rewardTitle'] ?? '',
      pointsSpent: data['pointsSpent'] ?? 0,
      purchasedAt: (data['purchasedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ============================================================
// 5. ARAMA ANALİZİ (Search Analytics)
// ============================================================
class SearchQuery {
  final String id;
  final String universityName;
  final String query;
  final String category;
  final int resultCount;
  final DateTime searchedAt;

  SearchQuery({
    required this.id,
    required this.universityName,
    required this.query,
    required this.category,
    required this.resultCount,
    required this.searchedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'universityName': universityName,
      'query': query,
      'category': category,
      'resultCount': resultCount,
      'searchedAt': Timestamp.fromDate(searchedAt),
    };
  }

  factory SearchQuery.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SearchQuery(
      id: doc.id,
      universityName: data['universityName'] ?? '',
      query: data['query'] ?? '',
      category: data['category'] ?? 'general',
      resultCount: data['resultCount'] ?? 0,
      searchedAt: (data['searchedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class SearchTrend {
  final String id;
  final String universityName;
  final String query;
  final int searchCount;
  final int trendScore;
  final DateTime periodStart;
  final DateTime periodEnd;

  SearchTrend({
    required this.id,
    required this.universityName,
    required this.query,
    required this.searchCount,
    required this.trendScore,
    required this.periodStart,
    required this.periodEnd,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'universityName': universityName,
      'query': query,
      'searchCount': searchCount,
      'trendScore': trendScore,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
    };
  }

  factory SearchTrend.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SearchTrend(
      id: doc.id,
      universityName: data['universityName'] ?? '',
      query: data['query'] ?? '',
      searchCount: data['searchCount'] ?? 0,
      trendScore: data['trendScore'] ?? 0,
      periodStart: (data['periodStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodEnd: (data['periodEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ============================================================
// 6. AI İSTATİSTİK (Model Metrics)
// ============================================================
class AIModelMetrics {
  final String id;
  final String modelName;
  final String universityName;
  final double accuracy;
  final double precision;
  final double recall;
  final int totalPredictions;
  final int correctPredictions;
  final double averageResponseTime;
  final DateTime measuredAt;

  AIModelMetrics({
    required this.id,
    required this.modelName,
    required this.universityName,
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.totalPredictions,
    required this.correctPredictions,
    required this.averageResponseTime,
    required this.measuredAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'modelName': modelName,
      'universityName': universityName,
      'accuracy': accuracy,
      'precision': precision,
      'recall': recall,
      'totalPredictions': totalPredictions,
      'correctPredictions': correctPredictions,
      'averageResponseTime': averageResponseTime,
      'measuredAt': Timestamp.fromDate(measuredAt),
    };
  }

  factory AIModelMetrics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AIModelMetrics(
      id: doc.id,
      modelName: data['modelName'] ?? '',
      universityName: data['universityName'] ?? '',
      accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0.0,
      precision: (data['precision'] as num?)?.toDouble() ?? 0.0,
      recall: (data['recall'] as num?)?.toDouble() ?? 0.0,
      totalPredictions: data['totalPredictions'] ?? 0,
      correctPredictions: data['correctPredictions'] ?? 0,
      averageResponseTime: (data['averageResponseTime'] as num?)?.toDouble() ?? 0.0,
      measuredAt: (data['measuredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ============================================================
// 7. FİNANSAL RAPOR (Financial Analytics)
// ============================================================
class FinancialRecord {
  final String id;
  final String universityName;
  final String type;
  final String category;
  final double amount;
  final String description;
  final DateTime recordedAt;
  final String status;

  FinancialRecord({
    required this.id,
    required this.universityName,
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    required this.recordedAt,
    required this.status,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'universityName': universityName,
      'type': type,
      'category': category,
      'amount': amount,
      'description': description,
      'recordedAt': Timestamp.fromDate(recordedAt),
      'status': status,
    };
  }

  factory FinancialRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FinancialRecord(
      id: doc.id,
      universityName: data['universityName'] ?? '',
      type: data['type'] ?? 'transaction',
      category: data['category'] ?? 'general',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      description: data['description'] ?? '',
      recordedAt: (data['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }
}

class FinancialSummary {
  final String id;
  final String universityName;
  final double totalIncome;
  final double totalExpense;
  final double netProfit;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<String, double> incomeByCategory;
  final Map<String, double> expenseByCategory;

  FinancialSummary({
    required this.id,
    required this.universityName,
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.periodStart,
    required this.periodEnd,
    this.incomeByCategory = const {},
    this.expenseByCategory = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'universityName': universityName,
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'netProfit': netProfit,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'incomeByCategory': incomeByCategory,
      'expenseByCategory': expenseByCategory,
    };
  }

  factory FinancialSummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FinancialSummary(
      id: doc.id,
      universityName: data['universityName'] ?? '',
      totalIncome: (data['totalIncome'] as num?)?.toDouble() ?? 0.0,
      totalExpense: (data['totalExpense'] as num?)?.toDouble() ?? 0.0,
      netProfit: (data['netProfit'] as num?)?.toDouble() ?? 0.0,
      periodStart: (data['periodStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodEnd: (data['periodEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      incomeByCategory: Map<String, double>.from(
        (data['incomeByCategory'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0),
            ) ?? {},
      ),
      expenseByCategory: Map<String, double>.from(
        (data['expenseByCategory'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0),
            ) ?? {},
      ),
    );
  }
}
