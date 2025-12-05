import 'package:flutter/material.dart';

class Phase4SearchAnalyticsTab extends StatefulWidget {
  const Phase4SearchAnalyticsTab({Key? key}) : super(key: key);

  @override
  State<Phase4SearchAnalyticsTab> createState() => _Phase4SearchAnalyticsTabState();
}

class _Phase4SearchAnalyticsTabState extends State<Phase4SearchAnalyticsTab> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔍 Arama Analiz',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Arama trendleri yükleniyor...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
