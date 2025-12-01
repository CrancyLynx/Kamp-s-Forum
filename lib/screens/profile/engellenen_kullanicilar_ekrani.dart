import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EngellenenKullanicilarEkrani extends StatelessWidget {
  const EngellenenKullanicilarEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Engellenenler")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('kullanicilar').doc(currentUserId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final blockedIds = List<String>.from(data['blockedUsers'] ?? []);

          if (blockedIds.isEmpty) {
            return const Center(child: Text("Engellenen kullanıcı yok."));
          }

          return ListView.builder(
            itemCount: blockedIds.length,
            itemBuilder: (context, index) {
              final blockedId = blockedIds[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('kullanicilar').doc(blockedId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox.shrink();
                  final userData = userSnap.data!.data() as Map<String, dynamic>?;
                  final name = userData?['takmaAd'] ?? 'Bilinmeyen Kullanıcı';

                  return ListTile(
                    title: Text(name),
                    trailing: TextButton(
                      child: const Text("Engeli Kaldır"),
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('kullanicilar').doc(currentUserId).update({
                          'blockedUsers': FieldValue.arrayRemove([blockedId])
                        });
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
