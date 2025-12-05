import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/phase4_models.dart';

// ============================================================
// PHASE 4 - SERVİSLER
// Tüm Türkiye'ye açık, üniversiteye özel veri filtreleme
// ============================================================

class Phase4Services {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // 1. RIDE ŞİKAYETLERİ SERVİSİ
  // ============================================================
  
  Future<String> createRideComplaint({
    required String ringId,
    required String seferId,
    required String complainantUserId,
    required String complainantName,
    required String driverId,
    required String driverName,
    required String universityName,
    required String category,
    required String description,
    required int severity,
    List<String> witnessIds = const [],
  }) async {
    try {
      final docRef = await _firestore.collection('ride_complaints').add({
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
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'resolutionNote': null,
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Şikayet oluşturulamadı: $e');
    }
  }

  Stream<List<RideComplaint>> getRideComplaintsByUniversity(String universityName) {
    return _firestore
        .collection('ride_complaints')
        .where('universityName', isEqualTo: universityName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideComplaint.fromFirestore(doc))
            .toList());
  }

  Future<void> updateRideComplaintStatus({
    required String complaintId,
    required String status,
    String? resolutionNote,
  }) async {
    try {
      await _firestore.collection('ride_complaints').doc(complaintId).update({
        'status': status,
        'resolutionNote': resolutionNote,
        if (status == 'resolved') 'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Şikayet güncellenemedi: $e');
    }
  }

  // ============================================================
  // 2. PUAN SİSTEMİ SERVİSİ
  // ============================================================
  
  Future<UserPoints> getUserPoints({
    required String userId,
    required String universityName,
  }) async {
    try {
      final doc = await _firestore.collection('user_points').doc(userId).get();
      if (doc.exists) {
        return UserPoints.fromFirestore(doc);
      } else {
        final newPoints = UserPoints(
          userId: userId,
          userName: '',
          universityName: universityName,
          totalPoints: 0,
          level: 1,
          nextLevelRequirement: 100,
          lastPointUpdateAt: DateTime.now(),
        );
        await doc.reference.set(newPoints.toFirestore());
        return newPoints;
      }
    } catch (e) {
      throw Exception('Puanlar getirilemedi: $e');
    }
  }

  Future<void> addPoints({
    required String userId,
    required int points,
    required String category,
  }) async {
    try {
      final docRef = _firestore.collection('user_points').doc(userId);
      await docRef.update({
        'totalPoints': FieldValue.increment(points),
        'pointsByCategory.$category': FieldValue.increment(points),
        'lastPointUpdateAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Puan eklenemedi: $e');
    }
  }

  Stream<List<UserPoints>> getUniversityLeaderboard(String universityName) {
    return _firestore
        .collection('user_points')
        .where('universityName', isEqualTo: universityName)
        .orderBy('totalPoints', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserPoints.fromFirestore(doc))
            .toList());
  }

  // ============================================================
  // 3. BAŞARILAR SERVİSİ
  // ============================================================
  
  Stream<List<Achievement>> getAchievements() {
    return _firestore
        .collection('achievements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Achievement.fromFirestore(doc))
            .toList());
  }

  Stream<List<UserAchievement>> getUserAchievements(String userId) {
    return _firestore
        .collection('user_achievements')
        .doc(userId)
        .collection('achievements')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserAchievement.fromFirestore(doc))
            .toList());
  }

