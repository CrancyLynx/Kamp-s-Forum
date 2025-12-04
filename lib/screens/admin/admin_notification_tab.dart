import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_colors.dart';
import 'admin_helpers.dart';

class AdminNotificationTab extends StatefulWidget {
  const AdminNotificationTab({super.key});

  @override
  State<AdminNotificationTab> createState() => _AdminNotificationTabState();
}

class _AdminNotificationTabState extends State<AdminNotificationTab> {
  final TextEditingController _notificationMessageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedNotificationType = 'system_message';

  @override
  void dispose() {
    _notificationMessageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendNotificationToUser(String userId, String message, String notificationType) async {
    try {
      await FirebaseFirestore.instance.collection('bildirimler').add({
        'userId': userId,
        'senderName': 'Sistem',
        'type': notificationType,
        'message': message,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        showSnackBar(context: context, message: "✅ Bildirim gönderildi", color: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context: context, message: "❌ Hata: $e", color: AppColors.error);
      }
    }
  }

  Future<void> _broadcastNotification(String message, String notificationType) async {
    try {
      final users = await FirebaseFirestore.instance.collection('kullanicilar').get();
      for (var doc in users.docs) {
        await FirebaseFirestore.instance.collection('bildirimler').add({
          'userId': doc.id,
          'senderName': 'Sistem',
          'type': notificationType,
          'message': message,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) {
        showSnackBar(
          context: context,
          message: "✅ ${users.docs.length} kullanıcıya bildirim gönderildi",
          color: AppColors.success,
        );
        _notificationMessageController.clear();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context: context, message: "❌ Hata: $e", color: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          const Text(
            "📢 Sistem Bildirimi Gönder",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Bildirim Tipi Seçimi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedNotificationType,
              items: const [
                DropdownMenuItem(value: 'system_message', child: Text('🔔 Sistem Mesajı')),
                DropdownMenuItem(value: 'warning', child: Text('⚠️ Uyarı')),
                DropdownMenuItem(value: 'update', child: Text('🔄 Güncelleme')),
                DropdownMenuItem(value: 'announcement', child: Text('📣 Duyuru')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedNotificationType = value);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Mesaj Girişi
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: TextField(
              controller: _notificationMessageController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Bildirim mesajını yazın...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Herkese Gönder Butonu
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_notificationMessageController.text.trim().isEmpty) {
                      showSnackBar(
                        context: context,
                        message: "⚠️ Mesaj boş olamaz",
                        color: AppColors.warning,
                      );
                      return;
                    }
                    await _broadcastNotification(
                      _notificationMessageController.text.trim(),
                      _selectedNotificationType,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.broadcast_on_personal),
                  label: const Text("🌍 Herkese Gönder"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Divider
          const Divider(height: 32, thickness: 1.5),

          // Belirli Kullanıcıya Gönder
          const Text(
            "👤 Belirli Kullanıcıya Gönder",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Arama Çubuğu
          ModernSearchBar(
            controller: _searchController,
            hint: "Kullanıcı adı veya email ara...",
            onClear: () => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Kullanıcı Listesi
          SizedBox(
            height: 300,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('kullanicilar').orderBy('ad').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allUsers = snapshot.data!.docs;
                final filteredUsers = allUsers.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['ad'] ?? '').toString().toLowerCase();
                  final takmaAd = (data['takmaAd'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final query = _searchController.text.toLowerCase();
                  return name.contains(query) || takmaAd.contains(query) || email.contains(query);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return EmptyState(
                    message: "Kullanıcı bulunamadı",
                    icon: Icons.person_off,
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final data = filteredUsers[index].data() as Map<String, dynamic>;
                    final uid = filteredUsers[index].id;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        subtitle: Text(
                          data['email'] ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF00BCD4)),
                          onPressed: () async {
                            if (_notificationMessageController.text.trim().isEmpty) {
                              showSnackBar(
                                context: context,
                                message: "⚠️ Mesaj boş olamaz",
                                color: AppColors.warning,
                              );
                              return;
                            }
                            await _sendNotificationToUser(
                              uid,
                              _notificationMessageController.text.trim(),
                              _selectedNotificationType,
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
