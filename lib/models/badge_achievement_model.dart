import 'package:cloud_firestore/cloud_firestore.dart';

/// Badge Tanımı
class Badge {
  final String id;
  final String ad;
  final String aciklama;
  final String icon;
  final String kategori; // "sosyal", "akademik", "eglence", "guvenlik"
  final int xpReward;
  final int maxUnlock; // Kaç kişi kazanabilir (-1 = sınırsız)
  final String unlockedBy; // Kimlerin kazandığı
  final int tierLevel; // 1-5, zorluk seviyesi
  final DateTime olusturmaTarihi;

  Badge({
    required this.id,
    required this.ad,
    required this.aciklama,
    required this.icon,
    required this.kategori,
    required this.xpReward,
    required this.maxUnlock,
    required this.unlockedBy,
    required this.tierLevel,
    required this.olusturmaTarihi,
  });

  factory Badge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Badge(
      id: doc.id,
      ad: data['ad'] ?? 'Badge',
      aciklama: data['aciklama'] ?? '',
      icon: data['icon'] ?? '🏆',
      kategori: data['kategori'] ?? 'sosyal',
      xpReward: (data['xpReward'] ?? 0).toInt(),
      maxUnlock: (data['maxUnlock'] ?? -1).toInt(),
      unlockedBy: data['unlockedBy'] ?? '',
      tierLevel: (data['tierLevel'] ?? 1).toInt(),
      olusturmaTarihi: (data['olusturmaTarihi'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ad': ad,
      'aciklama': aciklama,
      'icon': icon,
      'kategori': kategori,
      'xpReward': xpReward,
      'maxUnlock': maxUnlock,
      'unlockedBy': unlockedBy,
      'tierLevel': tierLevel,
      'olusturmaTarihi': Timestamp.fromDate(olusturmaTarihi),
    };
  }
}

/// Kullanıcının Kazandığı Badge
class UserBadge {
  final String badgeId;
  final String badgeName;
  final String icon;
  final DateTime unlockedAt;
  final bool isFeatured;

  UserBadge({
    required this.badgeId,
    required this.badgeName,
    required this.icon,
    required this.unlockedAt,
    required this.isFeatured,
  });

  factory UserBadge.fromFirestore(Map<String, dynamic> data) {
    return UserBadge(
      badgeId: data['badgeId'] ?? '',
      badgeName: data['badgeName'] ?? 'Badge',
      icon: data['icon'] ?? '🏆',
      unlockedAt: (data['unlockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFeatured: data['isFeatured'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'badgeId': badgeId,
      'badgeName': badgeName,
      'icon': icon,
      'unlockedAt': Timestamp.fromDate(unlockedAt),
      'isFeatured': isFeatured,
    };
  }
}

/// Achievement (Başarı Tanımı)
class Achievement {
  final String id;
  final String ad;
  final String aciklama;
  final String icon;
  final int targetValue; // Hedef değer (örn: 1000 XP, 10 post)
  final String metrik; // "xp", "messages", "posts", "ring_sefers", "poll_votes"
  final int xpReward;
  final DateTime olusturmaTarihi;

  Achievement({
    required this.id,
    required this.ad,
    required this.aciklama,
    required this.icon,
    required this.targetValue,
    required this.metrik,
    required this.xpReward,
    required this.olusturmaTarihi,
  });

  factory Achievement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Achievement(
      id: doc.id,
      ad: data['ad'] ?? 'Achievement',
      aciklama: data['aciklama'] ?? '',
      icon: data['icon'] ?? '⭐',
      targetValue: (data['targetValue'] ?? 0).toInt(),
      metrik: data['metrik'] ?? 'xp',
      xpReward: (data['xpReward'] ?? 0).toInt(),
      olusturmaTarihi: (data['olusturmaTarihi'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ad': ad,
      'aciklama': aciklama,
      'icon': icon,
      'targetValue': targetValue,
      'metrik': metrik,
      'xpReward': xpReward,
      'olusturmaTarihi': Timestamp.fromDate(olusturmaTarihi),
    };
  }
}

/// Kullanıcının Kazandığı Achievement
class UserAchievement {
  final String achievementId;
  final String achievementName;
  final String icon;
  final DateTime unlockedAt;
  final int progressPercent; // 0-100 arası

  UserAchievement({
    required this.achievementId,
    required this.achievementName,
    required this.icon,
    required this.unlockedAt,
    required this.progressPercent,
  });

  factory UserAchievement.fromFirestore(Map<String, dynamic> data) {
    return UserAchievement(
      achievementId: data['achievementId'] ?? '',
      achievementName: data['achievementName'] ?? 'Achievement',
      icon: data['icon'] ?? '⭐',
      unlockedAt: (data['unlockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      progressPercent: (data['progressPercent'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'achievementId': achievementId,
      'achievementName': achievementName,
      'icon': icon,
      'unlockedAt': Timestamp.fromDate(unlockedAt),
      'progressPercent': progressPercent,
    };
  }

  bool isUnlocked() {
    return progressPercent >= 100;
  }
}

/// Badge/Achievement İstatistiği
class GamificationStats {
  final int totalBadges;
  final int badgesUnlocked;
  final int totalAchievements;
  final int achievementsUnlocked;
  final int currentStreak; // Kaç gün üst üste aktif
  final int longestStreak;
  final int totalXpGained;

  GamificationStats({
    required this.totalBadges,
    required this.badgesUnlocked,
    required this.totalAchievements,
    required this.achievementsUnlocked,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalXpGained,
  });

  factory GamificationStats.fromFirestore(Map<String, dynamic> data) {
    return GamificationStats(
      totalBadges: (data['totalBadges'] ?? 0).toInt(),
      badgesUnlocked: (data['badgesUnlocked'] ?? 0).toInt(),
      totalAchievements: (data['totalAchievements'] ?? 0).toInt(),
      achievementsUnlocked: (data['achievementsUnlocked'] ?? 0).toInt(),
      currentStreak: (data['currentStreak'] ?? 0).toInt(),
      longestStreak: (data['longestStreak'] ?? 0).toInt(),
      totalXpGained: (data['totalXpGained'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'totalBadges': totalBadges,
      'badgesUnlocked': badgesUnlocked,
      'totalAchievements': totalAchievements,
      'achievementsUnlocked': achievementsUnlocked,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalXpGained': totalXpGained,
    };
  }

  double getBadgeUnlockPercentage() {
    if (totalBadges == 0) return 0;
    return (badgesUnlocked / totalBadges) * 100;
  }

  double getAchievementUnlockPercentage() {
    if (totalAchievements == 0) return 0;
    return (achievementsUnlocked / totalAchievements) * 100;
  }
}
