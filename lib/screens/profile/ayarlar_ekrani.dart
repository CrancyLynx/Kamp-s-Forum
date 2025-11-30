import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../main.dart'; // ThemeProvider için
import '../../utils/app_colors.dart';
import '../auth/giris_ekrani.dart';

class AyarlarEkrani extends StatelessWidget {
  const AyarlarEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Ayarlar")),
      body: ListView(
        children: [
          // Tema Ayarı
          SwitchListTile(
            title: const Text("Karanlık Mod"),
            value: themeProvider.themeMode == ThemeMode.dark,
            onChanged: (val) {
              themeProvider.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
            },
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),
          
          // Engellenen Kullanıcılar
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: const Text("Engellenen Kullanıcılar"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const EngellenenlerListesi()));
            },
          ),
          const Divider(),

          // Çıkış Yap
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.grey),
            title: const Text("Çıkış Yap"),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const GirisEkrani()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class EngellenenlerListesi extends StatelessWidget {
  const EngellenenlerListesi({super.key});

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

          // Engellenenlerin detaylarını çekmek için FutureBuilder kullanıyoruz
          // (Not: Çok fazla engellenen varsa bu sorgu optimize edilmeli, şimdilik ID'den çekiyoruz)
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