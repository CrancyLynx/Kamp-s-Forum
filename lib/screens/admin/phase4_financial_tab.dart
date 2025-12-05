import 'package:flutter/material.dart';

class Phase4FinancialTab extends StatefulWidget {
  const Phase4FinancialTab({Key? key}) : super(key: key);

  @override
  State<Phase4FinancialTab> createState() => _Phase4FinancialTabState();
}

class _Phase4FinancialTabState extends State<Phase4FinancialTab> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💰 Finansal Rapor',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(Icons.receipt, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Finansal raporlar yükleniyor...',
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
