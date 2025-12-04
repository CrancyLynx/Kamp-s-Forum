import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/gamification_model.dart';

class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  
  // Singleton
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  /// XP Ekleme İşlemi (Cloud Function'ı çağırır)
  Future<void> addXP(String userId, String operationType, String relatedId) async {
    try {
      await _functions.httpsCallable('addXp').call({
        'operationType': operationType,
        'relatedId': relatedId,
      });
    } catch (e) {
      print('XP Ekleme Hatası: $e');
    }
  }

  /// Kullanıcı gamifikasyon durumunu dinle
  Stream<UserGamificationStatus?> getUserGamificationStatusStream(String userId) {
    return _firestore
        .collection('kullanicilar')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserGamificationStatus.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Mevcut seviye için Level objesi oluştur (UI'da kullanmak için)
  Level getLevelData(int levelNumber) {
    // Basit bir hesaplama, ileride Firestore 'seviye_ayarlari' koleksiyonundan da çekilebilir.
    return Level(
      levelNumber: levelNumber,
      minXP: (levelNumber - 1) * 200,
      maxXP: levelNumber * 200,
      title: _getLevelTitle(levelNumber),
      bonusXP: levelNumber * 10,
      specialIcon: _getLevelIcon(levelNumber),
    );
  }

  String _getLevelTitle(int level) {
    if (level < 5) return "Yeni Başlayan";
    if (level < 10) return "Aktif Üye";
    if (level < 20) return "Kampüs Sakini";
    if (level < 30) return "Bilge";
    if (level < 40) return "Üstad";
    return "Efsane";
  }

  String _getLevelIcon(int level) {
    if (level < 5) return "🌱";
    if (level < 10) return "👋";
    if (level < 20) return "🎓";
    if (level < 30) return "🔥";
    if (level < 40) return "💎";
    return "👑";
  }

  // Badge Operations

  /// Badge oluştur (Admin)
  Future<String?> createBadge({
    required String ad,
    required String aciklama,
    required String icon,
    required String kategori,
    required int xpReward,
    required int maxUnlock,
    required int tierLevel,
  }) async {
    try {
      final badgeRef = _firestore.collection('rozetler').doc();
      await badgeRef.set({
        'ad': ad,
        'aciklama': aciklama,
        'icon': icon,
        'kategori': kategori,
        'xpReward': xpReward,
        'maxUnlock': maxUnlock,
        'unlockedBy': 0,
        'tierLevel': tierLevel,
        'olusturmaTarihi': Timestamp.now(),
      });
      return badgeRef.id;
    } catch (e) {
      print('Badge oluşturma hatası: $e');
      return null;
    }
  }

  /// Kullanıcıya badge ver
  Future<bool> unlockBadgeForUser({
    required String userId,
    required String badgeId,
    required String badgeName,
    required String icon,
    required int xpReward,
  }) async {
    try {
      // Badge koleksiyonuna ekle
      await _firestore
          .collection('kullanicilar')
          .doc(userId)
          .collection('rozetler')
          .doc(badgeId)
          .set({
        'badgeId': badgeId,
        'badgeName': badgeName,
        'icon': icon,
        'unlockedAt': Timestamp.now(),
        'isFeatured': false,
      });

      // XP ekle
      await _firestore.collection('kullanicilar').doc(userId).update({
        'toplam_xp': FieldValue.increment(xpReward),
      });

      // Badge unlock sayısını artır
      await _firestore.collection('rozetler').doc(badgeId).update({
        'unlockedBy': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      print('Badge unlock hatası: $e');
      return false;
    }
  }

  /// Kullanıcının badgelerini getir
  Stream<List<Map<String, dynamic>>> getUserBadgesStream(String userId) {
    return _firestore
        .collection('kullanicilar')
        .doc(userId)
        .collection('rozetler')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  /// Badge'i featured yap
  Future<bool> featureBadge({
    required String userId,
    required String badgeId,
  }) async {
    try {
      await _firestore
          .collection('kullanicilar')
          .doc(userId)
          .collection('rozetler')
          .doc(badgeId)
          .update({'isFeatured': true});
      return true;
    } catch (e) {
      print('Badge featured yapma hatası: $e');
      return false;
    }
  }

  // Achievement Operations

  /// Achievement oluştur (Admin)
  Future<String?> createAchievement({
    required String ad,
    required String aciklama,
    required String icon,
    required int targetValue,
    required String metrik,
    required int xpReward,
  }) async {
    try {
      final achievementRef = _firestore.collection('basarilar').doc();
      await achievementRef.set({
        'ad': ad,
        'aciklama': aciklama,
        'icon': icon,
        'targetValue': targetValue,
        'metrik': metrik,
        'xpReward': xpReward,
        'olusturmaTarihi': Timestamp.now(),
      });
      return achievementRef.id;
    } catch (e) {
      print('Achievement oluşturma hatası: $e');
      return null;
    }
  }

  /// Achievement ilerleme güncelleştir
  Future<bool> updateAchievementProgress({
    required String userId,
    required String achievementId,
    required int currentValue,
    required int targetValue,
  }) async {
    try {
      int progressPercent = ((currentValue / targetValue) * 100).toInt();
      if (progressPercent > 100) progressPercent = 100;

      final ref = _firestore
          .collection('kullanicilar')
          .doc(userId)
          .collection('basarilar')
          .doc(achievementId);

      final doc = await ref.get();

      if (doc.exists && progressPercent < 100) {
        // Mevcut, tamamlanmamış
        await ref.update({'progressPercent': progressPercent});
      } else if (!doc.exists && progressPercent > 0) {
        // Yeni achievement
        await ref.set({
          'achievementId': achievementId,
          'achievementName': 'Achievement',
          'icon': '⭐',
          'progressPercent': progressPercent,
          'unlockedAt': Timestamp.now(),
        });
      }

      return true;
    } catch (e) {
      print('Achievement progress update hatası: $e');
      return false;
    }
  }

  /// Achievement'ı tamamlamış kabul et
  Future<bool> completeAchievement({
    required String userId,
    required String achievementId,
    required String achievementName,
    required String icon,
    required int xpReward,
  }) async {
    try {
      await _firestore
          .collection('kullanicilar')
          .doc(userId)
          .collection('basarilar')
          .doc(achievementId)
          .set({
        'achievementId': achievementId,
        'achievementName': achievementName,
        'icon': icon,
        'progressPercent': 100,
        'unlockedAt': Timestamp.now(),
      });

      // XP ekle
      await _firestore.collection('kullanicilar').doc(userId).update({
        'toplam_xp': FieldValue.increment(xpReward),
      });

      return true;
    } catch (e) {
      print('Achievement complete hatası: $e');
      return false;
    }
  }

  /// Tüm achievements'ı getir
  Future<List<Map<String, dynamic>>> getAllAchievements() async {
    try {
      final snapshot = await _firestore.collection('basarilar').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Achievements getirme hatası: $e');
      return [];
    }
  }

  /// Kullanıcının achievements'ını getir
  Stream<List<Map<String, dynamic>>> getUserAchievementsStream(String userId) {
    return _firestore
        .collection('kullanicilar')
        .doc(userId)
        .collection('basarilar')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  /// Gamification istatistiklerini güncelle
  Future<bool> updateGamificationStats(String userId) async {
    try {
      final badgesSnap = await _firestore
          .collection('kullanicilar')
          .doc(userId)
          .collection('rozetler')
          .get();

      final achievementsSnap = await _firestore
          .collection('kullanicilar')
          .doc(userId)
          .collection('basarilar')
          .get();

      await _firestore
          .collection('kullanicilar')
          .doc(userId)
          .collection('istatistikler')
          .doc('gamifikasyon')
          .set({
        'totalBadges': badgesSnap.size,
        'totalAchievements': achievementsSnap.size,
        'achievementsUnlocked': achievementsSnap.docs
            .where((doc) => (doc.data()['progressPercent'] ?? 0) >= 100)
            .length,
        'guncellemeTarihi': Timestamp.now(),
      });

      return true;
    } catch (e) {
      print('Stats update hatası: $e');
      return false;
    }
  }
}
