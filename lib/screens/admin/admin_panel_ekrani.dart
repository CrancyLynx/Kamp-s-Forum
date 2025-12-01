import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../utils/app_colors.dart';
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
  final TextEditingController _pendingSearchController = TextEditingController();
  final TextEditingController _allUsersSearchController = TextEditingController();
  final TextEditingController _reportsSearchController = TextEditingController();
  
  String _pendingSearchQuery = "";
  String _allUsersSearchQuery = "";
  String _reportsSearchQuery = "";

  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  bool _isLoadingAuth = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess(); // Yetki kontrolü

    // 6 Sekme: Onay, Talepler, Kullanıcılar, Şikayetler, Etkinlikler, İstatistikler
    _tabController = TabController(length: 6, vsync: this); 
    
    _pendingSearchController.addListener(() {
      if(mounted) setState(() => _pendingSearchQuery = _pendingSearchController.text.toLowerCase());
    });
    
    _allUsersSearchController.addListener(() {
      if(mounted) setState(() => _allUsersSearchQuery = _allUsersSearchController.text.toLowerCase());
    });

    _reportsSearchController.addListener(() {
      if(mounted) setState(() => _reportsSearchQuery = _reportsSearchController.text.toLowerCase());
    });
  }

  // --- Orijinal Mantık Korundu: Admin Yetki Kontrolü ---
  Future<void> _checkAdminAccess() async {
    if (_currentUserId.isEmpty) {
      if (mounted) setState(() { _isAdmin = false; _isLoadingAuth = false; });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId).get();
      if (doc.exists) {
        final role = doc.data()?['role'];
        if (mounted) {
          setState(() {
            _isAdmin = (role == 'admin');
            _isLoadingAuth = false;
          });
        }
      } else {
        if (mounted) setState(() { _isAdmin = false; _isLoadingAuth = false; });
      }
    } catch (e) {
      debugPrint("Admin yetki kontrolü hatası: $e");
      if (mounted) setState(() { _isAdmin = false; _isLoadingAuth = false; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pendingSearchController.dispose();
    _allUsersSearchController.dispose();
    _reportsSearchController.dispose();
    super.dispose();
  }

  // --- Yardımcı UI Fonksiyonu ---
  void _showSnack(String msg, Color color) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )
    );
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

  // --- Orijinal Fonksiyonlar (Aynen Korundu) ---

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: reasonController, 
          decoration: InputDecoration(
            hintText: "Sebep giriniz...",
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
          )
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(color: Colors.grey))),
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

  // --- Silme İşlemleri (Orijinal Kod Yapısı Korundu) ---

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

  // --- İstatistikler ---

  Future<int> _getUserCount(String status) async {
    final snapshot = await FirebaseFirestore.instance.collection('kullanicilar').where('status', isEqualTo: status).count().get();
    return snapshot.count ?? 0;
  }

  Future<int> _getPostCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('gonderiler').count().get();
    return snapshot.count?? 0;
  }

  Future<int> _getTotalCommentCount() async {
    // DÜZELTME: Yorum sayısını 'statistics' koleksiyonundan okuyacak şekilde güncellendi.
    // Bu, Cloud Functions ile güncellenen bir sayaç varsayar ve daha performanslıdır.
    try {
      final doc = await FirebaseFirestore.instance.collection('statistics').doc('appStats').get();
      return doc.exists ? (doc.data()?['totalComments'] ?? 0) : 0;
    } catch (e) {
      return 0;
    }
  }

  // --- İstatistik Fonksiyonları ---
  Future<Map<String, int>> _getRecentPostCounts() async {
    Map<String, int> dailyCounts = {};
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      final start = Timestamp.fromDate(DateTime(day.year, day.month, day.day));
      final end = Timestamp.fromDate(DateTime(day.year, day.month, day.day, 23, 59, 59));
      final snapshot = await FirebaseFirestore.instance.collection('gonderiler').where('zaman', isGreaterThanOrEqualTo: start).where('zaman', isLessThanOrEqualTo: end).count().get();
      dailyCounts[day.toIso8601String().substring(0, 10)] = snapshot.count ?? 0;
    }
    return dailyCounts;
  }
  // --- Arayüz (Build) ---

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAdmin) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security_update_warning, size: 80, color: AppColors.error),
                const SizedBox(height: 20),
                const Text("Erişim Reddedildi", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Bu sayfayı görüntülemek için yönetici yetkisine sahip olmalısınız.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.greyText)),
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
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryAccent,
              indicatorWeight: 4,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              isScrollable: true,
              tabs: [
                const Tab(icon: Icon(Icons.person_add), text: "Onay"),
                const Tab(icon: Icon(Icons.change_circle), text: "Talepler"),
                const Tab(icon: Icon(Icons.group), text: "Kullanıcılar"),
                const Tab(icon: Icon(Icons.report_problem), text: "Şikayetler"),
                const Tab(icon: Icon(Icons.event_note), text: "Etkinlikler"), 
                const Tab(icon: Icon(Icons.bar_chart), text: "İstatistikler"),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPendingTab(),
            _buildRequestsTab(),
            _buildUsersTab(),
            _buildReportsTab(),
            const EtkinlikListesiEkrani(), 
            _buildStatisticsTab(),
          ],
        ),
      ),
    );
  }

  // --- Sekme Tasarımları (Modernize Edilmiş) ---
  
  Widget _buildPendingTab() {
    return Column(
      children: [
        _buildStatsDashboard(),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: _buildModernSearchBar(_pendingSearchController, 'Onay Bekleyenlerde Ara'),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // DÜZELTME: Stream doğrudan build içinde oluşturuluyor.
            stream: FirebaseFirestore.instance.collection('kullanicilar').where('status', isEqualTo: 'Pending').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs.where((doc) {
                 final data = doc.data() as Map<String, dynamic>;
                 final name = ((data['submissionData'] as Map?)?['name'] as String? ?? '').toLowerCase();
                 return name.contains(_pendingSearchQuery);
              }).toList();
              
              if (docs.isEmpty) return _buildEmptyState("Bekleyen başvuru yok", Icons.check_circle_outline);

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final sub = data['submissionData'] as Map<String, dynamic>? ?? {};
                  return Card( // GÜNCELLEME: Kart tasarımı modernize edildi.
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.priority_high, color: AppColors.warning),
                      ),
                      title: Text(sub['name'] ?? data['ad'] ?? 'İsimsiz', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${sub['university']}\n${sub['department']}"),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.check_circle, color: AppColors.success, size: 30), onPressed: () => _onayla(docs[index].id), tooltip: 'Onayla'),
                          IconButton(icon: const Icon(Icons.cancel, color: AppColors.error, size: 30), onPressed: () => _reddet(docs[index].id), tooltip: 'Reddet'),
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
      // DÜZELTME: Stream doğrudan build içinde oluşturuluyor.
      stream: FirebaseFirestore.instance.collection('degisiklik_istekleri').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState("Bekleyen talep yok", Icons.change_circle_outlined);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note, color: AppColors.primary, size: 24),
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
                              const Text("ESKİ BİLGİ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(data['oldUniversity'] ?? '-', style: const TextStyle(fontSize: 14)),
                              Text(data['oldDepartment'] ?? '-', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("YENİ BİLGİ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                              const SizedBox(height: 4),
                              Text(data['newUniversity'] ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.end),
                              Text(data['newDepartment'] ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.end),
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
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
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
          padding: const EdgeInsets.all(12.0),
          child: _buildModernSearchBar(_allUsersSearchController, "Kullanıcı Ara (Ad/Takma Ad)..."),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // DÜZELTME: Stream doğrudan build içinde oluşturuluyor.
            stream: FirebaseFirestore.instance.collection('kullanicilar').orderBy('kayit_tarihi', descending: true).limit(50).snapshots(),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index].data() as Map<String, dynamic>;
                  final uid = filteredDocs[index].id;
                  final status = data['status'] ?? 'Bilinmiyor';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: data['avatarUrl'] != null ? CachedNetworkImageProvider(data['avatarUrl']) : null,
                        backgroundColor: AppColors.primaryLight,
                        child: data['avatarUrl'] == null ? const Icon(Icons.person, color: AppColors.primary) : null,
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
          padding: const EdgeInsets.all(12.0),
          child: _buildModernSearchBar(_reportsSearchController, 'Şikayet İçeriği Ara (Başlık/Sebep)'),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // DÜZELTME: Stream doğrudan build içinde oluşturuluyor.
            stream: FirebaseFirestore.instance.collection('sikayetler').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text("Hata oluştu: ${snapshot.error}", style: const TextStyle(color: AppColors.error)));
              
              final allDocs = snapshot.data!.docs;
              final docs = allDocs.where((doc) {
                 final data = doc.data() as Map<String, dynamic>;
                 final title = (data['targetTitle'] ?? data['postTitle'] ?? '').toString().toLowerCase();
                 final reason = (data['reason'] ?? '').toString().toLowerCase();
                 return title.contains(_reportsSearchQuery) || reason.contains(_reportsSearchQuery);
              }).toList();


              if (docs.isEmpty) return _buildEmptyState("Şikayet yok", Icons.verified_user);

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    color: AppColors.error.withOpacity(0.05),
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.error.withOpacity(0.1))),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(backgroundColor: Colors.white, child: Icon(typeIcon, color: AppColors.error)),
                      title: Text(reason, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 15)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("Türü: $typeLabel | Şikayet Eden: $reporter"),
                          Text("İçerik: $targetTitle", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if(timestamp != null)
                             Text(timeago.format((timestamp as Timestamp).toDate(), locale: 'tr'), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, color: AppColors.primary),
                            onPressed: () async {
                              // İçeriği Görüntüle Mantığı
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
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.error),
                            onPressed: () {
                              // Silme Mantığı
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

  // --- İstatistik Kartları (Tasarım Güncellendi) ---

  Widget _buildStatsDashboard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDashboardCard('Onaylı', Icons.check_circle, AppColors.success, _getUserCount('Verified')),
          _buildDashboardCard('Bekleyen', Icons.hourglass_top, AppColors.warning, _getUserCount('Pending')),
          _buildDashboardCard('Reddedildi', Icons.cancel, AppColors.error, _getUserCount('Rejected')),
        ],
      ),
    );
  }

  Widget _buildContentStatsDashboard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDashboardCard('Toplam Gönderi', Icons.article, AppColors.info, _getPostCount()),
          _buildDashboardCard('Toplam Yorum', Icons.comment, AppColors.badgeNewUser, _getTotalCommentCount()),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(String title, IconData icon, Color color, Future<int> futureCount) {
    return FutureBuilder<int>(
      future: futureCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 8),
                Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- YENİ: İstatistikler Sekmesi ---
  Widget _buildStatisticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartCard(
            title: "Kullanıcı Durum Dağılımı",
            child: _buildUserStatusPieChart(),
          ),
          const SizedBox(height: 24),
          _buildChartCard(
            title: "Son 7 Günlük Gönderi Aktivitesi",
            child: _buildRecentPostsLineChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(height: 250, child: child),
        ],
      ),
    );
  }

  Widget _buildUserStatusPieChart() {
    return FutureBuilder<List<int>>(
      future: Future.wait([
        _getUserCount('Verified'),
        _getUserCount('Pending'),
        _getUserCount('Rejected'),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final counts = snapshot.data!;
        final total = counts.fold(0, (prev, e) => prev + e);
        if (total == 0) return _buildEmptyState("Veri Yok", Icons.pie_chart_outline);

        return PieChart(
          PieChartData(
            sectionsSpace: 4,
            centerSpaceRadius: 40,
            sections: [
              PieChartSectionData(
                value: counts[0].toDouble(),
                title: '${counts[0]}',
                color: AppColors.success,
                radius: 80,
                titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              PieChartSectionData(
                value: counts[1].toDouble(),
                title: '${counts[1]}',
                color: AppColors.warning,
                radius: 80,
                titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              PieChartSectionData(
                value: counts[2].toDouble(),
                title: '${counts[2]}',
                color: AppColors.error,
                radius: 80,
                titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentPostsLineChart() {
    return FutureBuilder<Map<String, int>>(
      future: _getRecentPostCounts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final spots = data.entries.toList().reversed.toList().asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
        }).toList();

        return LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 2,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      final dateStr = data.keys.toList().reversed.toList()[index];
                      final date = DateTime.parse(dateStr);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('${date.day}/${date.month}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.2))),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      '${spot.y.toInt()} gönderi',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernSearchBar(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
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
    // GÜNCELLEME: Kullanıcı detaylarını gösteren diyalog eklendi.
    final submissionData = (userData['submissionData'] as Map<String, dynamic>?) ?? {};
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(userData['email'] ?? 'Detay'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              _buildDetailRow('Ad Soyad:', '${submissionData['name'] ?? ''} ${submissionData['surname'] ?? ''}'),
              _buildDetailRow('Üniversite:', '${submissionData['university'] ?? ''}'),
              _buildDetailRow('Bölüm:', '${submissionData['department'] ?? ''}'),
              const Divider(height: 24),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: "Reddetme Sebebi",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ), 
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Kapat"),
          ),
          const Spacer(),
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
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _reddet(userId); // Reddet fonksiyonu artık diyalog açmayacak, doğrudan işlem yapacak.
              } else {
                _showSnack("Reddetmek için sebep girmelisiniz.", AppColors.warning);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text("Reddet"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
          children: [TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: value)],
        ),
      ),
    );
  }

  void _showUserManagementDialog(Map<String, dynamic> userData, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(userData['takmaAd'] ?? 'Kullanıcı'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: [
          SimpleDialogOption(
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("Profili Görüntüle")),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => KullaniciProfilDetayEkrani(userId: userId, userName: userData['takmaAd'])));
            },
          ),
          SimpleDialogOption(
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("Kullanıcıyı Sil (Kalıcı)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
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