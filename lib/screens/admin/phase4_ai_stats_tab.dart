import 'package:flutter/material.dart';

class Phase4AIStatsTab extends StatefulWidget {
  const Phase4AIStatsTab({Key? key}) : super(key: key);

  @override
  State<Phase4AIStatsTab> createState() => _Phase4AIStatsTabState();
}

class _Phase4AIStatsTabState extends State<Phase4AIStatsTab> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🤖 AI İstatistik',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(Icons.analytics, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Model metrikleri yükleniyor...',
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
