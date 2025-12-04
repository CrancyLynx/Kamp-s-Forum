import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../profile/kullanici_profil_detay_ekrani.dart';
import '../../utils/app_colors.dart';
import 'admin_helpers.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).delete();
      if (mounted) {
        showSnackBar(
          context: context,
          message: "✅ Kullanıcı silindi",
          color: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context: context,
          message: "❌ Hata: $e",
          color: AppColors.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: ModernSearchBar(
            controller: _searchController,
            hint: "Kullanıcı adı veya email ara...",
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('kullanicilar').orderBy('ad').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data!.docs;
              final filteredDocs = allDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final name = (data['ad'] ?? '').toString().toLowerCase();
                final takmaAd = (data['takmaAd'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                final query = _searchController.text.toLowerCase();
                return name.contains(query) || takmaAd.contains(query) || email.contains(query);
              }).toList();

              if (filteredDocs.isEmpty) {
                return EmptyState(
                  message: "Kullanıcı bulunamadı",
                  icon: Icons.person_off,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index].data() as Map<String, dynamic>;
                  final uid = filteredDocs[index].id;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (data['avatarUrl'] != null && data['avatarUrl'].toString().isNotEmpty)
                            ? CachedNetworkImageProvider(data['avatarUrl'])
                            : null,
                        backgroundColor: const Color(0xFF2C3E50).withOpacity(0.2),
                        child: data['avatarUrl'] == null
                            ? const Icon(Icons.person, color: Color(0xFF2C3E50))
                            : null,
                      ),
                      title: Text(
                        data['takmaAd'] ?? 'İsimsiz',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(data['email'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () {
                          showDeleteConfirmDialog(
                            context: context,
                            title: "Kullanıcıyı Sil",
                            message: "Bu kullanıcı kalıcı olarak silinecek. Emin misiniz?",
                            onDelete: () => _deleteUser(uid),
                          );
                        },
                      ),
                      onTap: () {
                        showUserManagementDialog(
                          context: context,
                          userName: data['takmaAd'] ?? 'Kullanıcı',
                          onViewProfile: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KullaniciProfilDetayEkrani(
                                  userId: uid,
                                  userName: data['takmaAd'],
                                ),
                              ),
                            );
                          },
                          onDelete: () {
                            showDeleteConfirmDialog(
                              context: context,
                              title: "Kullanıcıyı Sil",
                              message: "Bu kullanıcı kalıcı olarak silinecek. Emin misiniz?",
                              onDelete: () => _deleteUser(uid),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
