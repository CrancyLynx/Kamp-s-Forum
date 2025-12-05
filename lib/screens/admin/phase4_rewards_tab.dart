import 'package:flutter/material.dart';

class Phase4RewardsTab extends StatelessWidget {
  const Phase4RewardsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.card_giftcard, size: 64, color: Colors.purple),
          const SizedBox(height: 16),
          Text(
            '🎁 Ödüller yükleniyor...',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}
