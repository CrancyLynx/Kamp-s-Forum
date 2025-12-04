import 'package:flutter/material.dart';

/// Kullanıcı istatistikleri ekranı
class UserStatisticsScreen extends StatefulWidget {
  const UserStatisticsScreen({super.key});

  @override
  State<UserStatisticsScreen> createState() => _UserStatisticsScreenState();
}

class _UserStatisticsScreenState extends State<UserStatisticsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İstatistikler'),
        backgroundColor: Colors.blue,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatCard('Gönderi Sayısı', '42', Icons.article),
          _buildStatCard('Yorum Sayısı', '156', Icons.comment),
          _buildStatCard('Beğeni Aldığı', '523', Icons.thumb_up),
          _buildStatCard('Takipçi Sayısı', '89', Icons.people),
          _buildStatCard('Başarı Badgesi', '12', Icons.star),
          _buildStatCard('Ait Olduğu Grup', '5', Icons.group),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
            Icon(icon, size: 48, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}
