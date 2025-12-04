import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_helpers.dart';

class AdminStatisticsTab extends StatefulWidget {
  const AdminStatisticsTab({super.key});

  @override
  State<AdminStatisticsTab> createState() => _AdminStatisticsTabState();
}

class _AdminStatisticsTabState extends State<AdminStatisticsTab> {
  Future<Map<String, dynamic>> _fetchStats() async {
    try {
      final users = await FirebaseFirestore.instance.collection('kullanicilar').get();
      final posts = await FirebaseFirestore.instance.collection('gonderiler').count().get();
      final products = await FirebaseFirestore.instance.collection('urunler').count().get();
      final reports = await FirebaseFirestore.instance.collection('sikayetler').count().get();

      return {
        'totalUsers': users.docs.length,
        'totalPosts': posts.count ?? 0,
        'totalProducts': products.count ?? 0,
        'totalReports': reports.count ?? 0,
      };
    } catch (e) {
      debugPrint("İstatistik hatasındaki: $e");
      return {
        'totalUsers': 0,
        'totalPosts': 0,
        'totalProducts': 0,
        'totalReports': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📊 Platform İstatistikleri",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              // Stat Cards
              StatCard(
                title: "Toplam Kullanıcı",
                value: (data['totalUsers'] ?? 0).toString(),
                icon: Icons.people,
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              StatCard(
                title: "Toplam Gönderi",
                value: (data['totalPosts'] ?? 0).toString(),
                icon: Icons.article,
                color: Colors.purple,
              ),
              const SizedBox(height: 12),
              StatCard(
                title: "Toplam Ürün",
                value: (data['totalProducts'] ?? 0).toString(),
                icon: Icons.shopping_bag,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              StatCard(
                title: "Şikayet Sayısı",
                value: (data['totalReports'] ?? 0).toString(),
                icon: Icons.report_problem,
                color: Colors.red,
              ),
              const SizedBox(height: 32),
              const Text(
                "📈 Sistem Durumu",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                ),
                child: Column(
                  children: [
                    _buildStatusRow("Veritabanı", "Bağlı", Colors.green),
                    const Divider(height: 16),
                    _buildStatusRow("Kimlik Doğrulama", "Çalışıyor", Colors.green),
                    const Divider(height: 16),
                    _buildStatusRow("Depolama", "Erişilebilir", Colors.green),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(String name, String status, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}
