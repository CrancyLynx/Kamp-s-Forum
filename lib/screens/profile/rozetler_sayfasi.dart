import 'package:flutter/material.dart' hide Badge;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

// Modeller ve Servisler
import '../../models/badge_model.dart';
import '../../models/gamification_model.dart';
import '../../providers/gamification_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_header.dart';

class RozetlerSayfasi extends StatefulWidget {
  final Map<String, dynamic> userData; // İstatistikler için gerekli (yorum sayısı vb.)
  final Set<String> earnedBadgeIds;
  final bool isAdmin;

  const RozetlerSayfasi({
    super.key,
    required this.userData,
    required this.earnedBadgeIds,
    required this.isAdmin,
  });

  @override
  State<RozetlerSayfasi> createState() => _RozetlerSayfasiState();
}

class _RozetlerSayfasiState extends State<RozetlerSayfasi> with SingleTickerProviderStateMixin {
  String _selectedCategory = 'Tümü';
  final List<String> _categories = ['Tümü', 'Sosyal', 'İçerik', 'Topluluk', 'Özel'];

  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında verileri tazeleyelim (opsiyonel, provider zaten dinliyor)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppHeader(
        title: "Başarılarım",
        showLogo: false,
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<GamificationProvider>(
        builder: (context, provider, child) {
          final status = provider.status;
          final levelData = provider.currentLevelData;

          if (status == null || levelData == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return CustomScrollView(
            slivers: [
              // 1. SEVİYE VE XP KARTI
              SliverToBoxAdapter(
                child: _buildLevelProgressCard(context, status, levelData),
              ),

              // 2. KATEGORİ FİLTRELERİ
              SliverToBoxAdapter(
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      return ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          if (selected) setState(() => _selectedCategory = category);
                        },
                        selectedColor: AppColors.primary,
                        backgroundColor: Theme.of(context).cardColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 3. ROZETLER GRID
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // Yan yana 3 rozet
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final badge = allBadges[index];
                      
                      // Kategori Filtreleme Mantığı (Basitçe ID'ye veya manuel mantığa göre)
                      if (_selectedCategory != 'Tümü' && _getBadgeCategory(badge.id) != _selectedCategory) {
                        return const SizedBox.shrink(); // Gösterme (Grid yapısını bozabilir, normalde listeyi filtrelemek daha iyidir ama basitlik için)
                      }
                      
                      // Filtreleme yapıyorsak boşlukları önlemek için listeyi önceden filtrelemeliyiz
                      // Ancak şimdilik tüm listeyi dönüyoruz, gelişmiş filtreleme aşağıda:
                      return _buildBadgeCard(context, badge, status.unlockedBadgeIds);
                    },
                    childCount: allBadges.length,
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          );
        },
      ),
    );
  }

