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
}
