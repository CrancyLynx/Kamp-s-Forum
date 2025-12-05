import 'package:flutter/material.dart';
import '../../models/phase4_models.dart';
import '../../services/phase4_services.dart';

class Phase4AiStatsTab extends StatefulWidget {
  const Phase4AiStatsTab({Key? key}) : super(key: key);

  @override
  State<Phase4AiStatsTab> createState() => _Phase4AiStatsTabState();
}

class _Phase4AiStatsTabState extends State<Phase4AiStatsTab> {
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
              '🤖 AI Model Metrikleri',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<AIModelMetrics>>(
              stream: _services.getAIMetrics(''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Henüz model metrikleri yok',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final metric = snapshot.data![index];
                    return _buildMetricCard(metric);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(AIModelMetrics metric) {
    final accuracy = (metric.accuracy * 100).toStringAsFixed(1);
    final precision = (metric.precision * 100).toStringAsFixed(1);
    final recall = (metric.recall * 100).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy, color: Colors.green, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.modelName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${metric.totalPredictions} tahmin yapılmış',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$accuracy%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMetricRow('Accuracy', accuracy),
          const SizedBox(height: 8),
          _buildMetricRow('Precision', precision),
          const SizedBox(height: 8),
          _buildMetricRow('Recall', recall),
          const SizedBox(height: 8),
          _buildMetricRow(
            'Avg Response',
            '${metric.averageResponseTime.toStringAsFixed(2)}ms',
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Doğru: ${metric.correctPredictions}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Hatalı: ${metric.totalPredictions - metric.correctPredictions}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }
}
