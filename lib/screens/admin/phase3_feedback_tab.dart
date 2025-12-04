import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Phase3FeedbackTab extends StatelessWidget {
  const Phase3FeedbackTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_feedback')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final feedbacks = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("💬 Geri Bildirim", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Kullanıcı geri bildirimleri", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
              if (feedbacks.isEmpty)
                const Center(child: Text("Geri bildirim yok"))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: feedbacks.length,
                  itemBuilder: (_, i) {
                    final data = feedbacks[i].data() as Map<String, dynamic>;
                    return FeedbackCard(
                      title: data['title'] ?? 'Feedback',
                      message: data['message'] ?? '',
                      status: data['status'] ?? 'open',
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

class FeedbackCard extends StatelessWidget {
  final String title;
  final String message;
  final String status;

  const FeedbackCard({required this.title, required this.message, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(fontSize: 10, color: _getStatusColor(), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case 'open': return Colors.blue;
      case 'responded': return Colors.green;
      case 'closed': return Colors.grey;
      default: return Colors.blue;
    }
  }
}
