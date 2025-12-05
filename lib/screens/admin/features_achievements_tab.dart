import 'package:flutter/material.dart';
import '../../models/advanced_features_models.dart';
    import '../../services/advanced_features_services.dart';class Phase4AchievementsTab extends StatefulWidget {
  const Phase4AchievementsTab({Key? key}) : super(key: key);

  @override
  State<Phase4AchievementsTab> createState() => _Phase4AchievementsTabState();
}

class _Phase4AchievementsTabState extends State<Phase4AchievementsTab> {
  late Phase4Services _services;

  @override
  void initState() {
    super.initState();
    _services = Phase4Services();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏆 Tüm Başarılar',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Achievement>>(
              stream: _services.getAchievements(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Henüz başarı tanımlanmadı',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final achievement = snapshot.data![index];
                    return _buildAchievementCard(achievement);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    final rarityColor = _getRarityColor(achievement.rarity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rarityColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              achievement.emoji,
              style: const TextStyle(fontSize: 36),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '+${achievement.pointReward} XP',
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFFFF9800),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: rarityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                _getRarityLabel(achievement.rarity),
                style: TextStyle(
                  fontSize: 8,
                  color: rarityColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'legendary':
        return Colors.orange;
      case 'epic':
        return Colors.purple;
      case 'rare':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getRarityLabel(String rarity) {
    switch (rarity) {
      case 'legendary':
        return 'Efsane';
      case 'epic':
        return 'Epik';
      case 'rare':
        return 'Nadir';
      default:
        return 'Yaygın';
    }
  }
}
