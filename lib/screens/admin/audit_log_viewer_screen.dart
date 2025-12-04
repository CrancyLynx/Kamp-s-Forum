import 'package:flutter/material.dart';

/// Denetim günlüğü viewer ekranı
class AuditLogViewerScreen extends StatefulWidget {
  const AuditLogViewerScreen({super.key});

  @override
  State<AuditLogViewerScreen> createState() => _AuditLogViewerScreenState();
}

class _AuditLogViewerScreenState extends State<AuditLogViewerScreen> {
  final List<Map<String, dynamic>> auditLogs = [
    {
      'action': 'Kullanıcı Silinmiş',
      'actor': 'admin_user',
      'target': 'user_123',
      'timestamp': '2025-12-04 14:30',
      'severity': 'High',
    },
    {
      'action': 'Gönderi Onaylandı',
      'actor': 'moderator_001',
      'target': 'post_456',
      'timestamp': '2025-12-04 13:15',
      'severity': 'Medium',
    },
    {
      'action': 'Forum Kuralı Güncellendi',
      'actor': 'admin_user',
      'target': 'rule_789',
      'timestamp': '2025-12-04 11:45',
      'severity': 'Low',
    },
    {
      'action': 'Yorum Raporlandı',
      'actor': 'user_456',
      'target': 'comment_999',
      'timestamp': '2025-12-04 10:20',
      'severity': 'Medium',
    },
    {
      'action': 'İçerik Filtrelendi',
      'actor': 'system',
      'target': 'post_111',
      'timestamp': '2025-12-04 09:00',
      'severity': 'Low',
    },
  ];

  String _selectedSeverity = 'Tümü';

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedSeverity == 'Tümü'
        ? auditLogs
        : auditLogs
            .where((log) => log['severity'] == _selectedSeverity)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Denetim Günlüğü'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: ['Tümü', 'High', 'Medium', 'Low']
                  .map((severity) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(severity),
                          selected: severity == _selectedSeverity,
                          onSelected: (v) {
                            if (v) {
                              setState(() => _selectedSeverity = severity);
                            }
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (ctx, idx) {
                final log = filtered[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              log['action'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Chip(
                              label: Text(log['severity']),
                              backgroundColor: _getSeverityColor(log['severity']),
                              labelStyle: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Yapan: ${log['actor']}'),
                        Text('Hedef: ${log['target']}'),
                        const SizedBox(height: 4),
                        Text(
                          log['timestamp'],
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}
