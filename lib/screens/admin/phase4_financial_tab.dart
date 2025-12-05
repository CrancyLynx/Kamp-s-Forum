import 'package:flutter/material.dart';

class Phase4FinancialTab extends StatelessWidget {
  const Phase4FinancialTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.attach_money,
            size: 64,
            color: Color(0xFF4CAF50),
          ),
          const SizedBox(height: 16),
          Text(
            '💰 Finansal Raporlar',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C3E50),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gelir/Gider Takibi',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}