  // --- SEVİYE KARTI ---
  Widget _buildLevelProgressCard(BuildContext context, UserGamificationStatus status, Level levelData) {
    final double progress = status.getLevelProgress(levelData);
    final int nextLevelXP = levelData.maxXP;
    final int currentLevelXP = status.xpInCurrentLevel;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Seviye İkonu
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: Center(
                  child: Text(
                    levelData.specialIcon, // 🌱, 👑 vb.
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Seviye ${status.currentLevel}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      levelData.title, // "Yeni Başlayan" vb.
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Toplam XP", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    "${status.totalXP}",
                    style: const TextStyle(
                      color: AppColors.primaryAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          
          // XP Barı
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Sonraki Seviye",
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                  ),
                  Text(
                    "$currentLevelXP / $nextLevelXP XP",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.black12,
                  color: AppColors.primaryAccent,
                  minHeight: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ROZET KARTI (GRID ITEM) ---
  Widget _buildBadgeCard(BuildContext context, Badge badge, List<String> unlockedIds) {
    final bool isUnlocked = unlockedIds.contains(badge.id);
    
    return GestureDetector(
      onTap: () => _showBadgeDetailDialog(context, badge, isUnlocked),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked ? badge.color.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
            width: isUnlocked ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // İkon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnlocked ? badge.color.withOpacity(0.1) : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                badge.icon,
                size: 28,
                color: isUnlocked ? badge.color : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 12),
            
            // İsim
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                badge.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isUnlocked ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey,
                ),
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Durum İkonu
            if (isUnlocked)
              const Icon(Icons.check_circle, size: 16, color: AppColors.success)
            else
              const Icon(Icons.lock, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // --- DETAY DIALOGU ---
  void _showBadgeDetailDialog(BuildContext context, Badge badge, bool isUnlocked) {
    // İlerlemeyi hesapla
    final double progress = _getBadgeProgress(badge.id);
    final String progressText = _getProgressText(badge.id, progress);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Büyük İkon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isUnlocked ? badge.color.withOpacity(0.1) : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: FaIcon(
                  badge.icon,
                  size: 50,
                  color: isUnlocked ? badge.color : Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              
              // Başlık & Açıklama
              Text(
                badge.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                badge.description,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // İlerleme Durumu
              if (!isUnlocked) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("İlerleme Durumu", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    color: badge.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  progressText,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 24),
              ],

              // Kapat Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUnlocked ? AppColors.success : Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isUnlocked ? "KAZANILDI" : "KİLİTLİ"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- YARDIMCI FONKSİYONLAR ---

  // Rozetleri kategorize etmek için basit bir eşleştirme (Badge modeline 'category' eklenene kadar)
  String _getBadgeCategory(String badgeId) {
    switch (badgeId) {
      case 'pioneer':
      case 'veteran':
        return 'İçerik';
      case 'commentator_rookie':
      case 'commentator_pro':
        return 'Sosyal';
      case 'popular_author':
      case 'campus_phenomenon':
        return 'Topluluk';
      case 'admin':
        return 'Özel';
      default:
        return 'Diğer';
    }
  }

  // İlerleme Hesaplama (widget.userData kullanarak)
  double _getBadgeProgress(String badgeId) {
    final int postCount = (widget.userData['postCount'] is int) ? widget.userData['postCount'] : 0;
    final int commentCount = (widget.userData['commentCount'] is int) ? widget.userData['commentCount'] : 0;
    final int likeCount = (widget.userData['likeCount'] is int) ? widget.userData['likeCount'] : 0;

    int target = 1;
    int current = 0;

    switch (badgeId) {
      case 'pioneer': target = 1; current = postCount; break;
      case 'commentator_rookie': target = 10; current = commentCount; break;
      case 'commentator_pro': target = 50; current = commentCount; break;
      case 'popular_author': target = 50; current = likeCount; break;
      case 'campus_phenomenon': target = 250; current = likeCount; break;
      case 'veteran': target = 50; current = postCount; break;
      
      // ✅ YENİ ROZETLER
      case 'helper': target = 100; current = commentCount; break;
      case 'early_bird': target = 20; current = postCount; break;
      case 'night_owl': target = 20; current = postCount; break;
      case 'question_master': target = 25; current = postCount; break;
      case 'problem_solver': target = 50; current = commentCount; break;
      case 'trending_topic': target = 100; current = likeCount; break;
      
      case 'admin': return 0.0; // Admin manueldir
      default: return 0.0;
    }
    return (current / target).clamp(0.0, 1.0);
  }

  String _getProgressText(String badgeId, double progress) {
    if (progress >= 1.0) return 'Tebrikler! Hedefi tamamladın.';

    final int postCount = (widget.userData['postCount'] is int) ? widget.userData['postCount'] : 0;
    final int commentCount = (widget.userData['commentCount'] is int) ? widget.userData['commentCount'] : 0;
    final int likeCount = (widget.userData['likeCount'] is int) ? widget.userData['likeCount'] : 0;

    switch (badgeId) {
      case 'pioneer': return '1 gönderi paylaşman gerek.';
      case 'commentator_rookie': return '${10 - commentCount} yorum daha yapmalısın.';
      case 'commentator_pro': return '${50 - commentCount} yorum daha yapmalısın.';
      case 'popular_author': return '${50 - likeCount} beğeni daha kazanmalısın.';
      case 'campus_phenomenon': return '${250 - likeCount} beğeni daha kazanmalısın.';
      case 'veteran': return '${50 - postCount} gönderi daha paylaşmalısın.';
      
      // ✅ YENİ ROZETLER
      case 'helper': return '${100 - commentCount} yorum daha yapmalısın.';
      case 'early_bird': return '${20 - postCount} gönderi daha paylaşmalısın.';
      case 'night_owl': return '${20 - postCount} gönderi daha paylaşmalısın.';
      case 'question_master': return '${25 - postCount} soru daha sormalısın.';
      case 'problem_solver': return '${50 - commentCount} cevap daha vermelisin.';
      case 'trending_topic': return '${100 - likeCount} beğeni daha kazanmalısın.';
      
      // Diğerleri (henüz aktif değil)
      case 'social_butterfly': return 'Bu özellik yakında aktif olacak!';
      case 'curious': return 'Bu özellik yakında aktif olacak!';
      case 'loyal_member': return 'Bu özellik yakında aktif olacak!';
      case 'friendly': return 'Bu özellik yakında aktif olacak!';
      case 'influencer': return 'Bu özellik yakında aktif olacak!';
      case 'perfectionist': return 'Bu özellik yakında aktif olacak!';
      
      default: return 'Bu rozeti kazanmak için aktif olmaya devam et!';
    }
  }
}
