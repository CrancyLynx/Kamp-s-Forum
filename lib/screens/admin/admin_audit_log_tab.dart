import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Phase3AuditLogTab extends StatefulWidget {
  const Phase3AuditLogTab({super.key});

  @override
  State<Phase3AuditLogTab> createState() => _Phase3AuditLogTabState();
}

class _Phase3AuditLogTabState extends State<Phase3AuditLogTab> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admin_audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📋 Denetim Günü",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Yönetici işlemleri kaydı",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              if (logs.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.history_rounded, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text("Henüz kayıt yok", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final data = log.data() as Map<String, dynamic>;
                    final action = data['action'] ?? 'Unknown';
                    final adminId = data['adminId'] ?? 'System';
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final details = data['details'] ?? {};

                    return AuditLogCard(
                      action: action,
                      admin: adminId.substring(0, 8),
                      timestamp: timestamp,
                      details: details.toString(),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class AuditLogCard extends StatelessWidget {
  final String action;
  final String admin;
  final DateTime timestamp;
  final String details;

  const AuditLogCard({
    required this.action,
    required this.admin,
    required this.timestamp,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: _getActionColor(),
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getActionIcon(), color: _getActionColor(), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Admin: $admin",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            "Zaman: ${timestamp.toString().split('.')[0]}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Color _getActionColor() {
    if (action.contains('Delete')) return Colors.red;
    if (action.contains('Update')) return Colors.orange;
    if (action.contains('Create')) return Colors.green;
    return Colors.blue;
  }

  IconData _getActionIcon() {
    if (action.contains('Delete')) return Icons.delete_rounded;
    if (action.contains('Update')) return Icons.edit_rounded;
    if (action.contains('Create')) return Icons.add_circle_rounded;
    return Icons.info_rounded;
  }
}
