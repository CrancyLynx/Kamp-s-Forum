import 'package:flutter/material.dart';
import '../../services/phase4_services.dart';

class Phase4AchievementsTab extends StatefulWidget {
  const Phase4AchievementsTab({Key? key}) : super(key: key);

  @override
  State<Phase4AchievementsTab> createState() => _Phase4AchievementsTabState();
}

class _Phase4AchievementsTabState extends State<Phase4AchievementsTab> {
  late Phase4Services _services;

  @override
  void initState() {
    super.initState();
    _services = Phase4Services();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏆 Başarılar',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(Icons.emoji_events, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Başarılar yükleniyor...',
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
