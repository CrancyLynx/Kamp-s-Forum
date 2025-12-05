import 'package:flutter/material.dart';

class Phase4FinancialTab extends StatelessWidget {
  const Phase4FinancialTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.attach_money, size: 64, color: Colors.greenAccent),
          const SizedBox(height: 16),
          Text(
            '💰 Finansal raporlar yükleniyor...',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}
