import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';
import '../../services/ring_moderation_service.dart';
import '../../services/ring_notification_service.dart';
import '../profile/kullanici_profil_detay_ekrani.dart';
import '../forum/gonderi_detay_ekrani.dart';
import '../market/urun_detay_ekrani.dart';
import 'etkinlik_listesi_ekrani.dart';

class AdminPanelEkrani extends StatefulWidget {
  const AdminPanelEkrani({super.key});
  @override
  State<AdminPanelEkrani> createState() => _AdminPanelEkraniState();
}

class _AdminPanelEkraniState extends State<AdminPanelEkrani> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notificationMessageController = TextEditingController();
  String _searchQuery = "";
  String _selectedNotificationType = 'system_message';
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isLoadingAuth = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _tabController = TabController(length: 7, vsync: this);
    _searchController.addListener(() {
      if(mounted) setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  Future<void> _checkAdminAccess() async {
    if (_currentUserId.isEmpty) {
      if (mounted) setState(() { _isAdmin = false; _isLoadingAuth = false; });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId).get();
      if (doc.exists) {
        final role = doc.data()?['role'];
        if (mounted) setState(() { _isAdmin = (role == 'admin'); _isLoadingAuth = false; });
      } else {
        if (mounted) setState(() { _isAdmin = false; _isLoadingAuth = false; });
      }
    } catch (e) {
      debugPrint("Admin yetki hatası: $e");
      if (mounted) setState(() { _isAdmin = false; _isLoadingAuth = false; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _notificationMessageController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _sendNotificationToUser(String userId, String message, String notificationType) async {
    try {
      await FirebaseFirestore.instance.collection('bildirimler').add({
        'userId': userId, 'senderName': 'Sistem', 'type': notificationType,
        'message': message, 'isRead': false, 'timestamp': FieldValue.serverTimestamp(),
      });
      _showSnack("Bildirim gönderildi.", AppColors.success);
    } catch (e) {
      _showSnack("Bildirim gönderme hatası: $e", AppColors.error);
    }
  }

  Future<void> _broadcastNotification(String message, String notificationType) async {
    try {
      final users = await FirebaseFirestore.instance.collection('kullanicilar').get();
      for (var doc in users.docs) {
        await FirebaseFirestore.instance.collection('bildirimler').add({
          'userId': doc.id, 'senderName': 'Sistem', 'type': notificationType,
          'message': message, 'isRead': false, 'timestamp': FieldValue.serverTimestamp(),
        });
      }
      _showSnack("${users.docs.length} kullanıcıya bildirim gönderildi.", AppColors.success);
    } catch (e) {
      _showSnack("Broadcast hatası: $e", AppColors.error);
    }
  }

  Future<void> _deleteContent(String collection, String docId, String successMsg) async {
    try {
      if (collection == 'users') {
        try {
          final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('deleteUserAccount');
          await callable.call({'userId': docId});
        } catch (_) {
          await FirebaseFirestore.instance.collection('kullanicilar').doc(docId).delete();
        }
      } else {
        await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
      }
      _showSnack(successMsg, AppColors.success);
    } catch (e) {
      _showSnack("Silme hatası: $e", AppColors.error);
    }
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    final users = await FirebaseFirestore.instance.collection('kullanicilar').get();
    final posts = await FirebaseFirestore.instance.collection('gonderiler').count().get();
    return {'totalUsers': users.docs.length, 'totalPosts': posts.count ?? 0};
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAuth) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_isAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.gpp_bad_outlined, size: 80, color: AppColors.error),
              SizedBox(height: 16),
              Text("Erişim Reddedildi", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text("Bu sayfayı görüntülemek için yönetici yetkisine sahip olmalısınız.", 
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.greyText)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text("Yönetim Paneli", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
              ],
            ),
            backgroundColor: AppColors.primary,
            centerTitle: false,
            pinned: true,
            floating: true,
            elevation: 2,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.primaryAccent,
              indicatorWeight: 4,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              tabs: const [
                Tab(icon: Icon(Icons.notifications_active_rounded), text: "Bildirim"),
                Tab(icon: Icon(Icons.change_circle_rounded), text: "Talepler"),
                Tab(icon: Icon(Icons.group_rounded), text: "Kullanıcılar"),
                Tab(icon: Icon(Icons.report_problem_rounded), text: "Şikayetler"),
                Tab(icon: Icon(Icons.event_note_rounded), text: "Etkinlikler"),
                Tab(icon: Icon(Icons.directions_bus_rounded), text: "Ring Modü"),
                Tab(icon: Icon(Icons.bar_chart_rounded), text: "İstatistik"),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildNotificationTab(),
            _buildRequestsList(),
            _buildUserList(),
            _buildReportsList(),
            const EtkinlikListesiEkrani(),
            _buildRingModerationTab(),
            _buildStatistics(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Sistem Bildirimi Gönder", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedNotificationType,
              items: const [
                DropdownMenuItem(value: 'system_message', child: Text('Sistem Mesajı')),
                DropdownMenuItem(value: 'warning', child: Text('Uyarı')),
                DropdownMenuItem(value: 'update', child: Text('Güncelleme')),
                DropdownMenuItem(value: 'announcement', child: Text('Duyuru')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedNotificationType = value);
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: TextField(
              controller: _notificationMessageController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Bildirim mesajını yazın...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_notificationMessageController.text.trim().isEmpty) {
                      _showSnack("Mesaj boş olamaz", AppColors.warning);
                      return;
                    }
                    await _broadcastNotification(_notificationMessageController.text.trim(), _selectedNotificationType);
                    _notificationMessageController.clear();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.send),
                  label: const Text("Herkese Gönder"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          const Text("Belirli Kullanıcıya Gönder", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.all(12), child: _buildModernSearchBar(_searchController, "Kullanıcı Ara...")),
          SizedBox(
            height: 300,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('kullanicilar').orderBy('ad').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final allUsers = snapshot.data!.docs;
                final filteredUsers = allUsers.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['ad'] ?? '').toString().toLowerCase();
                  final takmaAd = (data['takmaAd'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || takmaAd.contains(_searchQuery);
                }).toList();
                if (filteredUsers.isEmpty) return _buildEmptyState("Kullanıcı bulunamadı", Icons.person_off);
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
                              ? CachedNetworkImageProvider(data['avatarUrl']) : null,
                          backgroundColor: AppColors.primaryLight,
                          child: data['avatarUrl'] == null ? const Icon(Icons.person, color: AppColors.primary) : null,
                        ),
                        title: Text(data['takmaAd'] ?? 'İsimsiz', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(data['email'] ?? '', style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.send, color: AppColors.primary),
                          onPressed: () async {
                            if (_notificationMessageController.text.trim().isEmpty) {
                              _showSnack("Mesaj boş olamaz", AppColors.warning);
                              return;
                            }
                            await _sendNotificationToUser(uid, _notificationMessageController.text.trim(), _selectedNotificationType);
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

  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('degisiklik_istekleri').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return _buildEmptyState("Talep yok.", Icons.mark_email_read);
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.edit_note, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(data['userName'] ?? 'Kullanıcı', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      if(data['timestamp'] != null) Text(timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'tr'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                    const Divider(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("ESKİ BİLGİ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(data['oldUniversity'] ?? '-', style: const TextStyle(fontSize: 14)),
                          Text(data['oldDepartment'] ?? '-', style: const TextStyle(fontSize: 14)),
                        ])),
                        const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          const Text("YENİ BİLGİ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                          const SizedBox(height: 4),
                          Text(data['newUniversity'] ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.end),
                          Text(data['newDepartment'] ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.end),
                        ])),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      OutlinedButton(
                        onPressed: () => _deleteContent('degisiklik_istekleri', doc.id, 'Talep silindi'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                        child: const Text("Reddet"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('kullanicilar').doc(data['userId']).update({
                            'submissionData.university': data['newUniversity'],
                            'submissionData.department': data['newDepartment'],
                            'universite': data['newUniversity'],
                            'bolum': data['newDepartment'],
                          });
                          await doc.reference.delete();
                          _showSnack("Bilgiler güncellendi.", AppColors.success);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                        child: const Text("Onayla"),
                      ),
                    ])
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserList() {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12.0), child: _buildModernSearchBar(_searchController, "Kullanıcı Ara...")),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('kullanicilar').orderBy('ad').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final allDocs = snapshot.data!.docs;
            final filteredDocs = allDocs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final name = (data['ad'] ?? '').toString().toLowerCase();
              final takmaAd = (data['takmaAd'] ?? '').toString().toLowerCase();
              return name.contains(_searchQuery) || takmaAd.contains(_searchQuery);
            }).toList();
            if (filteredDocs.isEmpty) return _buildEmptyState("Kullanıcı bulunamadı", Icons.person_off);
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final data = filteredDocs[index].data() as Map<String, dynamic>;
                final uid = filteredDocs[index].id;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (data['avatarUrl'] != null && data['avatarUrl'].toString().isNotEmpty) ? CachedNetworkImageProvider(data['avatarUrl']) : null,
                      backgroundColor: AppColors.primaryLight,
                      child: data['avatarUrl'] == null ? const Icon(Icons.person, color: AppColors.primary) : null,
                    ),
                    title: Text(data['takmaAd'] ?? 'İsimsiz', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(data['email'] ?? ''),
                    trailing: IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () => _showDeleteConfirm(uid, 'users')),
                    onTap: () => _showUserManagementDialog(data, uid),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildReportsList() {
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(12.0), child: _buildModernSearchBar(_searchController, 'Şikayet Ara...')),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('sikayetler').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}", style: const TextStyle(color: AppColors.error)));
              final allDocs = snapshot.data!.docs;
              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final title = (data['targetTitle'] ?? data['postTitle'] ?? '').toString().toLowerCase();
                final reason = (data['reason'] ?? '').toString().toLowerCase();
                return title.contains(_searchQuery) || reason.contains(_searchQuery);
              }).toList();
              if (docs.isEmpty) return _buildEmptyState("Şikayet yok", Icons.security);
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final String type = data['targetType'] ?? 'post';
                  String typeLabel = 'Gönderi';
                  IconData typeIcon = Icons.article;
                  if(type == 'comment') { typeLabel = 'Yorum'; typeIcon = Icons.comment; }
                  if(type == 'product') { typeLabel = 'Ürün'; typeIcon = Icons.shopping_bag; }
                  return Card(
                    color: AppColors.error.withOpacity(0.05),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(backgroundColor: Colors.white, child: Icon(typeIcon, color: AppColors.error)),
                      title: Text(data['reason'] ?? 'Sebep yok', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("Türü: $typeLabel | Şikayet Eden: ${data['reporterName']}"),
                          Text("İçerik: ${data['targetTitle'] ?? data['postTitle'] ?? 'Başlık Yok'}", maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.visibility, color: AppColors.primary), onPressed: () {
                          final targetId = data['targetId'] ?? data['postId'];
                          if (type == 'post' || type == 'comment') {
                            final postId = data['postId'] ?? targetId;
                            FirebaseFirestore.instance.collection('gonderiler').doc(postId).get().then((postDoc) {
                              if (postDoc.exists && mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => GonderiDetayEkrani.fromDoc(postDoc)));
                            });
                          } else if (type == 'product') {
                            FirebaseFirestore.instance.collection('urunler').doc(targetId).get().then((prodDoc) {
                              if (prodDoc.exists && mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => UrunDetayEkrani(productId: targetId, productData: prodDoc.data()!)));
                            });
                          }
                        }),
                        IconButton(icon: const Icon(Icons.delete_forever, color: AppColors.error), onPressed: () async {
                          final targetId = data['targetId'] ?? data['postId'];
                          final postId = data['postId'];
                          if (type == 'post') await _deleteContent('gonderiler', targetId, "Gönderi silindi.");
                          else if (type == 'comment') await _deleteComment(postId, targetId);
                          else if (type == 'product') await _deleteContent('urunler', targetId, "Ürün silindi.");
                          await doc.reference.delete();
                        }),
                        IconButton(icon: const Icon(Icons.check, color: AppColors.success), onPressed: () => _deleteContent('sikayetler', doc.id, "Şikayet çözüldü.")),
                      ]),
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

  Future<void> _deleteComment(String postId, String commentId) async {
    try {
      await FirebaseFirestore.instance.collection('gonderiler').doc(postId).collection('yorumlar').doc(commentId).delete();
      await FirebaseFirestore.instance.collection('gonderiler').doc(postId).update({'commentCount': FieldValue.increment(-1)});
      _showSnack("Yorum silindi.", AppColors.success);
    } catch (e) {
      _showSnack("Hata: $e", AppColors.error);
    }
  }

  Widget _buildStatistics() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            _buildStatCard("Toplam Kullanıcı", (data['totalUsers']).toString(), Icons.people, Colors.blue),
            const SizedBox(height: 10),
            _buildStatCard("Toplam Gönderi", "${data['totalPosts']}", Icons.article, Colors.purple),
            const SizedBox(height: 20),
            const Text("Sistem İstatistikleri", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
        );
      },
    );
  }

  Widget _buildModernSearchBar(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: controller.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () => controller.clear()) : null,
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ]),
          Icon(icon, color: color, size: 30),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }

  void _showDeleteConfirm(String docId, String collection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Emin misiniz?"),
        content: const Text("Bu veri kalıcı olarak silinecek."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteContent(collection, docId, "Silme işlemi başarılı.");
            },
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showUserManagementDialog(Map<String, dynamic> userData, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(userData['takmaAd'] ?? 'Kullanıcı'),
        children: [
          SimpleDialogOption(
            child: const Text("Profili Görüntüle"),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => KullaniciProfilDetayEkrani(userId: userId, userName: userData['takmaAd'])));
            },
          ),
          SimpleDialogOption(
            child: const Text("Kullanıcıyı Sil (Kalıcı)", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteConfirm(userId, 'users');
            },
          ),
        ],
      ),
    );
  }

  // RING MODERASYONTABı
  Widget _buildRingModerationTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Alt Tab Bar (Pending / Onaylı)
          TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(icon: Icon(Icons.schedule_rounded), text: "Beklemede"),
              Tab(icon: Icon(Icons.check_circle_rounded), text: "Onaylı"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPendingRingPhotos(),
                _buildApprovedRingPhotos(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRingPhotos() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: RingModerationService.getPendingPhotos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("Hata: ${snapshot.error}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported_rounded, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text("İncelenecek fotoğraf yok", style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        final pendingPhotos = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pendingPhotos.length,
          itemBuilder: (context, index) {
            final photo = pendingPhotos[index];
            final universityName = photo['universityName'] as String? ?? 'Bilinmiyor';
            final uploaderName = photo['uploaderName'] as String? ?? 'Anonim';
            final photoUrl = photo['photoUrl'] as String? ?? '';
            final photoId = photo['id'] as String? ?? '';
            final uploadedAt = (photo['uploadedAt'] as Timestamp?)?.toDate();

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fotoğraf
                  if (photoUrl.isNotEmpty)
                    Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => Icon(Icons.broken_image, size: 64, color: Colors.grey[300]),
                      ),
                    ),
                  // Bilgi
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "🏫 $universityName",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Yükleyen: $uploaderName",
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        if (uploadedAt != null)
                          Text(
                            "Tarih: ${DateFormat('dd MMM yyyy, HH:mm').format(uploadedAt)}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  // Butonlar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveRingPhoto(photoId, universityName, uploaderName),
                            icon: const Icon(Icons.check_circle),
                            label: const Text("Onayla"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showRejectReasonDialog(photoId),
                            icon: const Icon(Icons.cancel),
                            label: const Text("Reddet"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                            ),
                          ),
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

  Widget _buildApprovedRingPhotos() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: RingModerationService.getApprovedPhotos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("Hata: ${snapshot.error}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text("Onaylı fotoğraf yok", style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        final approvedPhotos = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: approvedPhotos.length,
          itemBuilder: (context, index) {
            final photo = approvedPhotos[index];
            final universityName = photo['university'] as String? ?? 'Bilinmiyor';
            final photoUrl = photo['imageUrl'] as String? ?? '';
            final updaterName = photo['updaterName'] as String? ?? 'Anonim';
            final approverName = photo['approvedByName'] as String? ?? 'Bilinmiyor';
            final lastUpdated = (photo['lastUpdated'] as Timestamp?)?.toDate();

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fotoğraf
                  if (photoUrl.isNotEmpty)
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => Icon(Icons.broken_image, size: 64, color: Colors.grey[300]),
                      ),
                    ),
                  // Bilgi
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "✅ $universityName",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Yükleyen: $updaterName",
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        Text(
                          "Onaylayan: $approverName",
                          style: const TextStyle(fontSize: 13, color: Colors.green),
                        ),
                        if (lastUpdated != null)
                          Text(
                            "Tarih: ${DateFormat('dd MMM yyyy, HH:mm').format(lastUpdated)}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  Future<void> _approveRingPhoto(String photoId, String universityName, String uploaderName) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final success = await RingModerationService.approvePendingPhoto(
        photoId: photoId,
        adminUserId: currentUser.uid,
        adminName: currentUser.displayName ?? 'Admin',
      );

      if (success) {
        // Uploader'a bildirim gönder
        await RingNotificationService.notifyUploaderPhotoApproved(
          uploaderUserId: '', // Bu bilgiyi pending_ring_photos'dan çekeceksin, bunu fix ettim
          uploaderName: uploaderName,
          universityName: universityName,
          approverName: currentUser.displayName ?? 'Admin',
        );

        // Üniversite kullanıcılarına bildirim gönder
        await RingNotificationService.notifyUniversityUsersAboutNewRingInfo(
          universityName: universityName,
          uploaderName: uploaderName,
        );

        _showSnack("✅ Fotoğraf onaylandı ve bildirimler gönderildi", AppColors.success);
      }
    } catch (e) {
      _showSnack("Hata: $e", AppColors.error);
    }
  }

  void _showRejectReasonDialog(String photoId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Fotoğrafı Reddet"),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Red sebebini yazınız...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _rejectRingPhoto(photoId, reasonController.text);
            },
            child: const Text("Reddet", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectRingPhoto(String photoId, String rejectionReason) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final photoDoc = await FirebaseFirestore.instance.collection('pending_ring_photos').doc(photoId).get();
      if (!photoDoc.exists) return;

      final photoData = photoDoc.data() as Map<String, dynamic>;
      final universityName = photoData['universityName'] as String;
      final uploaderUserId = photoData['uploadedBy'] as String;
      final uploaderName = photoData['uploaderName'] as String;

      final success = await RingModerationService.rejectPendingPhoto(
        photoId: photoId,
        adminUserId: currentUser.uid,
        adminName: currentUser.displayName ?? 'Admin',
        rejectionReason: rejectionReason,
      );

      if (success) {
        // Uploader'a bildirim gönder
        await RingNotificationService.notifyUploaderPhotoRejected(
          uploaderUserId: uploaderUserId,
          uploaderName: uploaderName,
          universityName: universityName,
          rejectionReason: rejectionReason,
          approverName: currentUser.displayName ?? 'Admin',
        );

        _showSnack("❌ Fotoğraf reddedildi ve bildirim gönderildi", AppColors.error);
      }
    } catch (e) {
      _showSnack("Hata: $e", AppColors.error);
    }
  }
}
