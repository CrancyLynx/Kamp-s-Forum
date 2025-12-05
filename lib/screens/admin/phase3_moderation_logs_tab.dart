// lib/screens/admin/phase3_moderation_logs_tab.dart
import 'package:flutter/material.dart';
import '../../models/phase3_complete_models.dart';
import '../../services/phase3_complete_services.dart';

class ModerationLogsTab extends StatefulWidget {
  const ModerationLogsTab({Key? key}) : super(key: key);

  @override
  State<ModerationLogsTab> createState() => _ModerationLogsTabState();
}

class _ModerationLogsTabState extends State<ModerationLogsTab> {
  final AuditLogService _auditService = AuditLogService();
  List<AuditLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _auditService.getRecentLogs(limit: 100);
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Denetleme Günlükleri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('Günlük bulunamadı'))
              : RefreshIndicator(
                  onRefresh: _loadLogs,
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return _buildLogCard(log);
                    },
                  ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    log.details,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text(log.status),
                  backgroundColor: log.status == 'completed' ? Colors.green.shade100 : Colors.orange.shade100,
                ),
              ],
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
        return Colors.blue;
      case 'create':
        return Colors.green;
      case 'suspend':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'delete':
        return Icons.delete;
      case 'edit':
        return Icons.edit;
      case 'create':
        return Icons.add;
      case 'suspend':
        return Icons.block;
      default:
        return Icons.description;
    }
  }
}
