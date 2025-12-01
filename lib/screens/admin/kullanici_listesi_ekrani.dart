import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_colors.dart';
import '../profile/kullanici_profil_detay_ekrani.dart'; 

class KullaniciListesiEkrani extends StatelessWidget {
  final String? title;
  final List<dynamic>? userIds;
  final bool hideAppBar; // Admin Panelinde kullanıldığında AppBar'ı gizle

  const KullaniciListesiEkrani({
    super.key, 
    this.title, 
    this.userIds,
    this.hideAppBar = false, 
  });

  // Kullanıcıyı engelleme/engeli kaldırma - Bu işlemler AdminPanelEkrani'nda yapılır.
  // Burada sadece görüntüleme listesini döndürüyoruz.

  @override
  Widget build(BuildContext context) {
    // Eğer userIds geldiyse "Liste Modu", gelmediyse "Admin Modu"
    final bool isFilterMode = userIds != null;

    // Firestore sorgusunu sadece filtre modunda kullanıyoruz.
    Stream<QuerySnapshot> getStream() {
      if (isFilterMode && (userIds == null || userIds!.isEmpty)) {
        return Stream.empty();
      }
      
      Query query = FirebaseFirestore.instance.collection('kullanicilar');
      
      if (isFilterMode) {
        // Firestore'un "in" sorgusunda maksimum 10 eleman limiti vardır.
        // Bu yüzden listeyi 10'arlı gruplara bölmek gerekir. Ancak basitlik adına
        // burada sadece ilk 10 elemanı kullanıyoruz.
        final List<String> validIds = userIds!.map((id) => id.toString()).where((id) => id.isNotEmpty).take(10).toList();
        
        if (validIds.isEmpty) return Stream.empty();
        
        // Etkinlik katılımcıları listesi için
        query = query.where(FieldPath.documentId, whereIn: validIds);
      } else {
         // Burası AdminPanel'deki Kullanıcılar sekmesi tarafından kullanılmayacak,
         // AdminPanel kendi stream'ini yönetiyor. Bu dosya sadece harici liste göstermek için kalmalı.
         query = query.orderBy('ad', descending: false); 
      }
      
      return query.snapshots();
    }

    // Eğer filtre moduysa, başlık belirle
    final displayTitle = isFilterMode ? title ?? "Katılımcılar" : "Tüm Kullanıcılar (Admin)";


    return Scaffold(
      // AdminPanelEkrani içinde kullanılacaksa AppBar'ı gizle
      appBar: hideAppBar 
        ? null 
        : AppBar(
            title: Text(displayTitle), 
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
      
      body: StreamBuilder<QuerySnapshot>(
        stream: isFilterMode ? getStream() : FirebaseFirestore.instance.collection('kullanicilar').snapshots(), // Fallback
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return Center(child: Text("Kullanıcı bulunamadı."));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            padding: const EdgeInsets.only(top: 8),
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              final isVerified = user['verified'] == true;
              final String takmaAd = user['takmaAd'] ?? 'Anonim';
              final String fullName = user['fullName'] ?? user['ad'] ?? 'İsimsiz';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (user['avatarUrl'] != null && user['avatarUrl'] != "") 
                        ? CachedNetworkImageProvider(user['avatarUrl']) 
                        : null,
                    backgroundColor: isVerified ? Colors.green.shade100 : Colors.grey.shade200,
                    child: (user['avatarUrl'] == null || user['avatarUrl'] == "")
                        ? Icon(isVerified ? Icons.check : Icons.person, color: isVerified ? Colors.green : Colors.grey)
                        : null,
                  ),
                  title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("@$takmaAd", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
                  onTap: () {
                    // Kullanıcı profiline git
                    Navigator.push(context, MaterialPageRoute(builder: (_) => KullaniciProfilDetayEkrani(userId: userId, userName: takmaAd)));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}