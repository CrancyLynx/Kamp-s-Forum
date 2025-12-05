// lib/screens/admin/admin_moderation_logs_tab.dart
import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/admin_services.dart';

class ModerationLogsTab extends StatefulWidget {
  const ModerationLogsTab({Key? key}) : super(key: key);

  @override
  State<ModerationLogsTab> createState() => _ModerationLogsTabState();
}

class _ModerationLogsTabState extends State<ModerationLogsTab> {
  String _filterType = 'create';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Denetleme Günlükleri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<List<AuditLog>>(
        stream: AuditLogService.getActionsByType(_filterType),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Günlük bulunamadı'));
          }

          final logs = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return _buildLogCard(log);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogCard(AuditLog log) {
    final Color actionColor = _getActionColor(log.action);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      _getActionIcon(log.action),
                      color: actionColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.action,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        log.adminName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              log.targetType,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text(
                  log.timestamp.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'delete':
        return Colors.red;
      case 'edit':
      case 'update':
        return Colors.blue;
      case 'create':
        return Colors.green;
      case 'view':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'delete':
        return Icons.delete;
      case 'edit':
      case 'update':
        return Icons.edit;
      case 'create':
        return Icons.add;
      case 'view':
        return Icons.visibility;
      default:
        return Icons.help;
    }
  }
}
