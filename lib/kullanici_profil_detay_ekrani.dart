import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'app_colors.dart';
import 'sohbet_detay_ekrani.dart';
import 'profil_duzenleme_ekrani.dart'; 
import 'rozetler_sayfasi.dart';
import 'gonderi_detay_ekrani.dart';
import 'giris_ekrani.dart';
import 'main.dart';
import 'kullanici_listesi_ekrani.dart'; 
import 'widgets/animated_list_item.dart'; 

class KullaniciProfilDetayEkrani extends StatefulWidget {
  final String? userId; 
  final String? userName;

  const KullaniciProfilDetayEkrani({super.key, this.userId, this.userName});

  @override
  State<KullaniciProfilDetayEkrani> createState() => _KullaniciProfilDetayEkraniState();
}

class _KullaniciProfilDetayEkraniState extends State<KullaniciProfilDetayEkrani> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _currentAuthId = FirebaseAuth.instance.currentUser!.uid;
  final ScrollController _scrollController = ScrollController();

  String get _targetUserId => widget.userId ?? _currentAuthId;
  bool get _isCurrentUser => _targetUserId == _currentAuthId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isCurrentUser ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.isAnonymous) {
        try {
          await FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid).delete();
          await user.delete();
        } catch (e) {
          await FirebaseAuth.instance.signOut();
        }
      } else {
        await FirebaseAuth.instance.signOut();
      }
    }
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const GirisEkrani()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _launchSocialURL(String platform, String value) async {
    if (value.isEmpty) return;
    String urlString;
    switch (platform) {
      case 'github': urlString = 'https://github.com/$value'; break;
      case 'instagram': urlString = 'https://instagram.com/$value'; break;
      case 'x_platform': urlString = 'https://x.com/$value'; break;
      case 'linkedin':
        urlString = value.contains('linkedin.com') ? (value.startsWith('http') ? value : 'https://$value') : 'https://www.linkedin.com/in/$value';
        break;
      default: return;
    }
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link açılamadı: $urlString')));
    }
  }

  Future<void> _toggleFollow(bool isFollowing) async {
    final userToFollowRef = FirebaseFirestore.instance.collection('kullanicilar').doc(_targetUserId);
    final currentUserRef = FirebaseFirestore.instance.collection('kullanicilar').doc(_currentAuthId);
    final batch = FirebaseFirestore.instance.batch();

    if (isFollowing) {
      batch.update(currentUserRef, {'following': FieldValue.arrayRemove([_targetUserId]), 'followingCount': FieldValue.increment(-1)});
      batch.update(userToFollowRef, {'followers': FieldValue.arrayRemove([_currentAuthId]), 'followerCount': FieldValue.increment(-1)});
    } else {
      batch.update(currentUserRef, {'following': FieldValue.arrayUnion([_targetUserId]), 'followingCount': FieldValue.increment(1)});
      batch.update(userToFollowRef, {'followers': FieldValue.arrayUnion([_currentAuthId]), 'followerCount': FieldValue.increment(1)});
      
       final senderDoc = await currentUserRef.get();
       final senderName = senderDoc.data()?['takmaAd'] ?? 'Bir kullanıcı';
       FirebaseFirestore.instance.collection('bildirimler').add({
        'userId': _targetUserId,
        'senderId': _currentAuthId,
        'senderName': senderName,
        'type': 'new_follower',
        'message': '$senderName seni takip etmeye başladı.',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  void _navigateToChat(String receiverName, String? receiverAvatar) async {
    List<String> ids = [_currentAuthId, _targetUserId];
    ids.sort();
    String chatId = ids.join('_');
    Navigator.push(context, MaterialPageRoute(builder: (context) => SohbetDetayEkrani(chatId: chatId, receiverId: _targetUserId, receiverName: receiverName, receiverAvatarUrl: receiverAvatar)));
  }

  void _showUserList(String title, List<dynamic> userIds) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => KullaniciListesiEkrani(title: title, userIds: userIds)));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); 

    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('kullanicilar').doc(_targetUserId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text("Kullanıcı bulunamadı."));

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final savedPosts = List<String>.from(userData['savedPosts'] ?? []);
          final earnedBadgeIds = Set<String>.from(userData['earnedBadges'] ?? []);
          final bool isAdmin = kAdminUids.contains(_targetUserId);

          return NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 420, 
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  title: innerBoxIsScrolled ? Text(userData['takmaAd'] ?? 'Profil') : null,
                  actions: [
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        final isDarkMode = themeProvider.themeMode == ThemeMode.dark || (themeProvider.themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
                        return IconButton(icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode), onPressed: () => themeProvider.setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark));
                      },
                    ),
                    if (_isCurrentUser) IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildModernProfileHeader(context, userData, earnedBadgeIds, isAdmin),
                  ),
                ),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      overlayColor: MaterialStateProperty.all(Theme.of(context).primaryColor.withOpacity(0.1)),
                      tabs: [
                        const Tab(text: "Gönderiler", icon: Icon(Icons.grid_on_rounded)),
                        if (_isCurrentUser) const Tab(text: "Kaydedilenler", icon: Icon(Icons.bookmark_border_rounded)),
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
                _buildPostList(userId: _targetUserId),
                if (_isCurrentUser) _buildPostList(savedPostIds: savedPosts),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernProfileHeader(BuildContext context, Map<String, dynamic> userData, Set<String> earnedBadgeIds, bool isAdmin) {
    final String displayAd = userData['ad'] ?? '';
    final String takmaAd = userData['takmaAd'] ?? '';
    final String? avatarUrl = userData['avatarUrl'];
    final String biyografi = userData['biyografi'] ?? 'Henüz biyografi eklenmedi.';
    final int postCount = userData['postCount'] ?? 0;
    final List<dynamic> followers = userData['followers'] ?? [];
    final List<dynamic> following = userData['following'] ?? [];
    final Map<String, dynamic> submissionData = userData['submissionData'] as Map<String, dynamic>? ?? {};
    final String university = submissionData['university'] ?? 'Üniversite Bilgisi Yok';
    final String department = submissionData['department'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, 
          end: Alignment.bottomCenter, 
          colors: [
            AppColors.primary, 
            isDark ? Theme.of(context).scaffoldBackgroundColor : AppColors.primaryLight,
          ]
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primaryLighter,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? CachedNetworkImageProvider(avatarUrl) : null,
              child: (avatarUrl == null || avatarUrl.isEmpty) 
                  ? Text(displayAd.isNotEmpty ? displayAd[0].toUpperCase() : '?', style: const TextStyle(fontSize: 40, color: AppColors.primary))
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(takmaAd, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
              if (isAdmin) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, color: Colors.white, size: 20)),
            ],
          ),
          Text(university + (department.isNotEmpty ? ' - $department' : ''), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
          
          const SizedBox(height: 16),
          
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem("Gönderi", postCount.toString(), () {}),
                _buildVerticalDivider(),
                _buildStatItem("Takipçi", followers.length.toString(), () => _showUserList("Takipçiler", followers)),
                _buildVerticalDivider(),
                _buildStatItem("Takip", following.length.toString(), () => _showUserList("Takip Edilenler", following)),
              ],
            ),
          ),

          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if ((userData['github'] ?? '').isNotEmpty) _buildSocialIcon(context, FontAwesomeIcons.github, () => _launchSocialURL('github', userData['github'])),
              if ((userData['linkedin'] ?? '').isNotEmpty) _buildSocialIcon(context, FontAwesomeIcons.linkedin, () => _launchSocialURL('linkedin', userData['linkedin'])),
              if ((userData['instagram'] ?? '').isNotEmpty) _buildSocialIcon(context, FontAwesomeIcons.instagram, () => _launchSocialURL('instagram', userData['instagram'])),
              if ((userData['x_platform'] ?? '').isNotEmpty) _buildSocialIcon(context, FontAwesomeIcons.xTwitter, () => _launchSocialURL('x_platform', userData['x_platform'])),
            ],
          ),

          const SizedBox(height: 16),

          // AKSİYON BUTONLARI (HATA DÜZELTİLDİ)
          if (_isCurrentUser)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilDuzenlemeEkrani()));
                    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {})); 
                  },
                  icon: const Icon(Icons.edit, size: 16), 
                  label: const Text("Düzenle"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, shape: const StadiumBorder()),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => RozetlerSayfasi(earnedBadgeIds: earnedBadgeIds, userData: userData, isAdmin: isAdmin)));
                    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {})); 
                  },
                  icon: const Icon(Icons.emoji_events, size: 16), 
                  label: const Text("Rozetler"),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white), shape: const StadiumBorder()),
                ),
              ],
            )
          else
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('kullanicilar').doc(_currentAuthId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final myData = snapshot.data!.data() as Map<String, dynamic>;
                final following = List<dynamic>.from(myData['following'] ?? []);
                final isFollowing = following.contains(_targetUserId);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => _toggleFollow(isFollowing),
                      style: ElevatedButton.styleFrom(backgroundColor: isFollowing ? Colors.grey[300] : Colors.white, foregroundColor: isFollowing ? Colors.black : AppColors.primary, shape: const StadiumBorder()),
                      child: Text(isFollowing ? "Takip Ediliyor" : "Takip Et"),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => _navigateToChat(userData['takmaAd'] ?? 'Kullanıcı', avatarUrl),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white), shape: const StadiumBorder()),
                      child: const Text("Mesaj"),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() => Container(height: 20, width: 1, color: Colors.white30);

  Widget _buildSocialIcon(BuildContext context, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: onTap,
        child: FaIcon(icon, size: 20, color: Colors.white.withOpacity(0.9)),
      ),
    );
  }

  Widget _buildPostList({String? userId, List<String>? savedPostIds}) {
    Query query = FirebaseFirestore.instance.collection('gonderiler');
    if (userId != null) {
      query = query.where('userId', isEqualTo: userId).orderBy('zaman', descending: true);
    } else if (savedPostIds != null && savedPostIds.isNotEmpty) {
      if (savedPostIds.length > 10) { query = query.where(FieldPath.documentId, whereIn: savedPostIds.sublist(0, 10)); } else { query = query.where(FieldPath.documentId, whereIn: savedPostIds); }
    } else {
      return const Center(child: Text("Henüz bir gönderi yok."));
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.image_not_supported_outlined, size: 60, color: Colors.grey), const SizedBox(height: 10), Text(userId != null ? "Henüz gönderi yok." : "Kaydedilen yok.", style: const TextStyle(color: Colors.grey))]));
        }
        
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return AnimatedListItem(
              index: index,
              child: Card(
                color: Theme.of(context).cardColor, 
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundImage: (data['avatarUrl'] != null) ? NetworkImage(data['avatarUrl']) : null,
                    child: (data['avatarUrl'] == null) ? const Icon(Icons.person) : null,
                  ),
                  title: Text(
                    data['baslik'] ?? 'Başlıksız', 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)
                  ),
                  subtitle: Text(
                    data['mesaj'] ?? '', 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7))
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => GonderiDetayEkrani.fromDoc(doc)));
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Theme.of(context).scaffoldBackgroundColor, child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}