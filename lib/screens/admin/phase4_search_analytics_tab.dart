import 'package:flutter/material.dart';
import '../../models/phase4_models.dart';
import '../../services/phase4_services.dart';

class Phase4SearchAnalyticsTab extends StatefulWidget {
  const Phase4SearchAnalyticsTab({Key? key}) : super(key: key);

  @override
  State<Phase4SearchAnalyticsTab> createState() =>
      _Phase4SearchAnalyticsTabState();
}

class _Phase4SearchAnalyticsTabState extends State<Phase4SearchAnalyticsTab> {
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
              '🔍 Arama Trendleri',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<SearchTrend>>(
              stream: _services.getSearchTrends(''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Henüz arama verisi yok',
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
                    final trend = snapshot.data![index];
                    return _buildTrendCard(trend, index + 1);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard(SearchTrend trend, int rank) {
    final maxScore = 100.0;
    final progress = (trend.trendScore / maxScore).clamp(0.0, 1.0);

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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getRankColor(rank),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trend.query,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${trend.searchCount}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  Text(
                    'Arama',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getTrendColor(progress),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Trend Skoru: ${trend.trendScore.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber[600]!;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.orange[600]!;
      default:
        return Colors.blue[400]!;
    }
  }

  Color _getTrendColor(double progress) {
    if (progress > 0.7) return Colors.red;
    if (progress > 0.4) return Colors.orange;
    return Colors.blue;
  }
}
