import 'package:flutter/material.dart';

class Phase4SearchAnalyticsTab extends StatelessWidget {
  const Phase4SearchAnalyticsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.trending_up, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            '🔍 Arama trendleri yükleniyor...',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}
