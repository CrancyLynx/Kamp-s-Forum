import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gamification_model.dart';


class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Singleton
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  /// XP Ekleme İşlemi (Tüm gamifikasyonun kalbi)
  Future<void> addXP(String userId, String operationType, int xpAmount, String relatedId) async {
    try {
      final userRef = _firestore.collection('kullanicilar').doc(userId);
      
      // Transaction kullanarak güvenli güncelleme yapıyoruz
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        final userData = userDoc.data() as Map<String, dynamic>;
        final currentXP = userData['xp'] ?? 0;


        // 1. Yeni XP'yi hesapla
        final int newXP = currentXP + xpAmount;

        // 2. Seviye Kontrolü (Basit formül: Her 200 XP = 1 Seviye)
        // İleri seviye bir formül için 'seviye_ayarlari' koleksiyonu kullanılabilir
        final int calculatedLevel = (newXP / 200).floor() + 1;
        final int newLevel = calculatedLevel > 50 ? 50 : calculatedLevel; // Max seviye 50
        
        // Bu seviye için kazanılan XP (örn: 250 XP ise, seviye 2'dir ve o seviyede 50 XP kazanmıştır)
        final int xpInCurrentLevel = newXP % 200;

        // 3. Güncellemeleri hazırla
        transaction.update(userRef, {
          'xp': newXP,
          'seviye': newLevel,
          'xpInCurrentLevel': xpInCurrentLevel,
          'lastXPUpdate': FieldValue.serverTimestamp(),
        });

        // 4. Log kaydı oluştur (xp_logs)
        final logRef = _firestore.collection('xp_logs').doc();
        transaction.set(logRef, {
          'userId': userId,
          'operationType': operationType,
          'xpAmount': xpAmount,
          'relatedId': relatedId,
          'timestamp': FieldValue.serverTimestamp(),
          'deleted': false,
        });
      });

      // Transaction bittikten sonra Rozet kontrolü yap (Transaction dışında olması daha performanslı olabilir)
      await _checkNewBadges(userId);

    } catch (e) {
      // ✅ DÜZELTME: Hata loglama iyileştirildi
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

      // Not: Diğer rozetler (social_butterfly, curious, loyal_member, friendly, influencer, perfectionist)
      // daha karmaşık mantık gerektiriyor (takipçi sayısı, farklı kullanıcılara yorum vb.)
      // Bu özellikler eklendiğinde burada da kontrol edilecek

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
