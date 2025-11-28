import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_colors.dart';

class KullaniciListesiEkrani extends StatelessWidget {
  // Bu alanları isteğe bağlı (nullable) yapıyoruz
  final String? title;
  final List<dynamic>? userIds;

  const KullaniciListesiEkrani({
    super.key, 
    this.title, 
    this.userIds
  });

  @override
  Widget build(BuildContext context) {
    // Eğer userIds geldiyse "Liste Modu", gelmediyse "Admin Modu"
    final bool isFilterMode = userIds != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? "Tüm Kullanıcılar"), 
        backgroundColor: AppColors.primary
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('kullanicilar').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          // Tüm kullanıcıları al
          var users = snapshot.data!.docs;

          // EĞER FİLTRE VARSA (Takipçi/Takip listesi için)
          if (isFilterMode) {
            if (userIds!.isEmpty) {
              return const Center(child: Text("Listelenecek kullanıcı yok."));
            }
            // Sadece listedeki ID'lere sahip kullanıcıları filtrele
            users = users.where((doc) => userIds!.contains(doc.id)).toList();
          }

          if (users.isEmpty) {
             return const Center(child: Text("Kullanıcı bulunamadı."));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              final isVerified = user['verified'] == true;
              final status = user['status'] ?? 'Bilinmiyor';
              final phoneNumber = user['phoneNumber'] ?? 'Yok'; 

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (user['avatarUrl'] != null && user['avatarUrl'] != "") 
                        ? NetworkImage(user['avatarUrl']) 
                        : null,
                    backgroundColor: isVerified ? Colors.green.shade100 : Colors.grey.shade200,
                    child: (user['avatarUrl'] == null || user['avatarUrl'] == "")
                        ? Icon(isVerified ? Icons.check : Icons.person, color: isVerified ? Colors.green : Colors.grey)
                        : null,
                  ),
                  title: Text(user['fullName'] ?? user['ad'] ?? 'İsimsiz'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("@${user['takmaAd'] ?? 'anonim'}"),
                      // Sadece Admin modundaysak detayları göster
                      if (!isFilterMode) ...[
                        Text(user['email'] ?? ''),
                        Text("Tel: $phoneNumber", style: const TextStyle(fontSize: 11)),
                        Text("Durum: $status", style: TextStyle(
                          color: status == 'Pending' ? Colors.orange : (status == 'Verified' ? Colors.green : Colors.black),
                          fontWeight: FontWeight.bold
                        )),
                      ]
                    ],
                  ),
                  // "Onayla" butonu sadece Admin modunda ve bekleyen kullanıcılarda görünsün
                  trailing: (!isFilterMode && status == 'Pending') 
                    ? ElevatedButton(
                        onPressed: () => _showApprovalDialog(context, userId, user),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                        child: const Text("İncele"),
                      )
                    : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    // İsteğe bağlı: Kullanıcı profiline gitmek için buraya navigasyon eklenebilir
                    // Navigator.push(...)
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showApprovalDialog(BuildContext context, String userId, Map<String, dynamic> user) {
    final submission = user['submissionData'] as Map<String, dynamic>?;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kullanıcı Başvurusu"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("İsim: ${submission?['name']} ${submission?['surname']}"),
              Text("Üniversite: ${submission?['university']}"),
              Text("Bölüm: ${submission?['department']}"),
              Text("Yaş: ${submission?['age']}"),
              const Divider(),
              Text("Kayıtlı Telefon: ${user['phoneNumber'] ?? 'Yok'}"),
              const SizedBox(height: 10),
              const Text("SMS ile doğrulama yapmış olabilir veya manuel inceleme gerektiriyor."),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _rejectUser(context, userId);
            },
            child: const Text("Reddet", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('kullanicilar').doc(userId).update({
                'status': 'Verified',
                'verified': true,
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kullanıcı onaylandı.")));
            },
            child: const Text("Onayla"),
          ),
        ],
      ),
    );
  }

  void _rejectUser(BuildContext context, String userId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reddetme Sebebi"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: "Örn: Öğrenci belgesi geçersiz"),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('kullanicilar').doc(userId).update({
                'status': 'Rejected',
                'rejectionReason': reasonController.text,
              });
              Navigator.pop(ctx);
            },
            child: const Text("Reddet"),
          )
        ],
      ),
    );
  }
}