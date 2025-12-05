import 'package:flutter/material.dart';
import '../../services/phase4_services.dart';

class Phase4RewardsTab extends StatefulWidget {
  const Phase4RewardsTab({Key? key}) : super(key: key);

  @override
  State<Phase4RewardsTab> createState() => _Phase4RewardsTabState();
}

class _Phase4RewardsTabState extends State<Phase4RewardsTab> {
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
              '🎁 Ödüller Dükkanı',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(Icons.card_giftcard, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Ödüller yükleniyor...',
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
