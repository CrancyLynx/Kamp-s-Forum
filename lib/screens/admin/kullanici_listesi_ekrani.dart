import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Düzeltilmiş Importlar
import '../../utils/app_colors.dart';
import '../profile/kullanici_profil_detay_ekrani.dart';


class KullaniciListesiEkrani extends StatelessWidget {
  final String title;
  final List<dynamic> userIds; // List<String> yerine dynamic yaptık ki hata almasın

  const KullaniciListesiEkrani({super.key, required this.title, required this.userIds});

  @override
  Widget build(BuildContext context) {
    // String listesine güvenli çevirim
    final List<String> safeUserIds = userIds.map((e) => e.toString()).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primary,
      ),
      body: safeUserIds.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text("Kimse yok...", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: safeUserIds.length,
              itemBuilder: (context, index) {
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('kullanicilar').doc(safeUserIds[index]).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const SizedBox.shrink(); // Veri gelene kadar boşluk
                    }
                    
                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    final String userName = userData['takmaAd'] ?? userData['ad'] ?? 'Kullanıcı';
                    final String? avatarUrl = userData['avatarUrl'];
                    final String userId = snapshot.data!.id;
                    final String realName = userData['ad'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) 
                            ? NetworkImage(avatarUrl) 
                            : null,
                        backgroundColor: AppColors.primaryLight,
                        child: (avatarUrl == null || avatarUrl.isEmpty) 
                            ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary)) 
                            : null,
                      ),
                      title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(realName),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        // Tıklanan kişiye git
                        Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (context) => KullaniciProfilDetayEkrani(
                              userId: userId == FirebaseAuth.instance.currentUser?.uid ? null : userId,
                              userName: userName,
                            )
                          )
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