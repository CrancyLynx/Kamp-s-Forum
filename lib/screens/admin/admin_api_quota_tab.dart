import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Phase3ApiQuotaTab extends StatefulWidget {
  const Phase3ApiQuotaTab({super.key});

  @override
  State<Phase3ApiQuotaTab> createState() => _Phase3ApiQuotaTabState();
}

class _Phase3ApiQuotaTabState extends State<Phase3ApiQuotaTab> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('system_config')
          .doc('vision_api')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final config = snapshot.data!.data() as Map<String, dynamic>?;
        final enabled = config?['enabled'] ?? false;
        final fallbackStrategy = config?['fallbackStrategy'] ?? 'deny';

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('vision_api_quota')
              .doc('2025_12')
              .get(),
          builder: (context, quotaSnapshot) {
            final quotaData = quotaSnapshot.data?.data() as Map<String, dynamic>?;
            final used = (quotaData?['usageCount'] ?? 0) as int;
            final limit = 1000; // Aylık sınır
            final percentage = (used / limit * 100).toStringAsFixed(1);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "📊 Vision API Kontenjanı",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Aylık kullanım takibi",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  // Durum Kartı
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: enabled ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: enabled ? Colors.green : Colors.red,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          enabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 40,
                          color: enabled ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "API Durumu",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: enabled ? Colors.green : Colors.red,
                                ),
                              ),
                              Text(
                                enabled ? "Aktif ✅" : "Pasif ❌",
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Quota Progress
                  Text(
                    "Aylık Kullanım ($used / $limit)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: used / limit,
                      minHeight: 12,
                      backgroundColor: Colors.grey.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        used / limit > 0.8 ? Colors.red : Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$percentage% kullanıldı",
                    style: TextStyle(
                      fontSize: 12,
                      color: (used as int) / limit > 0.8 ? Colors.red : Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Fallback Stratejisi
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "⚙️ Fallback Stratejisi",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          fallbackStrategy.toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getFallbackColor(fallbackStrategy),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getFallbackDescription(fallbackStrategy),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Bilgi Kartı
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "ℹ️ Bilgi",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "• Aylık 1000 free request\n"
                          "• Sonrası: \$3.50/1000\n"
                          "• Admin kontrol edilebilir\n"
                          "• Audit trail kaydı tutulur",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
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

  Color _getFallbackColor(String strategy) {
    switch (strategy) {
      case 'deny':
        return Colors.red;
      case 'allow':
        return Colors.green;
      case 'warn':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getFallbackDescription(String strategy) {
    switch (strategy) {
      case 'deny':
        return 'Quota aşıldığında istekler reddedilir';
      case 'allow':
        return 'Quota aşıldığında istekler yine de işlenir';
      case 'warn':
        return 'Quota aşıldığında uyarı gösterilir';
      default:
        return 'Bilinmeyen strateji';
    }
  }
}
