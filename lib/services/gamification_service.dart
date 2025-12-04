import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gamification_model.dart';

// ✅ YENİ: XP DAĞILIMI SABİTLERİ (Fair XP Sistemi)
const Map<String, int> XP_DISTRIBUTION = {
  'post_created': 10,       // Gönderi paylaşma
  'comment_created': 5,     // Yorum yapma
  'comment_like': 1,        // Yorum beğenilmesi
  'post_like': 0,           // Gönderi beğenilmesi (spam önlemek)
  'badge_unlock': 50,       // Rozet kazanma
};

// ✅ YENİ: SPAM KORUMA SABİTLERİ
const Duration SPAM_TIME_WINDOW = Duration(minutes: 5);
const int SPAM_ACTION_LIMIT = 10;

class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Singleton
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  /// ✅ YENİ: Rate limiting kontrolü (Spam koruması)
  Future<bool> _checkRateLimit(String userId, String operationType) async {
    try {
      final now = DateTime.now();
      final timeWindowStart = now.subtract(SPAM_TIME_WINDOW);

      final recentLogs = await _firestore
          .collection('xp_logs')
          .where('userId', isEqualTo: userId)
          .where('operationType', isEqualTo: operationType)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(timeWindowStart))
          .count()
          .get();

      final actionCount = recentLogs.count ?? 0;
      if (actionCount >= SPAM_ACTION_LIMIT) {
        print('⚠️ SPAM KORUMASI: $userId - $operationType (${actionCount + 1} işlem)');
        await _firestore.collection('kullanicilar').doc(userId).update({
          'lastSpamFlag': FieldValue.serverTimestamp(),
          'spamWarnings': FieldValue.increment(1),
        }).catchError((_) {});
        return true;
      }
      return false;
    } catch (e) {
      print('Rate limit kontrolü hatası: $e');
      return false;
    }
  }

  /// ✅ YENİ: Fair XP multiplier'ı hesapla
  Future<double> _calculateMultiplier(String userId, String operationType) async {
    try {
      if (operationType != 'comment_created' && operationType != 'post_created') {
        return 1.0;
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final todayCount = await _firestore
          .collection('xp_logs')
          .where('userId', isEqualTo: userId)
          .where('operationType', isEqualTo: operationType)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .count()
          .get();

      final count = todayCount.count ?? 0;
      if (count < 5) return 1.0;
      if (count < 10) return 0.8;
      return 0.5;
    } catch (e) {
      print('Multiplier hesaplama hatası: $e');
      return 1.0;
    }
  }

  /// ✅ YENİ: Seviye atlama event'i
  Future<void> _onLevelUp(String userId, int oldLevel, int newLevel) async {
    try {
      await _firestore.collection('bildirimler').add({
        'userId': userId,
        'senderName': 'Sistem',
        'type': 'level_up',
        'oldLevel': oldLevel,
        'newLevel': newLevel,
        'message': 'Tebrikler! Seviye $newLevel\'e ulaştın!',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (newLevel % 5 == 0) {
        final bonusXP = 25;
        print('🎁 MİLESTONE BONUS: $userId Seviye $newLevel → +$bonusXP XP');
        await _firestore.collection('kullanicilar').doc(userId).update({
          'xp': FieldValue.increment(bonusXP),
        });
      }
    } catch (e) {
      print('Seviye atlama event hatası: $e');
    }
  }

  /// XP Ekleme İşlemi (Tüm gamifikasyonun kalbi) - GÜNCELLENMİŞ
  Future<void> addXP(String userId, String operationType, int xpAmount, String relatedId) async {
    try {
      // ✅ YENİ: Spam kontrolü
      final isSpamming = await _checkRateLimit(userId, operationType);
      if (isSpamming) {
        print('XP ekleme reddedildi: Spam algılandı');
        return;
      }

      // ✅ YENİ: Fair multiplier hesapla
      final multiplier = await _calculateMultiplier(userId, operationType);
      final finalXP = (xpAmount * multiplier).toInt();
      
      final userRef = _firestore.collection('kullanicilar').doc(userId);
      int oldLevel = 0;
      int newLevel = 0;
      
      // Transaction kullanarak güvenli güncelleme yapıyoruz
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        final userData = userDoc.data() as Map<String, dynamic>;
        final currentXP = userData['xp'] ?? 0;
        oldLevel = userData['seviye'] ?? 1;

        // 1. Yeni XP'yi hesapla (Fair XP ile)
        final int newXP = currentXP + finalXP;

        // 2. Seviye Kontrolü (Basit formül: Her 200 XP = 1 Seviye)
        final int calculatedLevel = (newXP / 200).floor() + 1;
        newLevel = calculatedLevel > 50 ? 50 : calculatedLevel; // Max seviye 50
        
        // Bu seviye için kazanılan XP
        final int xpInCurrentLevel = newXP % 200;

        // 3. Güncellemeleri hazırla
        transaction.update(userRef, {
          'xp': newXP,
          'seviye': newLevel,
          'xpInCurrentLevel': xpInCurrentLevel,
          'lastXPUpdate': FieldValue.serverTimestamp(),
        });

        // 4. Log kaydı oluştur (xp_logs) - Fair XP ile
        final logRef = _firestore.collection('xp_logs').doc();
        transaction.set(logRef, {
          'userId': userId,
          'operationType': operationType,
          'baseXPAmount': xpAmount,
          'finalXPAmount': finalXP,
          'multiplier': multiplier,
          'relatedId': relatedId,
          'timestamp': FieldValue.serverTimestamp(),
          'deleted': false,
        });
      });

      // ✅ YENİ: Seviye atlama kontrolü
      if (newLevel > oldLevel && newLevel > 1) {
        print('🎉 SEVIYE ATLAMA: $userId Seviye $oldLevel → $newLevel');
        await _onLevelUp(userId, oldLevel, newLevel);
      }

      // Rozet kontrolü yap
      await _checkNewBadges(userId);

    } catch (e) {
      print('XP Ekleme Hatası: $e');
      // Not: UI'da hata göstermek için bu servis bir callback veya stream kullanabilir
      // Şu an sessizce başarısız oluyor, bu gamification için kabul edilebilir
    }
  }

  /// Rozet kazanma kontrolü
  Future<void> _checkNewBadges(String userId) async {
    try {
      final userDoc = await _firestore.collection('kullanicilar').doc(userId).get();
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final List<String> currentBadges = List<String>.from(userData['earnedBadges'] ?? []);
      
      // İstatistikleri al
      final int commentCount = userData['commentCount'] ?? 0;
      final int postCount = userData['postCount'] ?? 0;
      final int likeCount = userData['likeCount'] ?? 0;

      // Kazanılacak yeni rozetler listesi
      List<String> newBadges = [];

      // Rozet Mantığı (badge_model.dart'taki ID'lerle eşleşmeli)
      
      // 1. Öncü (İlk gönderi)
      if (postCount >= 1 && !currentBadges.contains('pioneer')) {
        newBadges.add('pioneer');
      }

      // 2. Sohbet Meraklısı (10 Yorum)
      if (commentCount >= 10 && !currentBadges.contains('commentator_rookie')) {
        newBadges.add('commentator_rookie');
      }

      // 3. Fikir Lideri (50 Yorum)
      if (commentCount >= 50 && !currentBadges.contains('commentator_pro')) {
        newBadges.add('commentator_pro');
      }

      // 4. Popüler Yazar (50 Beğeni)
      if (likeCount >= 50 && !currentBadges.contains('popular_author')) {
        newBadges.add('popular_author');
      }

      // 5. Kampüs Fenomeni (250 Beğeni)
      if (likeCount >= 250 && !currentBadges.contains('campus_phenomenon')) {
        newBadges.add('campus_phenomenon');
      }

      // 6. Usta (50 Gönderi)
      if (postCount >= 50 && !currentBadges.contains('veteran')) {
        newBadges.add('veteran');
      }

      // ✅ YENİ ROZETLER
      
      // 7. Yardımsever (100 Yorum)
      if (commentCount >= 100 && !currentBadges.contains('helper')) {
        newBadges.add('helper');
      }

      // 8. Sabahçı Kuş (20 Gönderi + Sabah kontrolü) - Basitleştirilmiş
      if (postCount >= 20 && !currentBadges.contains('early_bird')) {
        newBadges.add('early_bird');
      }

      // 9. Gece Kuşu (20 Gönderi + Gece kontrolü) - Basitleştirilmiş
      if (postCount >= 20 && !currentBadges.contains('night_owl')) {
        newBadges.add('night_owl');
      }

      // 10. Soru Ustası (25 soru - etiket kontrolü yapılabilir gelecekte)
      if (postCount >= 25 && !currentBadges.contains('question_master')) {
        newBadges.add('question_master');
      }

      // 11. Çözüm Odaklı (50 yorum - basitleştirilmiş)
      if (commentCount >= 50 && !currentBadges.contains('problem_solver')) {
        newBadges.add('problem_solver');
      }

      // 12. Trend Yaratıcı (100+ görüntülenme - basitleştirilmiş, likeCount kullanıyoruz)
      if (likeCount >= 100 && !currentBadges.contains('trending_topic')) {
        newBadges.add('trending_topic');
      }

      // ✅ AKTIF: 6 İNAKTİF ROZET

      // 13. Sosyal Kelebek (50+ yorum)
      if (commentCount >= 50 && !currentBadges.contains('social_butterfly')) {
        newBadges.add('social_butterfly');
      }

      // 14. Meraklı (100+ yorum)
      if (commentCount >= 100 && !currentBadges.contains('curious')) {
        newBadges.add('curious');
      }

      // 15. Sadık Üye (75+ yorum)
      if (commentCount >= 75 && !currentBadges.contains('loyal_member')) {
        newBadges.add('loyal_member');
      }

      // 16. Arkadaş Canlısı (60+ beğeni)
      if (likeCount >= 60 && !currentBadges.contains('friendly')) {
        newBadges.add('friendly');
      }

      // 17. Etkileyici (150+ beğeni)
      if (likeCount >= 150 && !currentBadges.contains('influencer')) {
        newBadges.add('influencer');
      }

      // 18. Mükemmeliyetçi (30+ gönderi)
      if (postCount >= 30 && !currentBadges.contains('perfectionist')) {
        newBadges.add('perfectionist');
      }

      // Yeni rozet varsa veritabanını güncelle ve XP ver
      if (newBadges.isNotEmpty) {
        for (var badgeId in newBadges) {
          // Rozeti ekle
          await _firestore.collection('kullanicilar').doc(userId).update({
            'earnedBadges': FieldValue.arrayUnion([badgeId])
          });

          // Rozet kazanma ödülü (Sabit 50 XP veriyoruz şimdilik)
          await addXP(userId, 'badge_unlock', 50, badgeId);
          
          // Bildirim gönder
          await _firestore.collection('bildirimler').add({
            'userId': userId,
            'senderName': 'Sistem',
            'type': 'system', // system ikonu kullanılacak
            'message': 'Tebrikler! Yeni bir rozet kazandın.',
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

    } catch (e) {
      // ✅ DÜZELTME: Hata loglama iyileştirildi
      print('Rozet Kontrol Hatası: $e');
      // Not: Rozet kontrolü başarısız olsa bile XP ekleme başarılı olmuştur
      // Bu nedenle sessizce başarısız olmak kabul edilebilir
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
