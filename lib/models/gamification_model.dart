import 'package:cloud_firestore/cloud_firestore.dart';

// XP Geçmişi Modeli (Log)
class XPLog {
  final String id;
  final String userId;
  final String operationType; // "forum_yazi", "yorum", "satis", "mesaj", "etkinlik", "badge_unlock", "haftalik_bonus"
  final int xpAmount;
  final String relatedId; // İlgili yazı/ürün ID'si
  final DateTime timestamp;
  final bool deleted;

  XPLog({
    required this.id,
    required this.userId,
    required this.operationType,
    required this.xpAmount,
    required this.relatedId,
    required this.timestamp,
    this.deleted = false,
  });

  factory XPLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return XPLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      operationType: data['operationType'] ?? '',
      xpAmount: data['xpAmount'] ?? 0,
      relatedId: data['relatedId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deleted: data['deleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'operationType': operationType,
      'xpAmount': xpAmount,
      'relatedId': relatedId,
      'timestamp': Timestamp.fromDate(timestamp),
      'deleted': deleted,
    };
  }
}

// Seviye Modeli
class Level {
  final int levelNumber; // 1-50
  final int minXP;
  final int maxXP;
  final String title; // "Yeni Başlayan", "Efsane" vb.
  final int bonusXP;
  final String specialIcon;

  Level({
    required this.levelNumber,
    required this.minXP,
    required this.maxXP,
    required this.title,
    required this.bonusXP,
    required this.specialIcon,
  });

  factory Level.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Level(
      levelNumber: data['levelNumber'] ?? 1,
      minXP: data['minXP'] ?? 0,
      maxXP: data['maxXP'] ?? 100,
      title: data['title'] ?? 'Üye',
      bonusXP: data['bonusXP'] ?? 0,
      specialIcon: data['specialIcon'] ?? '',
    );
  }
}

// Kullanıcı Gamifikasyon Durumu (State için)
class UserGamificationStatus {
  final String userId;
  final int totalXP;
  final int currentLevel;
  final int xpInCurrentLevel; 
  final List<String> unlockedBadgeIds;
  final DateTime lastXPUpdate;

  UserGamificationStatus({
    required this.userId,
    required this.totalXP,
    required this.currentLevel,
    required this.xpInCurrentLevel,
    required this.unlockedBadgeIds,
    required this.lastXPUpdate,
  });

  // Bir sonraki seviyeye kalan XP
  int getXPUntilNextLevel(Level currentLevelData) {
    return currentLevelData.maxXP - xpInCurrentLevel;
  }

  // Seviye ilerleme yüzdesi (0.0 - 1.0 arası)
  double getLevelProgress(Level currentLevelData) {
    final totalForLevel = currentLevelData.maxXP - currentLevelData.minXP;
    if (totalForLevel <= 0) return 0.0;
    return (xpInCurrentLevel / totalForLevel).clamp(0.0, 1.0);
  }

  factory UserGamificationStatus.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // XP'ye göre seviye içindeki ilerlemeyi hesaplamak için basit bir mantık 
    // (Gerçek hesaplama Service tarafında veya Level verisiyle yapılır)
    // Şimdilik gelen veriyi alıyoruz.
    
    return UserGamificationStatus(
      userId: doc.id,
      totalXP: data['xp'] ?? 0,
      currentLevel: data['seviye'] ?? 1,
      xpInCurrentLevel: data['xpInCurrentLevel'] ?? 0, // Bu alanın Firestore'da tutulması gerekir
      unlockedBadgeIds: List<String>.from(data['earnedBadges'] ?? []), // 'rozetler' yerine 'earnedBadges' kullanılıyor
      lastXPUpdate: (data['lastXPUpdate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}