  Future<void> unlockAchievement({
    required String userId,
    required String achievementId,
    required String achievementTitle,
    required String achievementEmoji,
  }) async {
    try {
      await _firestore
          .collection('user_achievements')
          .doc(userId)
          .collection('achievements')
          .add({
        'achievementId': achievementId,
        'achievementTitle': achievementTitle,
        'achievementEmoji': achievementEmoji,
        'unlockedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Başarı kilidi açılamadı: $e');
    }
  }

  // ============================================================
  // 4. ÖDÜLLER SERVİSİ
  // ============================================================
  
  Stream<List<Reward>> getActiveRewards() {
    return _firestore
        .collection('rewards')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Reward.fromFirestore(doc))
            .toList());
  }

  Future<void> purchaseReward({
    required String userId,
    required String userName,
    required String universityName,
    required String rewardId,
    required String rewardTitle,
    required int pointCost,
  }) async {
    try {
      await _firestore.collection('user_reward_purchases').add({
        'userId': userId,
        'userName': userName,
        'universityName': universityName,
        'rewardId': rewardId,
        'rewardTitle': rewardTitle,
        'pointsSpent': pointCost,
        'purchasedAt': FieldValue.serverTimestamp(),
      });

      await addPoints(userId: userId, points: -pointCost, category: 'reward');
    } catch (e) {
      throw Exception('Ödül satın alınamadı: $e');
    }
  }

  Stream<List<UserRewardPurchase>> getUserRewardPurchases(String userId) {
    return _firestore
        .collection('user_reward_purchases')
        .where('userId', isEqualTo: userId)
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserRewardPurchase.fromFirestore(doc))
            .toList());
  }

  // ============================================================
  // 5. ARAMA ANALİZİ SERVİSİ
  // ============================================================
  
  Future<void> logSearch({
    required String universityName,
    required String query,
    required String category,
    required int resultCount,
  }) async {
    try {
      await _firestore.collection('search_queries').add({
        'universityName': universityName,
        'query': query,
        'category': category,
        'resultCount': resultCount,
        'searchedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Arama kaydı oluşturulamadı: $e');
    }
  }

  Stream<List<SearchTrend>> getSearchTrends(String universityName) {
    return _firestore
        .collection('search_trends')
        .where('universityName', isEqualTo: universityName)
        .orderBy('trendScore', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SearchTrend.fromFirestore(doc))
            .toList());
  }

  // ============================================================
  // 6. AI İSTATİSTİK SERVİSİ
  // ============================================================
  
  Future<void> saveAIMetrics({
    required String modelName,
    required String universityName,
    required double accuracy,
    required double precision,
    required double recall,
    required int totalPredictions,
    required int correctPredictions,
    required double averageResponseTime,
  }) async {
    try {
      await _firestore.collection('ai_metrics').add({
        'modelName': modelName,
        'universityName': universityName,
        'accuracy': accuracy,
        'precision': precision,
        'recall': recall,
        'totalPredictions': totalPredictions,
        'correctPredictions': correctPredictions,
        'averageResponseTime': averageResponseTime,
        'measuredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('AI metrik kaydı yapılamadı: $e');
    }
  }

  Stream<List<AIModelMetrics>> getAIMetrics(String universityName) {
    return _firestore
        .collection('ai_metrics')
        .where('universityName', isEqualTo: universityName)
        .orderBy('measuredAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AIModelMetrics.fromFirestore(doc))
            .toList());
  }

  // ============================================================
  // 7. FİNANSAL RAPOR SERVİSİ
  // ============================================================
  
  Future<void> addFinancialRecord({
    required String universityName,
    required String type,
    required String category,
    required double amount,
    required String description,
    required String status,
  }) async {
    try {
      await _firestore.collection('financial_records').add({
        'universityName': universityName,
        'type': type,
        'category': category,
        'amount': amount,
        'description': description,
        'recordedAt': FieldValue.serverTimestamp(),
        'status': status,
      });
    } catch (e) {
      throw Exception('Finansal kaydı eklenemedi: $e');
    }
  }

  Future<FinancialSummary?> getFinancialSummary({
    required String universityName,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      final query = await _firestore
          .collection('financial_summaries')
          .where('universityName', isEqualTo: universityName)
          .where('periodStart', isGreaterThanOrEqualTo: periodStart)
          .where('periodEnd', isLessThanOrEqualTo: periodEnd)
          .orderBy('periodStart', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return FinancialSummary.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Finansal özet getirilemedi: $e');
    }
  }

  Stream<List<FinancialRecord>> getFinancialRecords({
    required String universityName,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    return _firestore
        .collection('financial_records')
        .where('universityName', isEqualTo: universityName)
        .where('recordedAt', isGreaterThanOrEqualTo: periodStart)
        .where('recordedAt', isLessThanOrEqualTo: periodEnd)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinancialRecord.fromFirestore(doc))
            .toList());
  }
}

