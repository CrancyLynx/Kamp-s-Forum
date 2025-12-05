import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Phase3ErrorLogsTab extends StatelessWidget {
  const Phase3ErrorLogsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('error_logs')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final logs = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("🐛 Hata Raporları", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Sistem hataları ve tanılamalar", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
              if (logs.isEmpty)
                const Center(child: Text("Hata kaydı yok"))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  itemBuilder: (_, i) {
                    final data = logs[i].data() as Map<String, dynamic>;
                    return ErrorLogCard(
                      title: data['title'] ?? 'Error',
                      message: data['message'] ?? '',
                      severity: data['severity'] ?? 'info',
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

class ErrorLogCard extends StatelessWidget {
  final String title;
  final String message;
  final String severity;

  const ErrorLogCard({required this.title, required this.message, required this.severity});

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
            color: _getSeverityColor(),
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(severity.toUpperCase(), style: TextStyle(fontSize: 10, color: _getSeverityColor(), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getSeverityColor() {
    switch (severity) {
      case 'critical': return Colors.red;
      case 'error': return Colors.orange;
      case 'warning': return Colors.yellow;
      default: return Colors.blue;
    }
  }
}
