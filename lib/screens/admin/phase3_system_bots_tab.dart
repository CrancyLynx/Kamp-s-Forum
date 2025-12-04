import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Phase3SystemBotsTab extends StatelessWidget {
  const Phase3SystemBotsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('system_bots').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final bots = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("🤖 Sistem Botları", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              if (bots.isEmpty)
                const Center(child: Text("Bot yok"))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bots.length,
                  itemBuilder: (_, i) {
                    final data = bots[i].data() as Map<String, dynamic>;
                    return BotCard(
                      name: data['name'] ?? 'Bot',
                      status: data['status'] ?? 'inactive',
                      taskCount: data['taskCount'] ?? 0,
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

class BotCard extends StatelessWidget {
  final String name;
  final String status;
  final int taskCount;

  const BotCard({required this.name, required this.status, required this.taskCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("$taskCount görev", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (status == 'active' ? Colors.green : Colors.grey).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status == 'active' ? 'Aktif' : 'Pasif',
              style: TextStyle(fontSize: 10, color: status == 'active' ? Colors.green : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
