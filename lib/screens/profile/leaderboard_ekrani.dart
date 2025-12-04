import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_header.dart';

class LeaderboardEkrani extends StatefulWidget {
  const LeaderboardEkrani({super.key});

  @override
  State<LeaderboardEkrani> createState() => _LeaderboardEkraniState();
}

class _LeaderboardEkraniState extends State<LeaderboardEkrani> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedUniversity = 'Tümü';
  List<String> _universities = ['Tümü'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUniversities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUniversities() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('universiteler')
          .get();
      
      final unis = ['Tümü'];
      for (var doc in snapshot.docs) {
        unis.add(doc['ad'] ?? 'Bilinmeyen');
      }
      
      setState(() => _universities = unis);
    } catch (e) {
      debugPrint('Üniversite yükleme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Leaderboard',
      ),
      body: Column(
        children: [
          // Üniversite Seçimi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButton<String>(
              value: _selectedUniversity,
              isExpanded: true,
              items: _universities.map((uni) => DropdownMenuItem(
                value: uni,
                child: Text(uni),
              )).toList(),
              onChanged: (value) {
                setState(() => _selectedUniversity = value ?? 'Tümü');
              },
            ),
          ),
          // Tab Bar
          Container(
            color: Colors.grey[100],
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(FontAwesomeIcons.star), text: 'XP'),
                Tab(icon: Icon(FontAwesomeIcons.fire), text: 'Haftalık'),
                Tab(icon: Icon(FontAwesomeIcons.crown), text: 'Rozetler'),
              ],
            ),
          ),
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildXPLeaderboard(),
                _buildWeeklyLeaderboard(),
                _buildBadgeLeaderboard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // XP Leaderboard
  Widget _buildXPLeaderboard() {
    Query query = FirebaseFirestore.instance
        .collection('kullanicilar')
        .orderBy('toplam_xp', descending: true)
        .limit(100);

    if (_selectedUniversity != 'Tümü') {
      query = query.where('universitesi', isEqualTo: _selectedUniversity);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Veri bulunamadı'));
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final totalXP = user['toplam_xp'] ?? 0;
            final userName = user['ad_soyad'] ?? 'Bilinmeyen';
            final userLevel = user['seviye'] ?? 1;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: index < 3
                    ? Border.all(
                        color: _getMedalColor(index),
                        width: 2,
                      )
                    : null,
              ),
              child: ListTile(
                leading: SizedBox(
                  width: 50,
                  child: Row(
                    children: [
                      // Medal/Position
                      SizedBox(
                        width: 36,
                        child: Center(
                          child: index == 0
                              ? const Icon(FontAwesomeIcons.medal, color: Colors.amber)
                              : index == 1
                                  ? const Icon(FontAwesomeIcons.medal, color: Color(0xFFC0C0C0))
                                  : index == 2
                                      ? const Icon(FontAwesomeIcons.medal, color: Color(0xFFCD7F32))
                                      : Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                        ),
                      ),
                    ],
                  ),
                ),
                title: Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Row(
                  children: [
                    const Icon(FontAwesomeIcons.book, size: 12),
                    const SizedBox(width: 4),
                    Text('Seviye $userLevel'),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$totalXP XP',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                    const Text(
                      'Toplam',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Haftalık Leaderboard
  Widget _buildWeeklyLeaderboard() {
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

    Query query = FirebaseFirestore.instance
        .collection('xp_logs')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(oneWeekAgo))
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Bu hafta hiç aktivite yok'));
        }

        // XP'yi kullanıcıya göre grupla
        final xpByUser = <String, int>{};
        for (var doc in snapshot.data!.docs) {
          final userId = doc['userId'] ?? '';
          final xpAmount = (doc['xpAmount'] ?? 0) as num;
          xpByUser[userId] = (xpByUser[userId] ?? 0) + xpAmount.toInt();
        }

        // Sırala
        final sorted = xpByUser.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView.builder(
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final entry = sorted[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('kullanicilar')
                  .doc(entry.key)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox();
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                final userName = userData?['ad_soyad'] ?? 'Bilinmeyen';

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: SizedBox(
                      width: 36,
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    title: Text(userName),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${entry.value} XP',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const Text(
                          'Bu Hafta',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Badge Leaderboard
  Widget _buildBadgeLeaderboard() {
    Query query = FirebaseFirestore.instance
        .collection('kullanicilar')
        .orderBy('unlockedBadgeIds', descending: true)
        .limit(100);

    if (_selectedUniversity != 'Tümü') {
      query = query.where('universitesi', isEqualTo: _selectedUniversity);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Veri bulunamadı'));
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final userName = user['ad_soyad'] ?? 'Bilinmeyen';
            final badgeCount = (user['unlockedBadgeIds'] as List?)?.length ?? 0;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: SizedBox(
                  width: 36,
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                title: Text(userName),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        badgeCount > 5 ? 5 : badgeCount,
                        (i) => const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            FontAwesomeIcons.solidStar,
                            size: 14,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '$badgeCount Rozet',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getMedalColor(int position) {
    switch (position) {
      case 0:
        return Colors.amber;
      case 1:
        return const Color(0xFFC0C0C0);
      case 2:
        return const Color(0xFFCD7F32);
      default:
        return Colors.grey;
    }
  }
}
