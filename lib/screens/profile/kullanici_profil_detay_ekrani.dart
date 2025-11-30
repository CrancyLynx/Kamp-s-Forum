import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';
import '../../models/badge_model.dart';
import '../chat/sohbet_detay_ekrani.dart';
import 'profil_duzenleme_ekrani.dart';
import '../forum/forum_sayfasi.dart'; // GonderiKarti için
import '../../widgets/animated_list_item.dart';
import 'rozetler_sayfasi.dart';
import '../admin/admin_panel_ekrani.dart';
import '../auth/giris_ekrani.dart'; // Çıkış işlemi için
import '../admin/kullanici_listesi_ekrani.dart'; // YENİ: Kullanıcı listesi ekranı eklendi
class KullaniciProfilDetayEkrani extends StatefulWidget {
  final String? userId; // Eğer null ise kendi profilim
  final String? userName;

  const KullaniciProfilDetayEkrani({
    super.key,
    required this.userId,
    this.userName,
  });

  @override
  State<KullaniciProfilDetayEkrani> createState() => _KullaniciProfilDetayEkraniState();
}

class _KullaniciProfilDetayEkraniState extends State<KullaniciProfilDetayEkrani> with TickerProviderStateMixin {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  late String _targetUserId;
  bool _isFollowing = false;
  bool _isLoading = false;
  bool _isOwnProfile = false;

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _targetUserId = widget.userId ?? _currentUserId;
    _isOwnProfile = _targetUserId == _currentUserId;
    
    // Kendi profilimizse "Kaydedilenler" sekmesi de açılır
    _tabController = TabController(length: _isOwnProfile ? 2 : 1, vsync: this);
    
