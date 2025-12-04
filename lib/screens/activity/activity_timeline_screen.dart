import 'package:flutter/material.dart';
import '../../models/phase2_models.dart';
import '../../services/phase2_services.dart';

/// Aktivite Zaman Çizelgesi
class ActivityTimelineScreen extends StatefulWidget {
  const ActivityTimelineScreen({super.key});

  @override
  State<ActivityTimelineScreen> createState() => _ActivityTimelineScreenState();
}

class _ActivityTimelineScreenState extends State<ActivityTimelineScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 Aktivite Zaman Çizelgesi'),
        backgroundColor: const Color(0xFF2C3E50),
      ),
      body: StreamBuilder<List<ActivityTimeline>>(
        stream: ActivityTimelineService.getActivityTimeline().asStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final activities = snapshot.data ?? [];

          if (activities.isEmpty) {
            return const Center(child: Text('Aktivite bulunamadı'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(activity.activityType[0])),
                  title: Text(activity.activityType),
                  subtitle: Text(_formatDate(activity.timestamp)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
