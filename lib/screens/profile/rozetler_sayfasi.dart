import 'package:flutter/material.dart' hide Badge; // DÜZELTME: Material'ın Badge widget'ı ile çakışmayı önle.
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// DÜZELTME: Tekrar eden tanımlamalar kaldırıldı, merkezi model dosyası import edildi.
import 'package:kampus_yardim_app/widgets/badge_widget.dart';
import '../../models/badge_model.dart';
// Düzeltilmiş Importlar
import '../../utils/app_colors.dart';


class RozetlerSayfasi extends StatelessWidget {
  final Set<String> earnedBadgeIds;
  final bool isAdmin;
  final Map<String, dynamic> userData; // YENİ: Kullanıcı istatistiklerini almak için

  const RozetlerSayfasi({
    super.key,
    required this.earnedBadgeIds,
    this.isAdmin = false,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    // Admin rozetini, kullanıcının admin olup olmamasına göre dinamik olarak ekle
    final userBadges = Set<String>.from(earnedBadgeIds);
    if (isAdmin) {
      userBadges.add('admin');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rozetler'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: allBadges.length,
        itemBuilder: (context, index) {
          final badge = allBadges[index];
          final bool isEarned = userBadges.contains(badge.id);

          return _buildBadgeCard(context, badge, isEarned);
        },
      ),
    );
  }

  // YENİ: Rozet kartını oluşturan ve ilerleme durumunu gösteren widget
  Widget _buildBadgeCard(BuildContext context, Badge badge, bool isEarned) {
    final progressData = _getBadgeProgress(badge.id);
    final double progress = progressData['progress']!;
    final String progressText = progressData['text']!;

    return Opacity(
      opacity: isEarned ? 1.0 : 0.6, // Kazanılmamışsa soluk göster
      child: Card(
        elevation: isEarned ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isEarned
              ? BorderSide(color: badge.color, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: badge.color.withOpacity(isEarned ? 0.2 : 0.1),
                    child: FaIcon(
                      badge.icon,
                      color: isEarned ? badge.color : Colors.grey,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [ 
                        BadgeWidget(badge: badge, fontSize: 14, iconSize: 14), // DÜZELTME: Rozet adı yerine yeni widget kullanılıyor.
                        const SizedBox(height: 4), // DÜZELTME: Rozet ile açıklama arasına boşluk eklendi.
                        Text(
                          badge.description,
                          style: TextStyle(color: isEarned ? Colors.grey[600] : Colors.grey[500], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  isEarned
                      ? const Icon(Icons.check_circle, color: AppColors.success, size: 28)
                      : const Icon(Icons.lock_outline, color: Colors.grey, size: 28),
                ],
              ),
              // Kazanılmamışsa ve ilerleme varsa göster
              if (!isEarned && progress > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade300,
                          color: badge.color,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        progressText,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // YENİ: Rozet ID'sine göre ilerleme durumunu hesaplayan fonksiyon
  Map<String, dynamic> _getBadgeProgress(String badgeId) {
    final int postCount = userData['postCount'] ?? 0;
    final int commentCount = userData['commentCount'] ?? 0;
    final int likeCount = userData['likeCount'] ?? 0;

    // DÜZELTME: Kalan miktarı hesaplarken negatif sayıları önlemek ve
    // ilerleme çubuğunun değerini 0.0 ile 1.0 arasında tutmak için mantığı güncelliyoruz.
    switch (badgeId) {
      case 'pioneer':
        final int target = 1;
        final int remaining = target - postCount;
        return {'progress': (postCount / target).clamp(0.0, 1.0), 'text': remaining > 0 ? 'Hedef: 1 gönderi' : 'Hedef tamamlandı!'};
      case 'commentator_rookie':
        final int target = 10;
        final int remaining = target - commentCount;
        return {'progress': (commentCount / target).clamp(0.0, 1.0), 'text': remaining > 0 ? 'Kalan $remaining yorum' : 'Hedef tamamlandı!'};
      case 'commentator_pro':
        final int target = 50;
        final int remaining = target - commentCount;
        return {'progress': (commentCount / target).clamp(0.0, 1.0), 'text': remaining > 0 ? 'Kalan $remaining yorum' : 'Hedef tamamlandı!'};
      case 'popular_author':
        final int target = 50;
        final int remaining = target - likeCount;
        return {'progress': (likeCount / target).clamp(0.0, 1.0), 'text': remaining > 0 ? 'Kalan $remaining beğeni' : 'Hedef tamamlandı!'};
      case 'campus_phenomenon':
        final int target = 250;
        final int remaining = target - likeCount;
        return {'progress': (likeCount / target).clamp(0.0, 1.0), 'text': remaining > 0 ? 'Kalan $remaining beğeni' : 'Hedef tamamlandı!'};
      case 'veteran':
        final int target = 50;
        final int remaining = target - postCount;
        return {'progress': (postCount / target).clamp(0.0, 1.0), 'text': remaining > 0 ? 'Kalan $remaining gönderi' : 'Hedef tamamlandı!'};
      default:
        return {'progress': 0.0, 'text': ''};
    }
  }
}