    if (!_isOwnProfile) {
      _checkFollowStatus();
    }
  }

  Future<void> _checkFollowStatus() async {
    final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(_targetUserId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final followers = List<String>.from(data['followers'] ?? []);
      if (mounted) {
        setState(() => _isFollowing = followers.contains(_currentUserId));
      }
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isLoading = true);
    final targetRef = FirebaseFirestore.instance.collection('kullanicilar').doc(_targetUserId);
    final myRef = FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId);

    try {
      if (_isFollowing) {
        await targetRef.update({'followers': FieldValue.arrayRemove([_currentUserId]), 'followerCount': FieldValue.increment(-1)});
        await myRef.update({'following': FieldValue.arrayRemove([_targetUserId]), 'followingCount': FieldValue.increment(-1)});
        if (mounted) setState(() => _isFollowing = false);
      } else {
        await targetRef.update({'followers': FieldValue.arrayUnion([_currentUserId]), 'followerCount': FieldValue.increment(1)});
        await myRef.update({'following': FieldValue.arrayUnion([_targetUserId]), 'followingCount': FieldValue.increment(1)});
        
        await FirebaseFirestore.instance.collection('bildirimler').add({
          'userId': _targetUserId,
          'type': 'follow',
          'senderId': _currentUserId,
          'message': 'Seni takip etmeye başladı.',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        if (mounted) setState(() => _isFollowing = true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchURL(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link açılamadı.")));
    }
  }

  Future<void> _toggleAdminRole(bool isCurrentlyAdmin) async {
     try {
       final newRole = isCurrentlyAdmin ? 'user' : 'admin';
       await FirebaseFirestore.instance.collection('kullanicilar').doc(_targetUserId).update({
         'role': newRole
       });
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text(isCurrentlyAdmin ? "Admin yetkisi alındı." : "Admin yetkisi verildi."),
           backgroundColor: isCurrentlyAdmin ? Colors.orange : AppColors.success,
         ));
       }
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
     }
  }

  String _getChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  void _showSettingsModal(BuildContext context, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: AppColors.primary),
                  title: const Text('Admin Paneli'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelEkrani()));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Profili Düzenle'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilDuzenlemeEkrani()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Çıkış Yap', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const GirisEkrani()),
                      (route) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_targetUserId == 'deleted_user') {
       return Scaffold(
         appBar: AppBar(title: const Text("Profil Bulunamadı")),
         body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_off, size: 80, color: Colors.grey), SizedBox(height: 16), Text("Bu kullanıcı hesabını silmiş.", style: TextStyle(fontSize: 18, color: Colors.grey))])),
       );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId).get(),
      builder: (context, mySnapshot) {
        final myData = mySnapshot.data?.data() as Map<String, dynamic>?;
        final bool amIAdmin = (myData?['role'] == 'admin');

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('kullanicilar').doc(_targetUserId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Scaffold(
                appBar: AppBar(title: const Text("Giriş Yapmalısınız")),
                body: const Center(child: Text("Kullanıcı bulunamadı veya misafir girişi.")),
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            
            return NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildModernSliverAppBar(userData, amIAdmin, innerBoxIsScrolled),
                ];
              },
              body: Column(
                children: [
                  _buildStickyTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPostsList(_targetUserId), 
                        if (_isOwnProfile) 
                          _buildSavedPostsList(List<String>.from(userData['savedPosts'] ?? [])),
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

  Widget _buildModernSliverAppBar(Map<String, dynamic> data, bool amIAdmin, bool isScrolled) {
    final String coverUrl = data['coverUrl'] ?? 'https://images.unsplash.com/photo-1557683316-973673baf926?w=900&q=80';
    final String avatarUrl = data['avatarUrl'] ?? '';
    final String name = data['takmaAd'] ?? 'Anonim';
    final String realName = data['ad'] ?? '';
    final String bio = data['biyografi'] ?? '';
    
    // GÜNCELLEME: Okul bilgisi için güvenli erişim (Hem eski hem yeni yapıyı destekler)
    final Map<String, dynamic> submission = (data['submissionData'] as Map<String, dynamic>?) ?? {};
    final String university = data['universite'] ?? submission['university'] ?? '';
    final String department = data['bolum'] ?? submission['department'] ?? '';
    
    final bool isUserAdmin = (data['role'] == 'admin');
    final List<String> badges = List<String>.from(data['earnedBadges'] ?? []);

    return SliverAppBar(
      // GÜNCELLEME: Taşmayı önlemek için yükseklik artırıldı (580)
      expandedHeight: 580, 
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: isScrolled ? 2 : 0,
      title: isScrolled ? Text(name, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)) : null,
      leading: _isOwnProfile 
          ? null 
          : Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
              child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ),
      actions: [
        if (_isOwnProfile)
          Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () => _showSettingsModal(context, isUserAdmin),
            ),
          )
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // A. Kapak Fotoğrafı
            CachedNetworkImage(
              imageUrl: coverUrl,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.3),
              colorBlendMode: BlendMode.darken,
            ),
            
            // B. İçerik
            Positioned(
              top: 100, // Kapak resminin altından başla
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Theme.of(context).scaffoldBackgroundColor],
                    stops: const [0.0, 0.2], // Geçişi biraz daha yukarı aldık
                  ),
                ),
                // GÜNCELLEME: SingleChildScrollView dikey taşmayı önler
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(), // Esnemeyi önle
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const SizedBox(height: 40), // Avatar için üst boşluk
                        // Avatar
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [AppColors.primary, Colors.purpleAccent]),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                            child: avatarUrl.isEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold)) : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // İsim
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                            if (isUserAdmin) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, color: AppColors.primary, size: 20)),
                          ],
                        ),
                        if (realName.isNotEmpty)
                          Text(realName, style: TextStyle(fontSize: 14, color: Colors.grey[600])),

                        // Okul Bilgisi
                        if (university.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.school, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Flexible(child: Text("$university${department.isNotEmpty ? ' - $department' : ''}", style: TextStyle(color: Colors.grey[700], fontSize: 12), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),

                        // Rozetler & (+) İkonu
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: SingleChildScrollView( // Yatay taşmayı önle
                            scrollDirection: Axis.horizontal,
                            child: GestureDetector(
                              onTap: () {
                                 Navigator.push(context, MaterialPageRoute(builder: (context) => RozetlerSayfasi(
                                   earnedBadgeIds: Set<String>.from(badges),
                                   isAdmin: isUserAdmin,
                                   userData: data,
                                 )));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Rozetler (En fazla 5 tane göster)
                                    ...badges.take(5).map((id) {
                                      final badge = allBadges.firstWhere((b) => b.id == id, orElse: () => allBadges[0]);
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: FaIcon(badge.icon, size: 14, color: badge.color),
                                      );
                                    }).toList(),
                                    
                                    // GÜNCELLEME: Sona eklenen (+) İkonu
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.primary.withOpacity(0.6), width: 1),
                                      ),
                                      child: Icon(Icons.add, size: 10, color: AppColors.primary.withOpacity(0.8)),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Biyografi
                        if (bio.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(bio, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                          ),

                        // İstatistikler
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                            border: Border.all(color: Colors.grey.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem(
                                "Takipçi", 
                                data['followerCount'] ?? 0,
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => KullaniciListesiEkrani(
                                    title: "$name Takipçileri",
                                    userIds: List<String>.from(data['followers'] ?? []),
                                  )));
                                }
                              ),
                              Container(height: 20, width: 1, color: Colors.grey[300]),
                              _buildStatItem(
                                "Takip", 
                                data['followingCount'] ?? 0,
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => KullaniciListesiEkrani(
                                    title: "$name Takip Ettikleri",
                                    userIds: List<String>.from(data['following'] ?? []),
                                  )));
                                }
                              ),
                              Container(height: 20, width: 1, color: Colors.grey[300]),
                              _buildStatItem("Gönderi", data['postCount'] ?? 0),
                            ],
                          ),
                        ),

                        // GÜNCELLEME: Sosyal Medya İkonları (Yatay Scroll ile Hata Önleme)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (data['github']?.isNotEmpty ?? false) _buildSocialIcon(FontAwesomeIcons.github, "https://github.com/${data['github']}"),
                              if (data['linkedin']?.isNotEmpty ?? false) _buildSocialIcon(FontAwesomeIcons.linkedin, "https://linkedin.com/in/${data['linkedin']}"),
                              if (data['instagram']?.isNotEmpty ?? false) _buildSocialIcon(FontAwesomeIcons.instagram, "https://instagram.com/${data['instagram']}"),
                              if (data['x_platform']?.isNotEmpty ?? false) _buildSocialIcon(FontAwesomeIcons.xTwitter, "https://x.com/${data['x_platform']}"),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Aksiyon Butonları
                        if (_isOwnProfile)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilDuzenlemeEkrani())),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: const Text("Profili Düzenle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _toggleFollow,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isFollowing ? Colors.grey[200] : AppColors.primary,
                                    foregroundColor: _isFollowing ? Colors.black : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(_isFollowing ? "Takibi Bırak" : "Takip Et"),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    final chatId = _getChatId(_currentUserId, _targetUserId);
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => SohbetDetayEkrani(
                                      chatId: chatId,
                                      receiverId: _targetUserId, 
                                      receiverName: name, 
                                      receiverAvatarUrl: avatarUrl)));
                                  },
                                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  child: const Text("Mesaj"),
                                ),
                              ),
                            ],
                          ),
                          
                        // Admin Toggle
                        if (amIAdmin && !_isOwnProfile)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 20),
                            child: InkWell(
                              onTap: () => _toggleAdminRole(isUserAdmin),
                              child: Text(
                                isUserAdmin ? "Yönetici Yetkisini Al" : "Yönetici Yap",
                                style: TextStyle(color: isUserAdmin ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Text(count.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0), // İkonlar arası boşluk
      child: IconButton(
        icon: FaIcon(icon, size: 20, color: Colors.grey[700]),
        onPressed: () => _launchURL(url),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildStickyTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        tabs: [
          const Tab(icon: Icon(Icons.grid_on_rounded), text: "Gönderiler"),
          if (_isOwnProfile) const Tab(icon: Icon(Icons.bookmark_border_rounded), text: "Kaydedilenler"),
        ],
      ),
    );
  }

  Widget _buildPostsList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gonderiler')
          .where('userId', isEqualTo: userId)
          .orderBy('zaman', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Henüz gönderi yok.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            return _buildPostItem(doc, doc.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }

  Widget _buildSavedPostsList(List<String> savedPostIds) {
    if (savedPostIds.isEmpty) return const Center(child: Text("Henüz kaydedilen gönderi yok.", style: TextStyle(color: Colors.grey)));

    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait(savedPostIds.map((id) => FirebaseFirestore.instance.collection('gonderiler').doc(id).get())),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.where((doc) => doc.exists).toList() ?? [];
        if (docs.isEmpty) return const Center(child: Text("Kaydedilenler bulunamadı.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _buildPostItem(doc, doc.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }

  Widget _buildPostItem(DocumentSnapshot doc, Map<String, dynamic> data) {
    String formattedTime = '...';
    if (data['zaman'] is Timestamp) {
      final diff = DateTime.now().difference((data['zaman'] as Timestamp).toDate());
      formattedTime = diff.inDays > 0 ? "${diff.inDays}g" : "${diff.inHours}s";
    }

    return AnimatedListItem(
      index: 0, 
      child: GonderiKarti(
        key: ValueKey(doc.id),
        postId: doc.id,
        adSoyad: data['ad'] ?? 'Anonim',
        realUsername: data['realUsername'] ?? data['takmaAd'],
        baslik: data['baslik'] ?? 'Başlıksız',
        mesaj: data['mesaj'] ?? '',
        zaman: formattedTime,
        kategori: data['kategori'] ?? 'Genel',
        authorUserId: data['userId'] ?? '',
        isAuthorAdmin: false,
        avatarUrl: data['avatarUrl'],
        isGuest: false,
        isAdmin: false, 
        onShowLoginRequired: () {},
        currentUserTakmaAd: '', 
        currentUserRealName: '',
        isSaved: true, 
        likes: (data['likes'] as List<dynamic>? ?? []),
        commentCount: (data['commentCount'] as int? ?? 0),
        authorBadges: List<String>.from(data['authorBadges'] ?? []),
      ),
    );
  }
}