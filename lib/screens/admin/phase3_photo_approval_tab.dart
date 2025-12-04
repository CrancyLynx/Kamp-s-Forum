import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Phase3PhotoApprovalTab extends StatelessWidget {
  const Phase3PhotoApprovalTab({super.key});

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_rounded, size: 40, color: Colors.orange),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ring_photo_approvals')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final pendingPhotos = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("📸 Fotoğraf Onayı", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Ring fotoğrafı moderasyonu", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
              _buildStatCard("Beklemede", pendingPhotos.length.toString()),
              const SizedBox(height: 16),
              if (pendingPhotos.isEmpty)
                const Center(child: Text("Onay bekleyen fotoğraf yok"))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingPhotos.length,
                  itemBuilder: (_, i) {
                    final data = pendingPhotos[i].data() as Map<String, dynamic>;
                    return PhotoApprovalCard(
                      userId: data['userId'] ?? 'Unknown',
                      rideId: data['rideId'] ?? 'Unknown',
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

class PhotoApprovalCard extends StatelessWidget {
  final String userId;
  final String rideId;

  const PhotoApprovalCard({required this.userId, required this.rideId});

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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image_rounded, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Kullanıcı: $userId", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text("Sefer: $rideId", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.check_circle, color: Colors.green, size: 20), onPressed: () {}),
              IconButton(icon: const Icon(Icons.cancel, color: Colors.red, size: 20), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}
