import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // YENİ EKLENDİ (Güvenlik Kontrolü İçin)
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';

// Düzeltilmiş Importlar
import '../../utils/app_colors.dart';
import '../profile/kullanici_profil_detay_ekrani.dart';
import '../forum/gonderi_detay_ekrani.dart';
import '../market/urun_detay_ekrani.dart';
import 'etkinlik_listesi_ekrani.dart'; 
// Kullanıcı listesi burada dahil edilmiyor, _buildUsersTab() içinde mantığı kullanılıyor.


// Admin UID'leri (main.dart'tan veya merkezi bir yerden alınmalı)
const List<String> kAdminUids = ["oZ2RIhV1JdYVIr0xyqCwhX9fJYq1", "VD8MeJIhhRVtbT9iiUdMEaCe3MO2"];


class AdminPanelEkrani extends StatefulWidget {
  const AdminPanelEkrani({super.key});

  @override
  State<AdminPanelEkrani> createState() => _AdminPanelEkraniState();
}

class _AdminPanelEkraniState extends State<AdminPanelEkrani> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _pendingSearchController = TextEditingController();
  final TextEditingController _allUsersSearchController = TextEditingController();
  final TextEditingController _reportsSearchController = TextEditingController();
  
  String _pendingSearchQuery = "";
  String _allUsersSearchQuery = "";
  String _reportsSearchQuery = "";

  late Stream<QuerySnapshot> _pendingStream;
  late Stream<QuerySnapshot> _requestsStream;
  late Stream<QuerySnapshot> _usersStream;
  late Stream<QuerySnapshot> _reportsStream;

  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isAdmin => kAdminUids.contains(_currentUserId);


  @override
  void initState() {
    super.initState();
    // HATA ÇÖZÜMÜ: Sekme sayısı 5 olarak ayarlandı.
    _tabController = TabController(length: 5, vsync: this); 
    
    // Dinleyiciler: query değişkenlerinin güncellenmesi
    _pendingSearchController.addListener(() {
      if(mounted) setState(() => _pendingSearchQuery = _pendingSearchController.text.toLowerCase());
    });
    
    _allUsersSearchController.addListener(() {
      if(mounted) setState(() => _allUsersSearchQuery = _allUsersSearchController.text.toLowerCase());
    });

    _reportsSearchController.addListener(() {
      if(mounted) setState(() => _reportsSearchQuery = _reportsSearchController.text.toLowerCase());
    });

    // Stream tanımlamaları
    _pendingStream = FirebaseFirestore.instance.collection('kullanicilar').where('status', isEqualTo: 'Pending').snapshots();
    _requestsStream = FirebaseFirestore.instance.collection('degisiklik_istekleri').orderBy('timestamp', descending: true).snapshots();
    _usersStream = FirebaseFirestore.instance.collection('kullanicilar').orderBy('kayit_tarihi', descending: true).limit(50).snapshots(); 
    _reportsStream = FirebaseFirestore.instance.collection('sikayetler').orderBy('timestamp', descending: true).snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pendingSearchController.dispose();
    _allUsersSearchController.dispose();
    _reportsSearchController.dispose();
    super.dispose();
  }

  void _onayla(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).update({
        'status': 'Verified', 
        'verified': true
      });
      _sendSystemNotification(userId, 'verification_approved', 'Tebrikler! Öğrenci doğrulama başvurunuz onaylandı.');
      if (mounted) _showSnack("Kullanıcı onaylandı.", AppColors.success);
    } catch (e) {
      if (mounted) _showSnack("Hata: $e", AppColors.error);
    }
  }

  void _reddet(String userId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reddetme Sebebi"),
        content: TextField(controller: reasonController, decoration: const InputDecoration(hintText: "Sebep giriniz...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final finalReason = reasonController.text.trim();
              if (finalReason.isEmpty) {
                 return _showSnack("Sebep girmelisiniz.", AppColors.warning);
              }
              
              await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).update({
                'status': 'Rejected',
                'rejectionReason': finalReason,
              });
              _sendSystemNotification(userId, 'verification_rejected', 'Başvurunuz reddedildi: $finalReason');
              if (mounted) _showSnack("Başvuru reddedildi.", AppColors.error);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text("Reddet"),
          )
        ],
      ),
    );
  }

  void _approveChangeRequest(DocumentSnapshot reqDoc) async {
    final data = reqDoc.data() as Map<String, dynamic>;
    final userId = data['userId'];
    final newUni = data['newUniversity'];
    final newDept = data['newDepartment'];

    try {
      await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).update({
        'submissionData.university': newUni,
        'submissionData.department': newDept,
      });
      await reqDoc.reference.delete();
      _sendSystemNotification(userId, 'info_update', 'Profil bilgileriniz güncellendi: $newUni - $newDept');
      if (mounted) _showSnack("Değişiklik onaylandı.", AppColors.success);
    } catch (e) {
      if (mounted) _showSnack("Hata: $e", AppColors.error);
    }
  }

  void _rejectChangeRequest(DocumentSnapshot reqDoc) async {
    try {
      await reqDoc.reference.delete(); 
      if (mounted) _showSnack("Talep reddedildi.", AppColors.warning);
    } catch (e) {
      if (mounted) _showSnack("Hata: $e", AppColors.error);
    }
  }

  void _sendSystemNotification(String userId, String type, String message) {
    FirebaseFirestore.instance.collection('bildirimler').add({
      'userId': userId,
      'senderName': 'Sistem',
      'type': type,
      'message': message,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _deletePost(String postId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('deletePost');
      await callable.call({'postId': postId});
      if (mounted) _showSnack("Gönderi silindi.", AppColors.success);
    } catch (e) {
      if (mounted) _showSnack("Hata: $e", AppColors.error);
    }
  }
  
  void _deleteComment(String postId, String commentId) async {
    try {
        await FirebaseFirestore.instance.collection('gonderiler').doc(postId).collection('yorumlar').doc(commentId).delete();
        await FirebaseFirestore.instance.collection('gonderiler').doc(postId).update({
            'commentCount': FieldValue.increment(-1)
        });
        if (mounted) _showSnack("Yorum silindi.", AppColors.success);
    } catch (e) {
        if (mounted) _showSnack("Hata: $e", AppColors.error);
    }
  }

  void _deleteProduct(String productId) async {
      try {
          await FirebaseFirestore.instance.collection('urunler').doc(productId).delete();
          if (mounted) _showSnack("Ürün silindi.", AppColors.success);
      } catch (e) {
          if (mounted) _showSnack("Hata: $e", AppColors.error);
      }
  }

  void _deleteUser(String userId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('deleteUserAccount');
      await callable.call({'userId': userId});
      if (mounted) _showSnack("Kullanıcı silindi.", AppColors.success);
    } catch (e) {
      if (mounted) _showSnack("Hata: $e", AppColors.error);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<int> _getUserCount(String status) async {
    final snapshot = await FirebaseFirestore.instance.collection('kullanicilar').where('status', isEqualTo: status).count().get();
    return snapshot.count ?? 0;
  }

  Future<int> _getPostCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('gonderiler').count().get();
    return snapshot.count ?? 0;
  }

  Future<int> _getTotalCommentCount() async {
    return 0; 
  }

  @override
  Widget build(BuildContext context) {
    // GÜVENLİK KONTROLÜ
    if (!_isAdmin) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security_update_warning, size: 60, color: AppColors.error),
                SizedBox(height: 20),
                Text(
                  "Erişim Reddedildi",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Bu sayfayı görüntülemek için yönetici yetkisine sahip olmalısınız.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.greyText),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: const Text("Yönetim Merkezi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
            backgroundColor: AppColors.primary,
            centerTitle: true,
            pinned: true,
            floating: true,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              isScrollable: true,
              // HATA ÇÖZÜMÜ: 5 Sekme
              tabs: const [
                Tab(icon: Icon(Icons.person_add), text: "Onay"),
                Tab(icon: Icon(Icons.change_circle), text: "Talepler"),
                Tab(icon: Icon(Icons.people), text: "Kullanıcılar"),
                Tab(icon: Icon(Icons.report_problem), text: "Şikayetler"),
                Tab(icon: Icon(Icons.event_note), text: "Etkinlikler"), 
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          // HATA ÇÖZÜMÜ: 5 Sekme içeriği
          children: [
            _buildPendingTab(),
            _buildRequestsTab(),
            _buildUsersTab(),
            _buildReportsTab(),
            const EtkinlikListesiEkrani(), // Etkinlikler Listesi
          ],
        ),
      ),
    );
  }

  // --- SEKMELERİN İÇERİKLERİ ---
  
  Widget _buildPendingTab() {
    return Column(
      children: [
        _buildStatsDashboard(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _pendingSearchController,
            decoration: InputDecoration(
              labelText: 'Onay Bekleyenlerde Ara',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _pendingSearchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _pendingSearchController.clear()) : null,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _pendingStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs.where((doc) {
                 final data = doc.data() as Map<String, dynamic>;
                 final name = ((data['submissionData'] as Map?)?['name'] as String? ?? '').toLowerCase();
                 return name.contains(_pendingSearchQuery);
              }).toList();
              
              if (docs.isEmpty) return _buildEmptyState("Bekleyen başvuru yok", Icons.check_circle_outline);

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final sub = data['submissionData'] as Map<String, dynamic>? ?? {};
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: AppColors.warning, child: Icon(Icons.priority_high, color: Colors.white)),
                      title: Text(sub['name'] ?? data['ad'] ?? 'İsimsiz', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${sub['university']}\n${sub['department']}"),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.check, color: AppColors.success), onPressed: () => _onayla(docs[index].id), tooltip: 'Onayla'),
                          IconButton(icon: const Icon(Icons.close, color: AppColors.error), onPressed: () => _reddet(docs[index].id), tooltip: 'Reddet'),
                        ],
                      ),
                      onTap: () => _showDetailAndRejectDialog(data, docs[index].id),
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

  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState("Bekleyen talep yok", Icons.change_circle_outlined);

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(data['userName'] ?? 'Kullanıcı', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        if(data['timestamp'] != null)
                          Text(timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'tr'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("ESKİ BİLGİ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              Text(data['oldUniversity'] ?? '-', style: const TextStyle(fontSize: 13)),
                              Text(data['oldDepartment'] ?? '-', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward, color: Colors.grey),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("YENİ BİLGİ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                              Text(data['newUniversity'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(data['newDepartment'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _rejectChangeRequest(doc),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text("Reddet"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => _approveChangeRequest(doc),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                          child: const Text("Onayla"),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        _buildContentStatsDashboard(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _allUsersSearchController,
            onChanged: (val) => setState(() => _allUsersSearchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "Kullanıcı Ara (Ad/Takma Ad)...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _allUsersSearchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _allUsersSearchController.clear()) : null,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _usersStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final allDocs = snapshot.data!.docs;
              final filteredDocs = allDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final name = (data['ad'] ?? '').toString().toLowerCase();
                final takmaAd = (data['takmaAd'] ?? '').toString().toLowerCase();
                return name.contains(_allUsersSearchQuery) || takmaAd.contains(_allUsersSearchQuery);
              }).toList();

              if (filteredDocs.isEmpty) return _buildEmptyState("Kullanıcı bulunamadı", Icons.person_off);

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index].data() as Map<String, dynamic>;
                  final uid = filteredDocs[index].id;
                  final status = data['status'] ?? 'Bilinmiyor';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: data['avatarUrl'] != null ? CachedNetworkImageProvider(data['avatarUrl']) : null,
                        child: data['avatarUrl'] == null ? const Icon(Icons.person) : null,
                        backgroundColor: AppColors.primaryLight,
                      ),
                      title: Text(data['takmaAd'] ?? 'İsimsiz', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(data['email'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(status, style: TextStyle(color: _getStatusColor(status), fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                            onPressed: () => _confirmDeleteUser(uid),
                            tooltip: 'Kullanıcıyı Sil',
                          ),
                        ],
                      ),
                      onTap: () => _showUserManagementDialog(data, uid),
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

  Widget _buildReportsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _reportsSearchController,
            onChanged: (val) => setState(() => _reportsSearchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              labelText: 'Şikayet İçeriği Ara (Başlık/Sebep)',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _reportsSearchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _reportsSearchController.clear()) : null,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _reportsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text("Hata oluştu: ${snapshot.error}", style: const TextStyle(color: AppColors.error)));
              
              final allDocs = snapshot.data!.docs;
              // Filtreleme yapılıyor
              final docs = allDocs.where((doc) {
                 final data = doc.data() as Map<String, dynamic>;
                 final title = (data['targetTitle'] ?? data['postTitle'] ?? '').toString().toLowerCase();
                 final reason = (data['reason'] ?? '').toString().toLowerCase();
                 return title.contains(_reportsSearchQuery) || reason.contains(_reportsSearchQuery);
              }).toList();


              if (docs.isEmpty) return _buildEmptyState("Şikayet yok", Icons.verified_user);

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  final String type = data['targetType'] ?? 'post';
                  final String targetTitle = data['targetTitle'] ?? data['postTitle'] ?? 'Başlık Yok';
                  final String reporter = data['reporterName'] ?? 'Bilinmiyor';
                  final String reason = data['reason'] ?? 'Sebep belirtilmedi';
                  final Timestamp? timestamp = data['timestamp'];
                  
                  String typeLabel = 'Gönderi';
                  IconData typeIcon = Icons.article;
                  
                  if(type == 'comment') { typeLabel = 'Yorum'; typeIcon = Icons.comment; }
                  if(type == 'product') { typeLabel = 'Ürün'; typeIcon = Icons.shopping_bag; }

                  return Card(
                    color: Colors.red.withOpacity(0.05),
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.white, child: Icon(typeIcon, color: AppColors.error)),
                      title: Text(reason, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("Türü: $typeLabel | Şikayet Eden: $reporter"),
                          Text("İçerik: $targetTitle", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if(timestamp != null)
                             Text(timeago.format((timestamp as Timestamp).toDate(), locale: 'tr'), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // GÖRÜNTÜLE BUTONU
                          IconButton(
                            icon: const Icon(Icons.visibility, color: AppColors.primary),
                            onPressed: () async {
                              final targetId = data['targetId'] ?? data['postId'];
                              
                              if (type == 'post' || type == 'comment') {
                                  final postId = data['postId'] ?? targetId;
                                  final postDoc = await FirebaseFirestore.instance.collection('gonderiler').doc(postId).get();
                                  if (postDoc.exists && mounted) {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => GonderiDetayEkrani.fromDoc(postDoc)));
                                  } else {
                                      _showSnack("Gönderi silinmiş.", Colors.grey);
                                  }
                              } else if (type == 'product') {
                                  final prodDoc = await FirebaseFirestore.instance.collection('urunler').doc(targetId).get();
                                  if (prodDoc.exists && mounted) {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => UrunDetayEkrani(productId: targetId, productData: prodDoc.data()!)));
                                  } else {
                                      _showSnack("Ürün bulunamadı.", Colors.grey);
                                  }
                              }
                            },
                            tooltip: 'Görüntüle',
                          ),
                          // SİL/ÇÖZÜLDÜ BUTONU
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.error),
                            onPressed: () {
                              final targetId = data['targetId'] ?? data['postId'];
                              final postId = data['postId'];

                              if (type == 'post') {
                                  _deletePost(targetId);
                              } else if (type == 'comment') {
                                  _deleteComment(postId, targetId);
                              } else if (type == 'product') {
                                  _deleteProduct(targetId);
                              }
                              // Şikayet kaydını da sil
                              doc.reference.delete();
                            },
                            tooltip: 'Şikayeti Sil (Çözüldü)',
                          ),
                        ],
                      ),
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

  // --- YARDIMCI WIDGET'LAR VE FONKSİYONLAR ---

  Widget _buildStatsDashboard() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Onaylı', Icons.check_circle, AppColors.success, _getUserCount('Verified')),
            _buildStatItem('Bekleyen', Icons.hourglass_top, AppColors.warning, _getUserCount('Pending')),
            _buildStatItem('Reddedildi', Icons.cancel, AppColors.error, _getUserCount('Rejected')),
          ],
        ),
      ),
    );
  }

  Widget _buildContentStatsDashboard() {
    return Card(
      margin: const EdgeInsets.all(8.0), 
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Toplam Gönderi', Icons.article, AppColors.info, _getPostCount()),
            _buildStatItem('Toplam Yorum', Icons.comment, AppColors.badgeNewUser, _getTotalCommentCount()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, IconData icon, Color color, Future<int> futureCount) {
    return FutureBuilder<int>(
      future: futureCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }

  void _confirmDeleteUser(String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kullanıcıyı Sil"),
        content: const Text("Bu işlem geri alınamaz. Emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          TextButton(onPressed: () { Navigator.pop(ctx); _deleteUser(uid); }, child: const Text("SİL", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showDetailAndRejectDialog(Map<String, dynamic> userData, String userId) {
    final submissionData = (userData['submissionData'] as Map<String, dynamic>?) ?? {};
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(userData['email'] ?? 'Detay'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text('Ad Soyad: ${submissionData['name'] ?? ''} ${submissionData['surname'] ?? ''}'),
              Text('Üniversite: ${submissionData['university'] ?? ''}'),
              Text('Bölüm: ${submissionData['department'] ?? ''}'),
              const Divider(),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(hintText: "Reddetme Sebebi (Zorunlu)"), // Düzeltme sebebi zorunluluğu
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onayla(userId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text("Onayla"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _reddet(userId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text("Reddet"),
          ),
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
              _confirmDeleteUser(userId);
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Verified': return AppColors.success;
      case 'Pending': return AppColors.warning;
      case 'Rejected': return AppColors.error;
      default: return AppColors.greyText;
    }
  }
}