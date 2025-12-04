import 'package:flutter/material.dart';
import '../../models/phase2_models.dart';
import '../../services/phase2_services.dart';
import '../../utils/app_colors.dart';

/// Kullanıcı aktivite zaman çizelgesi ekranı
class ActivityTimelineScreen extends StatefulWidget {
  final String userId;

  const ActivityTimelineScreen({super.key, required this.userId});

  @override
  State<ActivityTimelineScreen> createState() => _ActivityTimelineScreenState();
}

class _ActivityTimelineScreenState extends State<ActivityTimelineScreen> {
  String _filterType = 'all';

  final Map<String, String> _typeLabels = {
    'all': 'Tümü',
    'post': '📝 Gönderi',
    'comment': '💬 Yorum',
    'vote': '👍 Oy',
    'join': '👋 Katılma',
    'achievement': '🏆 Başarı',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktivite Geçmişi'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Filtre butonları
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: _typeLabels.keys.map((type) {
                final isSelected = _filterType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_typeLabels[type] ?? type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _filterType = selected ? type : 'all');
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: AppColors.primary.withValues(alpha: 0.3),
                  ),
                );
              }).toList(),
            ),
          ),

          // Aktivite listesi
          Expanded(
            child: StreamBuilder<List<ActivityTimeline>>(
              stream: _filterType == 'all'
                  ? ActivityTimelineService.getUserActivityTimeline(widget.userId)
                  : ActivityTimelineService.getActivityByType(widget.userId, _filterType),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final activities = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return _buildActivityCard(activity);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(ActivityTimeline activity) {
    final icon = _getIconForActivity(activity.activityType);
    final color = _getColorForActivity(activity.activityType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İkon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),

            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.description,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(activity.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Henüz aktivite yok',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  IconData _getIconForActivity(String type) {
    switch (type.toLowerCase()) {
      case 'post':
        return Icons.article;
      case 'comment':
        return Icons.comment;
      case 'vote':
        return Icons.thumb_up;
      case 'join':
        return Icons.person_add;
      case 'achievement':
        return Icons.emoji_events;
      default:
        return Icons.info;
    }
  }

  Color _getColorForActivity(String type) {
    switch (type.toLowerCase()) {
      case 'post':
        return Colors.blue;
      case 'comment':
        return Colors.green;
      case 'vote':
        return Colors.orange;
      case 'join':
        return Colors.purple;
      case 'achievement':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} dakika önce';
      }
      return '${diff.inHours} saat önce';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}
