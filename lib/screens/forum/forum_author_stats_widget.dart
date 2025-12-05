import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Forum yazarının puanını ve rozetlerini gösteren widget
class ForumAuthorStatsWidget extends StatelessWidget {
  final String authorUserId;

  const ForumAuthorStatsWidget({
    Key? key,
    required this.authorUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_points')
          .doc(authorUserId)
          .snapshots(),
      builder: (context, pointsSnapshot) {
        if (!pointsSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final pointsData = pointsSnapshot.data?.data() as Map<String, dynamic>?;
        final totalPoints = (pointsData?['totalPoints'] ?? 0) as int;
        final level = (pointsData?['level'] ?? 1) as int;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('user_achievements')
              .where('userId', isEqualTo: authorUserId)
              .where('unlockedAt', isNotEqualTo: null)
              .snapshots(),
          builder: (context, achievementsSnapshot) {
            final achievements = achievementsSnapshot.data?.docs ?? [];

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Points Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'L$level',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$totalPoints⭐',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Achievement Badges (show up to 3)
                  if (achievements.isNotEmpty)
                    ...List.generate(
                      achievements.length > 3 ? 3 : achievements.length,
                      (index) {
                        final achievementData = achievements[index].data() as Map<String, dynamic>;
                        final rarity = (achievementData['rarity'] ?? 'common') as String;
                        final icon = (achievementData['icon'] ?? '🏆') as String;
                        final rarityColor = _getRarityColor(rarity);

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Tooltip(
                            message: achievementData['name'] ?? 'Rozet',
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: rarityColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: rarityColor.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(icon, style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    ),

                  // More achievements indicator
                  if (achievements.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Text(
                        '+${achievements.length - 3}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return Colors.amber;
      case 'epic':
        return Colors.purple;
      case 'rare':
        return Colors.blue;
      case 'uncommon':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
