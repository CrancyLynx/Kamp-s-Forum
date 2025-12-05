import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Pazarda satıcının puanını ve istatistiklerini gösteren widget
class MarketSellerStatsWidget extends StatelessWidget {
  final String sellerUserId;

  const MarketSellerStatsWidget({
    Key? key,
    required this.sellerUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_points')
          .doc(sellerUserId)
          .snapshots(),
      builder: (context, pointsSnapshot) {
        if (!pointsSnapshot.hasData) {
          return const SizedBox(height: 20);
        }

        final pointsData = pointsSnapshot.data?.data() as Map<String, dynamic>?;
        final totalPoints = (pointsData?['totalPoints'] ?? 0) as int;
        final level = (pointsData?['level'] ?? 1) as int;

        // Satıcı istatistiklerini al
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('markets')
              .where('sellerUserId', isEqualTo: sellerUserId)
              .snapshots(),
          builder: (context, productsSnapshot) {
            final totalProducts = productsSnapshot.data?.docs.length ?? 0;
            final soldCount = (productsSnapshot.data?.docs ?? [])
                .where((doc) => (doc['isSold'] ?? false) as bool)
                .length;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Level Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 12, color: Colors.blue),
                        const SizedBox(width: 3),
                        Text(
                          'L$level',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Sold Count Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: Colors.green),
                        const SizedBox(width: 3),
                        Text(
                          '$soldCount/$totalProducts',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Points Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on_rounded, size: 12, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          '$totalPoints',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
