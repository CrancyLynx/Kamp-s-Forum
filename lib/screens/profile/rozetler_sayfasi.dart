import 'package:flutter/material.dart' hide Badge;
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
import '../../models/badge_model.dart';
import '../../utils/app_colors.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../utils/maskot_helper.dart'; // EKLENDİ

class RozetlerSayfasi extends StatefulWidget {
  final Set<String> earnedBadgeIds;
  final bool isAdmin;
  final Map<String, dynamic> userData; 

  const RozetlerSayfasi({
    super.key,
    required this.earnedBadgeIds,
    this.isAdmin = false,
    required this.userData,
  });

  @override
  State<RozetlerSayfasi> createState() => _RozetlerSayfasiState();
}

class _RozetlerSayfasiState extends State<RozetlerSayfasi> {
  // --- YENİ SİSTEM İÇİN GLOBAL KEY'LER ---
  final Map<String, GlobalKey> _badgeKeys = {};

  @override
  void initState() {
    super.initState();

    // Her rozet için bir GlobalKey oluştur
    for (var badge in allBadges) {
      _badgeKeys[badge.id] = GlobalKey();
    }

    // --- YENİ SİSTEM İLE MASKOT KODU ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Vurgulanacak rozeti bul: Ya kazanılan ilk rozet ya da en yakın olunan rozet
      String? targetBadgeId;
      if (widget.earnedBadgeIds.isNotEmpty) {
        targetBadgeId = widget.earnedBadgeIds.first;
      } else {
        // En yüksek ilerlemeye sahip rozeti bul
        double maxProgress = 0;
        for (var badge in allBadges) {
          final progressData = _getBadgeProgress(badge.id);
          if (progressData['progress'] > maxProgress) {
            maxProgress = progressData['progress'];
            targetBadgeId = badge.id;
          }
        }
      }

      if (targetBadgeId != null && _badgeKeys[targetBadgeId] != null) {
        MaskotHelper.checkAndShow(context,
            featureKey: 'rozetler_tutorial_gosterildi',
            targets: [
              TargetFocus(
                  identify: "badge-focus",
                  keyTarget: _badgeKeys[targetBadgeId],
                  contents: [
                    TargetContent(
                      align: ContentAlign.top, builder: (context, controller) =>
                        MaskotHelper.buildTutorialContent(
                            context,
                            title: 'Rozet Koleksiyonun',
                            description: 'Kampüsteki aktifliğine göre kazandığın rozetler burada sergilenir. Hepsini toplamaya çalış!'),
                    )
                  ])
            ]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Admin rozetini, kullanıcının admin olup olmamasına göre dinamik olarak ekle
    final userBadges = Set<String>.from(widget.earnedBadgeIds);
    if (widget.isAdmin) {
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

          return KeyedSubtree(
            key: _badgeKeys[badge.id], // --- HER KARTA KEY EKLE ---
            child: _buildBadgeCard(context, badge, isEarned),
          );
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
                        Text(
                          badge.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isEarned ? badge.color : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4), 
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
                          color: badge.color.withOpacity(0.8), // Renk opaklığı azaltıldı
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
    final int postCount = widget.userData['postCount'] ?? 0;
    final int commentCount = widget.userData['commentCount'] ?? 0;
    final int likeCount = widget.userData['likeCount'] ?? 0;

    switch (badgeId) {
      case 'pioneer':
        final int target = 1;
        final int current = postCount.clamp(0, target);
        final int remaining = target - current;
        return {'progress': current / target, 'text': remaining > 0 ? 'Kalan 1 gönderi' : 'Hedef tamamlandı!'};
      case 'commentator_rookie':
        final int target = 10;
        final int current = commentCount.clamp(0, target);
        final int remaining = target - current;
        return {'progress': current / target, 'text': remaining > 0 ? 'Kalan $remaining yorum' : 'Hedef tamamlandı!'};
      case 'commentator_pro':
        final int target = 50;
        final int current = commentCount.clamp(0, target);
        final int remaining = target - current;
        return {'progress': current / target, 'text': remaining > 0 ? 'Kalan $remaining yorum' : 'Hedef tamamlandı!'};
      case 'popular_author':
        final int target = 50;
        final int current = likeCount.clamp(0, target);
        final int remaining = target - current;
        return {'progress': current / target, 'text': remaining > 0 ? 'Kalan $remaining beğeni' : 'Hedef tamamlandı!'};
      case 'campus_phenomenon':
        final int target = 250;
        final int current = likeCount.clamp(0, target);
        final int remaining = target - current;
        return {'progress': current / target, 'text': remaining > 0 ? 'Kalan $remaining beğeni' : 'Hedef tamamlandı!'};
      case 'veteran':
        final int target = 50;
        final int current = postCount.clamp(0, target);
        final int remaining = target - current;
        return {'progress': current / target, 'text': remaining > 0 ? 'Kalan $remaining gönderi' : 'Hedef tamamlandı!'};
      case 'admin':
        return {'progress': widget.isAdmin ? 1.0 : 0.0, 'text': widget.isAdmin ? 'Yetkili kullanıcı.' : 'Yönetici yetkisi gerekli.'};
      default:
        return {'progress': 0.0, 'text': 'İlerleme hesaplanamadı'};
    }
  }
}