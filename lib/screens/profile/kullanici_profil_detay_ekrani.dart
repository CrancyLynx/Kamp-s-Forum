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
import '../../widgets/animated_list_item.dart'; // Liste animasyonları için

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
  bool _isFollowing = false;
  bool _isLoading = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
    // TabController'ı başlat (Kendi profili ise 2 sekme, başkası ise 1 sekme)
    bool isOwnProfile = widget.userId == null || widget.userId == _currentUserId;
    _tabController = TabController(length: isOwnProfile ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkFollowStatus() async {
    if (widget.userId == null || widget.userId == _currentUserId) return;
    
    final doc = await FirebaseFirestore.instance
        .collection('kullanicilar')
        .doc(widget.userId)
        .get();
        
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final followers = List<String>.from(data['followers'] ?? []);
      if (mounted) {
        setState(() {
          _isFollowing = followers.contains(_currentUserId);
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.userId == null) return;
    
    setState(() => _isLoading = true);
    final targetRef = FirebaseFirestore.instance.collection('kullanicilar').doc(widget.userId);
    final myRef = FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId);

    try {
      if (_isFollowing) {
        // Takipten Çık
        await targetRef.update({'followers': FieldValue.arrayRemove([_currentUserId]), 'followerCount': FieldValue.increment(-1)});
        await myRef.update({'following': FieldValue.arrayRemove([widget.userId]), 'followingCount': FieldValue.increment(-1)});
        if (mounted) setState(() => _isFollowing = false);
      } else {
        // Takip Et
        await targetRef.update({'followers': FieldValue.arrayUnion([_currentUserId]), 'followerCount': FieldValue.increment(1)});
        await myRef.update({'following': FieldValue.arrayUnion([widget.userId]), 'followingCount': FieldValue.increment(1)});
        
        // Bildirim Gönder
        await FirebaseFirestore.instance.collection('bildirimler').add({
          'userId': widget.userId,
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

  Future<void> _toggleAdminRole(String targetUserId, bool isCurrentlyAdmin) async {
     try {
       final newRole = isCurrentlyAdmin ? 'user' : 'admin';
       await FirebaseFirestore.instance.collection('kullanicilar').doc(targetUserId).update({
         'role': newRole
       });
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isCurrentlyAdmin ? "Admin yetkisi alındı." : "Admin yetkisi verildi.")));
         setState(() {}); 
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

  @override
  Widget build(BuildContext context) {
    final targetId = widget.userId ?? _currentUserId;
    final bool isOwnProfile = targetId == _currentUserId;

    if (targetId == 'deleted_user') {
       return Scaffold(
         appBar: AppBar(title: const Text("Profil Bulunamadı")),
         body: const Center(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(Icons.person_off, size: 80, color: Colors.grey),
               SizedBox(height: 16),
               Text("Bu kullanıcı hesabını silmiş.", style: TextStyle(fontSize: 18, color: Colors.grey)),
             ],
           ),
         ),
       );
    }

    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('kullanicilar').doc(targetId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.data!.exists) {
            return Scaffold(appBar: AppBar(), body: const Center(child: Text("Kullanıcı bulunamadı.")));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final badges = List<String>.from(data['earnedBadges'] ?? []);
          final savedPosts = List<String>.from(data['savedPosts'] ?? []);
          
          final String role = data['role'] ?? 'user';
          final bool isAdmin = (role == 'admin');

          // Admin kontrolü için kendi verimizi çekiyoruz
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId).get(),
            builder: (context, mySnapshot) {
               final myData = mySnapshot.data?.data() as Map<String, dynamic>?;
               final bool amIAdmin = (myData?['role'] == 'admin');

               return NestedScrollView(
                 headerSliverBuilder: (context, innerBoxIsScrolled) {
                   return [
                     SliverAppBar(
                       title: Text(widget.userName ?? data['takmaAd'] ?? "Profil"),
                       centerTitle: true,
                       pinned: true,
                       floating: true,
                       forceElevated: innerBoxIsScrolled,
                     ),
                     SliverToBoxAdapter(
                       child: Padding(
                         padding: const EdgeInsets.all(20),
                         child: Column(
                           children: [
                             // AVATAR VE İSİM
                             CircleAvatar(
                               radius: 50,
                               backgroundColor: AppColors.primary.withOpacity(0.1),
                               backgroundImage: (data['avatarUrl'] != null && data['avatarUrl'].isNotEmpty)
                                   ? CachedNetworkImageProvider(data['avatarUrl'])
                                   : null,
                               child: (data['avatarUrl'] == null || data['avatarUrl'].isEmpty)
                                   ? Text(data['takmaAd']?[0].toUpperCase() ?? '?', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary))
                                   : null,
                             ),
                             const SizedBox(height: 16),
                             Row(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 Text(
                                   data['takmaAd'] ?? 'Anonim',
                                   style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                 ),
                                 if (isAdmin) 
                                   const Padding(
                                     padding: EdgeInsets.only(left: 8.0),
                                     child: Icon(Icons.verified, color: AppColors.primary),
                                   ),
                               ],
                             ),
                             
                             // YENİ: ROZET SİMGELERİ (İsmin Altında)
                             if (badges.isNotEmpty)
                               Padding(
                                 padding: const EdgeInsets.only(top: 8.0),
                                 child: Wrap(
                                   alignment: WrapAlignment.center,
                                   spacing: 8,
                                   runSpacing: 8,
                                   children: badges.map((id) {
                                     final badge = allBadges.firstWhere((b) => b.id == id, orElse: () => allBadges[0]);
                                     return Tooltip(
                                       message: badge.name,
                                       triggerMode: TooltipTriggerMode.tap,
                                       child: Container(
                                         padding: const EdgeInsets.all(6),
                                         decoration: BoxDecoration(
                                           color: badge.color.withOpacity(0.1),
                                           shape: BoxShape.circle,
                                         ),
                                         child: FaIcon(badge.icon, size: 16, color: badge.color),
                                       ),
                                     );
                                   }).toList(),
                                 ),
                               ),

                             if (data['biyografi'] != null && data['biyografi'].isNotEmpty)
                               Padding(
                                 padding: const EdgeInsets.symmetric(vertical: 12.0),
                                 child: Text(data['biyografi'], textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                               ),
                             
                             // SOSYAL LİNKLER
                             Row(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 if (data['github'] != null && data['github'].isNotEmpty)
                                   IconButton(icon: const FaIcon(FontAwesomeIcons.github, size: 20), onPressed: () => _launchURL("https://github.com/${data['github']}")),
                                 if (data['linkedin'] != null && data['linkedin'].isNotEmpty)
                                   IconButton(icon: const FaIcon(FontAwesomeIcons.linkedin, size: 20), onPressed: () => _launchURL("https://linkedin.com/in/${data['linkedin']}")),
                                 if (data['instagram'] != null && data['instagram'].isNotEmpty)
                                   IconButton(icon: const FaIcon(FontAwesomeIcons.instagram, size: 20), onPressed: () => _launchURL("https://instagram.com/${data['instagram']}")),
                                 if (data['x_platform'] != null && data['x_platform'].isNotEmpty)
                                   IconButton(icon: const FaIcon(FontAwesomeIcons.xTwitter, size: 20), onPressed: () => _launchURL("https://x.com/${data['x_platform']}")),
                               ],
                             ),

                             const SizedBox(height: 10),
                             
                             // İSTATİSTİKLER
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                               children: [
                                 _buildStatItem("Takipçi", data['followerCount'] ?? 0),
                                 _buildStatItem("Takip", data['followingCount'] ?? 0),
                                 _buildStatItem("Gönderi", data['postCount'] ?? 0),
                               ],
                             ),

                             const SizedBox(height: 24),
                             
                             // BUTONLAR (Rozetler butonu kaldırıldı)
                             if (isOwnProfile)
                               SizedBox(
                                 width: double.infinity,
                                 child: ElevatedButton.icon(
                                   onPressed: () {
                                     Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilDuzenlemeEkrani()));
                                   },
                                   icon: const Icon(Icons.edit, size: 16),
                                   label: const Text("Profili Düzenle"),
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: AppColors.primary, 
                                     foregroundColor: Colors.white,
                                     padding: const EdgeInsets.symmetric(vertical: 12)
                                   ),
                                 ),
                               )
                             else
                               Row(
                                 children: [
                                   Expanded(
                                     child: ElevatedButton(
                                       onPressed: _isLoading ? null : _toggleFollow,
                                       style: ElevatedButton.styleFrom(
                                         backgroundColor: _isFollowing ? Colors.grey[300] : AppColors.primary,
                                         foregroundColor: _isFollowing ? Colors.black : Colors.white,
                                       ),
                                       child: Text(_isFollowing ? "Takibi Bırak" : "Takip Et"),
                                     ),
                                   ),
                                   const SizedBox(width: 12),
                                   Expanded(
                                     child: OutlinedButton(
                                       onPressed: () {
                                         final chatId = _getChatId(_currentUserId, widget.userId!);
                                         Navigator.push(context, MaterialPageRoute(builder: (context) => SohbetDetayEkrani(
                                           chatId: chatId,
                                           receiverId: widget.userId!, 
                                           receiverName: data['takmaAd'] ?? 'Kullanıcı', 
                                           receiverAvatarUrl: data['avatarUrl'])));
                                       },
                                       child: const Text("Mesaj"),
                                     ),
                                   ),
                                 ],
                               ),
                               
                             // YÖNETİCİ PANELİ KARTI
                             if (amIAdmin && !isOwnProfile)
                                Container(
                                  margin: const EdgeInsets.only(top: 20),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.withOpacity(0.2))
                                  ),
                                  child: SwitchListTile(
                                    dense: true,
                                    title: const Text("Yönetici Yetkisi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                    value: isAdmin,
                                    onChanged: (val) => _toggleAdminRole(widget.userId!, isAdmin),
                                  ),
                                ),
                           ],
                         ),
                       ),
                     ),
                     
                     // YENİ: TAB BAR (Gönderiler / Kaydedilenler)
                     SliverPersistentHeader(
                       delegate: _SliverAppBarDelegate(
                         TabBar(
                           controller: _tabController,
                           labelColor: AppColors.primary,
                           unselectedLabelColor: Colors.grey,
                           indicatorColor: AppColors.primary,
                           tabs: [
                             const Tab(text: "Gönderiler"),
                             if (isOwnProfile) const Tab(text: "Kaydedilenler"),
                           ],
                         ),
                       ),
                       pinned: true,
                     ),
                   ];
                 },
                 body: TabBarView(
                   controller: _tabController,
                   children: [
                     // 1. Gönderiler Listesi
                     _buildPostsList(targetId, isOwnProfile),
                     // 2. Kaydedilenler Listesi (Sadece kendi profilimse)
                     if (isOwnProfile) _buildSavedPostsList(savedPosts, isOwnProfile),
                   ],
                 ),
               );
            }
          );
        },
      ),
    );
  }

  // Kullanıcının Gönderilerini Getiren Liste
  Widget _buildPostsList(String userId, bool isOwnProfile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gonderiler')
          .where('userId', isEqualTo: userId)
          .orderBy('zaman', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Henüz gönderi yok.", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final postData = doc.data() as Map<String, dynamic>;
            return _buildPostItem(doc, postData, isOwnProfile);
          },
        );
      },
    );
  }

  // Kaydedilen Gönderileri Getiren Liste
  Widget _buildSavedPostsList(List<String> savedPostIds, bool isOwnProfile) {
    if (savedPostIds.isEmpty) {
      return const Center(child: Text("Henüz kaydedilen gönderi yok.", style: TextStyle(color: Colors.grey)));
    }

    // Not: 'whereIn' sorgusu en fazla 10 eleman kabul eder. 
    // Basitlik adına, burada her bir gönderiyi Future.wait ile çekiyoruz.
    // Performans için sayfalandırma yapılabilir ama profil sayfası için bu yöntem yeterlidir.
    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait(
        savedPostIds.map((id) => FirebaseFirestore.instance.collection('gonderiler').doc(id).get())
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data?.where((doc) => doc.exists).toList() ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text("Kaydedilen gönderiler silinmiş veya bulunamadı.", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final postData = doc.data() as Map<String, dynamic>;
            return _buildPostItem(doc, postData, isOwnProfile);
          },
        );
      },
    );
  }

  Widget _buildPostItem(DocumentSnapshot doc, Map<String, dynamic> data, bool isOwnProfile) {
    // Zaman hesaplama
    String formattedTime = '...';
    if (data['zaman'] is Timestamp) {
      Timestamp t = data['zaman'] as Timestamp;
      DateTime date = t.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 0) formattedTime = "${diff.inDays}g önce";
      else if (diff.inHours > 0) formattedTime = "${diff.inHours}s önce";
      else formattedTime = "${diff.inMinutes}dk önce";
    }

    // GonderiKarti widget'ını kullanıyoruz (forum_sayfasi.dart'tan)
    return AnimatedListItem(
      index: 0, // Liste animasyonu için basit index
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
        isAdmin: false, // Profilde admin badge'ine gerek yok veya eklenebilir
        onShowLoginRequired: () {},
        currentUserTakmaAd: '', // Gerekirse doldurulabilir
        currentUserRealName: '',
        isSaved: true, // Profildeki görünüm için varsayılan
        likes: (data['likes'] as List<dynamic>? ?? []),
        commentCount: (data['commentCount'] as int? ?? 0),
        authorBadges: List<String>.from(data['authorBadges'] ?? []),
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(count.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}

// SliverAppBar altında TabBar kullanabilmek için gerekli Delegate sınıfı
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, // Arkaplan rengi
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}