import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/phase4_models.dart';
import '../../services/phase4_services.dart';

class Phase4ScoringTab extends StatefulWidget {
  const Phase4ScoringTab({Key? key}) : super(key: key);

  @override
  State<Phase4ScoringTab> createState() => _Phase4ScoringTabState();
}

class _Phase4ScoringTabState extends State<Phase4ScoringTab> {
  late Phase4Services _services;
  String _universityName = '';

  @override
  void initState() {
    super.initState();
    _services = Phase4Services();
    _loadUserUniversity();
  }

  Future<void> _loadUserUniversity() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        setState(() {
          _universityName = doc['universitesi'] ?? 'Belirsiz';
        });
      }
    } catch (e) {
      debugPrint('Üniversite yüklenemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              '⭐ Puan Sistemi',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Üniversite: $_universityName',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),

            // Leaderboard Section
            Text(
              '🏆 Leaderboard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            StreamBuilder<List<UserPoints>>(
              stream: _services.getUniversityLeaderboard(_universityName),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.leaderboard, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Veri yok',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final rankings = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rankings.length,
                  itemBuilder: (context, index) {
                    final user = rankings[index];
                    final rank = index + 1;
                    final isTopThree = rank <= 3;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isTopThree
                          ? _getRankColor(rank).withOpacity(0.1)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Rank Badge
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isTopThree
                                    ? _getRankColor(rank)
                                    : Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  isTopThree ? _getRankEmoji(rank) : '$rank',
                                  style: TextStyle(
                                    fontSize: isTopThree ? 24 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: isTopThree
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // User Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Level ${user.level}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Points
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${user.totalPoints} 💫',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[900],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.yellow[700] ?? Colors.yellow;
      case 2:
        return Colors.grey[400] ?? Colors.grey;
      case 3:
        return Colors.orange[400] ?? Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }
}
