import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Phase3BlockedUsersTab extends StatelessWidget {
  const Phase3BlockedUsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('blocked_users')
          .orderBy('blockedAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final blocked = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("🔒 Engellenenler", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildStatCard("Toplam Engelleme", blocked.length.toString(), Colors.red),
              const SizedBox(height: 16),
              if (blocked.isEmpty)
                const Center(child: Text("Engellenen kullanıcı yok"))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: blocked.length,
                  itemBuilder: (_, i) {
                    final data = blocked[i].data() as Map<String, dynamic>;
                    return BlockedUserCard(
                      blockedUserId: data['blockedUserId'] ?? 'Unknown',
                      reason: data['reason'] ?? 'Nedensiz',
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.block_rounded, size: 40, color: color),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class BlockedUserCard extends StatelessWidget {
  final String blockedUserId;
  final String reason;

  const BlockedUserCard({required this.blockedUserId, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: Colors.red, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(blockedUserId.substring(0, 8), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(reason, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
