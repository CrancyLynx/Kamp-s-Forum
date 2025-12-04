import 'package:flutter/material.dart';

/// Vision API Kota Monitor ekranı
class VisionQuotaMonitorScreen extends StatefulWidget {
  const VisionQuotaMonitorScreen({super.key});

  @override
  State<VisionQuotaMonitorScreen> createState() =>
      _VisionQuotaMonitorScreenState();
}

class _VisionQuotaMonitorScreenState extends State<VisionQuotaMonitorScreen> {
  @override
  Widget build(BuildContext context) {
    final quotaUsed = 7500;
    final quotaTotal = 10000;
    final quotaPercent = quotaUsed / quotaTotal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision API Kota'),
        backgroundColor: Colors.blue,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Ana Kota Kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bu Ay Kullanılan Kota',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$quotaUsed / $quotaTotal',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: quotaPercent,
                      minHeight: 12,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        quotaPercent > 0.8 ? Colors.red : Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(quotaPercent * 100).toStringAsFixed(1)}% kullanıldı',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // İstatistikler
          _buildStatCard('Kalan Kota', '${quotaTotal - quotaUsed}'),
          const SizedBox(height: 12),
          _buildStatCard('Gün Başına Ortalama', '250'),
          const SizedBox(height: 12),
          _buildStatCard('Tahmini Bitiş Tarihi', '20 Aralık'),
          const SizedBox(height: 20),

          // Kullanım Geçmişi
          const Text(
            'Son 7 Günün Kullanımı',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildUsageRow('Pazartesi', 200),
                  _buildUsageRow('Salı', 150),
                  _buildUsageRow('Çarşamba', 300),
                  _buildUsageRow('Perşembe', 250),
                  _buildUsageRow('Cuma', 280),
                  _buildUsageRow('Cumartesi', 100),
                  _buildUsageRow('Pazar', 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageRow(String day, int usage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day),
          Text('$usage', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
