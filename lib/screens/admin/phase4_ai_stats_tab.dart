import 'package:flutter/material.dart';

class Phase4AiStatsTab extends StatelessWidget {
  const Phase4AiStatsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            '🤖 Model metrikleri yükleniyor...',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}
