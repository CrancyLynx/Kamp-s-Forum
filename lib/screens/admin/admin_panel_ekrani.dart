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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isLoadingAuth = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    // 6 Sekme: Onay, Talepler, Kullanıcılar, Şikayetler, Etkinlikler, İstatistikler
    _tabController = TabController(length: 6, vsync: this);
    
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
      debugPrint("Admin yetki hatası: $e");
      if (mounted) setState(() { _isAdmin = false; _isLoadingAuth = false; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Yardımcı Metodlar ---
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // --- İşlemler (Onay/Red/Silme) ---
  Future<void> _updateUserStatus(String userId, String status, {String? reason}) async {
    try {
      final updateData = {
        'status': status,
        'verified': status == 'Verified',
      };
      if (reason != null) updateData['rejectionReason'] = reason;

      await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).update(updateData);
      
      if (status == 'Verified') {
        _sendSystemNotification(userId, 'verification_approved', 'Öğrenci doğrulamanız onaylandı! 🎉');
        _showSnack("Kullanıcı onaylandı.", AppColors.success);
      } else if (status == 'Rejected') {
        _sendSystemNotification(userId, 'verification_rejected', 'Başvurunuz reddedildi: $reason');
        _showSnack("Başvuru reddedildi.", AppColors.error);
      }
    } catch (e) {
      _showSnack("İşlem hatası: $e", AppColors.error);
    }
  }

  void _confirmReject(String userId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reddetme Sebebi"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: "Eksik belge, geçersiz mail vb.", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              if (reasonController.text.trim().isEmpty) return _showSnack("Sebep girilmedi!", AppColors.warning);
              _updateUserStatus(userId, 'Rejected', reason: reasonController.text.trim());
            },
            child: const Text("Reddet", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _deleteContent(String collection, String docId, String successMsg) async {
    try {
      if (collection == 'users') {
        try {
          // Cloud Function varsa
          final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('deleteUserAccount');
          await callable.call({'userId': docId});
        } catch (_) {
          // Yoksa manuel sil (Auth hariç)
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

  // --- İstatistikler ---
  Future<Map<String, dynamic>> _fetchStats() async {
    final users = await FirebaseFirestore.instance.collection('kullanicilar').get();
    final posts = await FirebaseFirestore.instance.collection('gonderiler').count().get();
    
    int verified = 0, pending = 0, rejected = 0;
    for (var doc in users.docs) {
      final s = doc.data()['status'];
      if (s == 'Verified') verified++;
      else if (s == 'Pending') pending++;
      else if (s == 'Rejected') rejected++;
    }

    return {
      'verified': verified,
      'pending': pending,
      'rejected': rejected,
      'totalPosts': posts.count ?? 0,
    };
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
              Text("Bu sayfayı görüntülemek için yönetici yetkisine sahip olmalısınız.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.greyText)),
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
            title: const Text("Yönetim Paneli", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: AppColors.primary,
            centerTitle: true,
            pinned: true,
            floating: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white), 
              onPressed: () => Navigator.pop(context)
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.primaryAccent,
              indicatorWeight: 4,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              tabs: const [
                Tab(icon: Icon(Icons.person_add), text: "Onay"),
                Tab(icon: Icon(Icons.change_circle), text: "Talepler"),
                Tab(icon: Icon(Icons.group), text: "Kullanıcılar"),
                Tab(icon: Icon(Icons.report_problem), text: "Şikayetler"),
                Tab(icon: Icon(Icons.event_note), text: "Etkinlikler"),
                Tab(icon: Icon(Icons.bar_chart), text: "İstatistik"),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPendingList(),
            _buildRequestsList(),
            _buildUserList(),
            _buildReportsList(),
            const EtkinlikListesiEkrani(), // Ayrı dosya
            _buildStatistics(),
          ],
        ),
      ),
    );
  }

  // --- 1. ONAY BEKLEYENLER ---
  Widget _buildPendingList() {
    return Column(
      children: [
        _buildStatsDashboard(),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: _buildModernSearchBar(_searchController, 'Onay Bekleyenlerde Ara'),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('kullanicilar').where('status', isEqualTo: 'Pending').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final docs = snapshot.data!.docs.where((doc) {
                 final data = doc.data() as Map<String, dynamic>;
                 final name = ((data['submissionData'] as Map?)?['name'] as String? ?? '').toLowerCase();
                 return name.contains(_searchQuery);
              }).toList();
              
              if (docs.isEmpty) return _buildEmptyState("Bekleyen başvuru yok", Icons.check_circle_outline);

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final sub = data['submissionData'] as Map<String, dynamic>? ?? {};
                  return Card(
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
                          IconButton(icon: const Icon(Icons.check_circle, color: AppColors.success, size: 30), onPressed: () => _updateUserStatus(docs[index].id, 'Verified'), tooltip: 'Onayla'),
                          IconButton(icon: const Icon(Icons.cancel, color: AppColors.error, size: 30), onPressed: () => _confirmReject(docs[index].id), tooltip: 'Reddet'),
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

  // --- 2. DEĞİŞİKLİK TALEPLERİ ---
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

  // --- 3. TÜM KULLANICILAR ---
  Widget _buildUserList() {
    return Column(
      children: [
        _buildContentStatsDashboard(),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: _buildModernSearchBar(_searchController, "Kullanıcı Ara..."),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('kullanicilar').orderBy('kayit_tarihi', descending: true).limit(50).snapshots(),
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
                  final status = data['status'] ?? 'Bilinmiyor';

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (data['avatarUrl'] != null && data['avatarUrl'] != "") ? CachedNetworkImageProvider(data['avatarUrl']) : null,
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
                            onPressed: () => _showDeleteConfirm(uid, 'users'),
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

  // --- 4. ŞİKAYETLER ---
  Widget _buildReportsList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: _buildModernSearchBar(_searchController, 'Şikayet Ara...'),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('sikayetler').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text("Hata oluştu: ${snapshot.error}", style: const TextStyle(color: AppColors.error)));
              
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, color: AppColors.primary),
                            onPressed: () {
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
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: AppColors.error),
                            onPressed: () async {
                              final targetId = data['targetId'] ?? data['postId'];
                              final postId = data['postId'];
                              if (type == 'post') await _deleteContent('gonderiler', targetId, "Gönderi silindi.");
                              else if (type == 'comment') await _deleteComment(postId, targetId);
                              else if (type == 'product') await _deleteContent('urunler', targetId, "Ürün silindi.");
                              await doc.reference.delete();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: AppColors.success),
                            onPressed: () => _deleteContent('sikayetler', doc.id, "Şikayet çözüldü."),
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

  Future<void> _deleteComment(String postId, String commentId) async {
    try {
        await FirebaseFirestore.instance.collection('gonderiler').doc(postId).collection('yorumlar').doc(commentId).delete();
        await FirebaseFirestore.instance.collection('gonderiler').doc(postId).update({
            'commentCount': FieldValue.increment(-1)
        });
        _showSnack("Yorum silindi.", AppColors.success);
    } catch (e) {
        _showSnack("Hata: $e", AppColors.error);
    }
  }

  // --- 6. İSTATİSTİKLER ---
  Widget _buildStatistics() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildStatCard("Toplam Kullanıcı", (data['verified'] + data['pending'] + data['rejected']).toString(), Icons.people, Colors.blue),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildStatCard("Onaylı", "${data['verified']}", Icons.check_circle, AppColors.success)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatCard("Bekleyen", "${data['pending']}", Icons.hourglass_top, AppColors.warning)),
                ],
              ),
              const SizedBox(height: 10),
              _buildStatCard("Toplam Gönderi", "${data['totalPosts']}", Icons.article, Colors.purple),
              const SizedBox(height: 20),
              const Text("Kullanıcı Dağılımı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(value: data['verified'].toDouble(), color: AppColors.success, radius: 50, title: "${data['verified']}"),
                      PieChartSectionData(value: data['pending'].toDouble(), color: AppColors.warning, radius: 50, title: "${data['pending']}"),
                      PieChartSectionData(value: data['rejected'].toDouble(), color: AppColors.error, radius: 50, title: "${data['rejected']}"),
                    ],
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- UI Widgetlar ---
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

  Future<int> _getUserCount(String status) async {
    final snapshot = await FirebaseFirestore.instance.collection('kullanicilar').where('status', isEqualTo: status).count().get();
    return snapshot.count ?? 0;
  }

  Widget _buildContentStatsDashboard() {
    return const Padding(padding: EdgeInsets.all(8.0)); 
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
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
                decoration: const InputDecoration(hintText: "Reddetme Sebebi"), 
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Kapat")),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _updateUserStatus(userId, 'Verified'); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text("Onayla"),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _updateUserStatus(userId, 'Rejected', reason: reasonController.text.trim());
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Verified': return AppColors.success;
      case 'Pending': return AppColors.warning;
      case 'Rejected': return AppColors.error;
      default: return AppColors.greyText;
    }
  }
}