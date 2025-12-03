import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kampus_yardim_app/widgets/forum/gonderi_karti.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../utils/app_colors.dart';
import '../../models/badge_model.dart';
import '../../utils/maskot_helper.dart';
import '../chat/sohbet_detay_ekrani.dart';
import 'profil_duzenleme_ekrani.dart';
import 'engellenen_kullanicilar_ekrani.dart';

import '../../widgets/animated_list_item.dart';
import 'rozetler_sayfasi.dart';
import '../admin/admin_panel_ekrani.dart';
import '../auth/giris_ekrani.dart'; 
import '../admin/kullanici_listesi_ekrani.dart';

import '../../services/auth_service.dart';
import '../../main.dart'; // ThemeProvider için

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

class _KullaniciProfilDetayEkraniState extends State<KullaniciProfilDetayEkrani> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  late String _targetUserId;
  bool _isOwnProfile = false;
  Map<String, dynamic>? _myUserData;
  Future<DocumentSnapshot>? _myUserDataFuture;

  // --- MASKOT İÇİN KEY'LER ---
  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _actionButtonsKey = GlobalKey();
  final GlobalKey _badgesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _targetUserId = widget.userId ?? _currentUserId;
    _isOwnProfile = _targetUserId == _currentUserId;
    
    if (_currentUserId.isNotEmpty) {
      _myUserDataFuture = FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId).get();
    }

    // --- MASKOT TANITIMI ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MaskotHelper.checkAndShow(
        context,
        featureKey: 'profil_detay_tutorial_gosterildi',
        targets: [
          TargetFocus(
            identify: "profil-badges",
            keyTarget: _badgesKey, 
            alignSkip: Alignment.bottomCenter,
            shape: ShapeLightFocus.RRect,
            radius: 12,
            contents: [
              TargetContent(
                align: ContentAlign.bottom,
                builder: (context, controller) => MaskotHelper.buildTutorialContent(
                  context,
                  title: 'Rozetlerin',
                  description: 'Kazandığın başarı rozetleri burada listelenir. Yukarıdaki madalya ikonuna tıklayarak tüm hedefleri görebilirsin!',
                  mascotAssetPath: 'assets/images/mutlu_bay.png',
                ),
              ),
            ],
          ),
          TargetFocus(
            identify: "profil-stats",
            keyTarget: _statsKey,
            alignSkip: Alignment.bottomLeft,
            shape: ShapeLightFocus.RRect,
            radius: 16,
            contents: [
              TargetContent(
                align: ContentAlign.bottom,
                builder: (context, controller) => MaskotHelper.buildTutorialContent(
                  context,
                  title: 'İstatistikler',
                  description: 'Takipçi ve gönderi sayılarını buradan inceleyebilirsin.',
                  mascotAssetPath: 'assets/images/düsünceli_bay.png',
                ),
              ),
            ],
          ),
          TargetFocus(
            identify: "profil-actions",
            keyTarget: _actionButtonsKey,
            alignSkip: Alignment.topRight,
            shape: ShapeLightFocus.RRect,
            radius: 12,
            contents: [
              TargetContent(
                align: ContentAlign.top,
                builder: (context, controller) => MaskotHelper.buildTutorialContent(
                  context,
                  title: _isOwnProfile ? 'Profili Düzenle' : 'İletişime Geç',
                  description: _isOwnProfile 
                      ? 'Profil bilgilerini ve ayarlarını buradan güncelleyebilirsin.' 
                      : 'Bu kullanıcıyı takip edebilir veya mesaj atabilirsin.',
                  mascotAssetPath: 'assets/images/dedektif_bay.png',
                ),
              ),
            ],
          ),
        ],
      );
    });
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

  @override
  Widget build(BuildContext context) {
    if (_targetUserId == 'deleted_user') {
       return Scaffold(
         appBar: AppBar(title: const Text("Profil Bulunamadı")),
         body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_off, size: 80, color: Colors.grey), SizedBox(height: 16), Text("Bu kullanıcı hesabını silmiş.", style: TextStyle(fontSize: 18, color: Colors.grey))])),
       );
    }

    return DefaultTabController(
      length: _isOwnProfile ? 2 : 1,
      child: FutureBuilder<DocumentSnapshot?>(
        future: _myUserDataFuture,
        builder: (context, mySnapshot) {
          _myUserData = mySnapshot.data?.data() as Map<String, dynamic>?;
          final myData = _myUserData;
          final bool amIAdmin = (myData?['role'] == 'admin');

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('kullanicilar').doc(_targetUserId).snapshots(),
            builder: (context, snapshot) {
              // ✅ Loading state
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Profil yükleniyor..."),
                      ],
                    ),
                  ),
                );
              }

              // ✅ Error state
              if (snapshot.hasError) {
                return Scaffold(
                  appBar: AppBar(title: const Text("Hata")),
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 80, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text("Profil yüklenemedi.", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(snapshot.error.toString(), style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Geri Dön"),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // ✅ No data state
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Scaffold(
                  appBar: AppBar(title: const Text("Profil Bulunamadı")),
                  body: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("Bu kullanıcı bilgileri bulunamadı.", style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                );
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              if (userData == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text("Hata")),
                  body: const Center(child: Text("Kullanıcı verisi işlenemiyor.")),
                );
              }

              final List<String> earnedBadges = List<String>.from(userData['earnedBadges'] ?? []);
              final bool isUserAdmin = (userData['role'] == 'admin');

              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverAppBar(
                        pinned: true,
                        floating: true,
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        elevation: innerBoxIsScrolled ? 2 : 0,
                        leading: !_isOwnProfile ? IconButton(
                          icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyLarge?.color),
                          onPressed: () => Navigator.pop(context),
                        ) : null,
                        actions: [
                          // YENİ: ROZETLER İKONU
                          IconButton(
                            icon: const Icon(Icons.military_tech, color: AppColors.primaryAccent, size: 28),
                            tooltip: 'Rozet Koleksiyonu',
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => RozetlerSayfasi(
                                earnedBadgeIds: Set<String>.from(earnedBadges),
                                isAdmin: isUserAdmin,
                                userData: userData,
                              )));
                            },
                          ),
                          
                          if (_isOwnProfile)
                            IconButton(
                              icon: const Icon(Icons.settings),
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                              onPressed: () => _showSettingsModal(context, userData['role'] == 'admin'),
                            ),
                          
                          // DÜZELTİLMİŞ TEMA BUTONU
                          Consumer<ThemeProvider>(
                            builder: (context, themeProvider, child) {
                              final isSystemDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
                              final isDark = themeProvider.themeMode == ThemeMode.dark || 
                                            (themeProvider.themeMode == ThemeMode.system && isSystemDark);
                              
                              return IconButton(
                                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                onPressed: () {
                                  themeProvider.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      
                      SliverToBoxAdapter(
                        child: _buildProfileHeader(userData, amIAdmin),
                      ),

                      SliverPersistentHeader(
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            labelColor: AppColors.primary,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: AppColors.primary,
                            indicatorWeight: 3,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            tabs: [
                              const Tab(text: "Gönderiler"),
                              if (_isOwnProfile) const Tab(text: "Kaydedilenler"),
                            ],
                          ),
                        ),
                        pinned: true,
                      ),
                    ];
                  },
                  body: TabBarView(
                    children: [
                      _buildPostsList(_targetUserId), 
                      if (_isOwnProfile) 
                        _buildSavedPostsList(List<String>.from(userData['savedPosts'] ?? [])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> data, bool amIAdmin) {
    final String avatarUrl = data['avatarUrl'] ?? '';
    final String name = data['takmaAd'] ?? 'Anonim';
    final String realName = data['ad'] ?? '';
    final String bio = data['biyografi'] ?? '';
    final Map<String, dynamic> submission = (data['submissionData'] as Map<String, dynamic>?) ?? {};
    final String university = data['universite'] ?? submission['university'] ?? '';
    final String department = data['bolum'] ?? submission['department'] ?? '';
    final bool isUserAdmin = (data['role'] == 'admin');
    final List<String> badges = List<String>.from(data['earnedBadges'] ?? []);
    final List<String> followers = List<String>.from(data['followers'] ?? []);
    final bool isFollowing = followers.contains(_currentUserId);

    final String? github = data['github'];
    final String? linkedin = data['linkedin'];
    final String? instagram = data['instagram'];
    final String? xPlatform = data['x_platform'];
    final bool hasSocial = (github?.isNotEmpty ?? false) || (linkedin?.isNotEmpty ?? false) || (instagram?.isNotEmpty ?? false) || (xPlatform?.isNotEmpty ?? false);

    return Column(
      children: [
        const SizedBox(height: 10),
        
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.white,
            child: avatarUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      memCacheWidth: 240,
                      memCacheHeight: 240,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                    ),
                  )
                : (name.isNotEmpty
                    ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primary))
                    : null),
          ),
        ),
        
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name, 
              style: TextStyle(
                fontSize: 26, 
                fontWeight: FontWeight.w900, 
                letterSpacing: 0.5,
                color: Theme.of(context).textTheme.bodyLarge?.color
              )
            ),
            if (isUserAdmin) 
              const Padding(
                padding: EdgeInsets.only(left: 6), 
                child: Icon(Icons.verified, color: AppColors.primary, size: 24)
              ),
          ],
        ),
        if (realName.isNotEmpty) 
          Text(realName, style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),

        const SizedBox(height: 12),

        if (university.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FontAwesomeIcons.graduationCap, color: AppColors.primary, size: 14),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "$university ${department.isNotEmpty ? '| $department' : ''}",
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        if (badges.isNotEmpty)
          SizedBox(
            key: _badgesKey,
            height: 60, 
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20), 
              itemCount: badges.length,
              itemBuilder: (context, index) {
                final badgeId = badges[index];
                final badge = allBadges.firstWhere((b) => b.id == badgeId, orElse: () => allBadges[0]);
                
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: badge.name,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: badge.color.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: badge.color.withOpacity(0.3)),
                      ),
                      child: FaIcon(badge.icon, size: 20, color: badge.color),
                    ),
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 16),

        if (bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              bio, 
              textAlign: TextAlign.center, 
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8), fontSize: 14, height: 1.4)
            ),
          ),

        const SizedBox(height: 20),

        Container(
          key: _statsKey,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem("Takipçi", data['followerCount'] ?? 0,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => KullaniciListesiEkrani(title: "$name Takipçileri", userIds: List<String>.from(data['followers'] ?? []))))
              ),
              Container(height: 30, width: 1, color: Colors.grey.withOpacity(0.3)),
              _buildStatItem("Takip", data['followingCount'] ?? 0,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => KullaniciListesiEkrani(title: "$name Takip Ettikleri", userIds: List<String>.from(data['following'] ?? []))))
              ),
              Container(height: 30, width: 1, color: Colors.grey.withOpacity(0.3)),
              _buildStatItem("Gönderi", data['postCount'] ?? 0),
            ],
          ),
        ),

        const SizedBox(height: 20),

        if (hasSocial)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (github?.isNotEmpty ?? false) _buildSocialIcon(FontAwesomeIcons.github, "https://github.com/$github"),
                if (linkedin?.isNotEmpty ?? false) _buildSocialIcon(FontAwesomeIcons.linkedin, "https://linkedin.com/in/$linkedin"),
                if (instagram?.isNotEmpty ?? false) _buildSocialIcon(FontAwesomeIcons.instagram, "https://instagram.com/$instagram"),
                if (xPlatform?.isNotEmpty ?? false) _buildSocialIcon(FontAwesomeIcons.xTwitter, "https://x.com/$xPlatform"),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _isOwnProfile
            ? SizedBox(
                key: _actionButtonsKey,
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilDuzenlemeEkrani())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: const Text("Profili Düzenle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            : Row(
                key: _actionButtonsKey,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _toggleFollow(isFollowing),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? Colors.grey[200] : AppColors.primary,
                          foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: isFollowing ? 0 : 4,
                        ),
                        child: Text(isFollowing ? "Takibi Bırak" : "Takip Et", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          final chatId = _getChatId(_currentUserId, _targetUserId);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => SohbetDetayEkrani(
                            chatId: chatId,
                            receiverId: _targetUserId, 
                            receiverName: name, 
                            receiverAvatarUrl: avatarUrl)));
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 1.5),
                        ),
                        child: const Text("Mesaj Gönder", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
        ),
        
        if (amIAdmin && !_isOwnProfile)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: TextButton(
              onPressed: () => _toggleAdminRole(isUserAdmin),
              child: Text(
                isUserAdmin ? "Yönetici Yetkisini Al" : "Yönetici Yap",
                style: TextStyle(color: isUserAdmin ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
          ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatItem(String label, int count, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text(
              count.toString(), 
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w900, 
                color: Theme.of(context).textTheme.bodyLarge?.color
              )
            ),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(
                color: Colors.grey[600], 
                fontSize: 13, 
                fontWeight: FontWeight.w500
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () => _launchURL(url),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
          ),
          child: FaIcon(icon, size: 20, color: Theme.of(context).iconTheme.color),
        ),
      ),
    );
  }

  Widget _buildPostsList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gonderiler')
          .where('userId', isEqualTo: userId)
          .orderBy('zaman', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                const SizedBox(height: 10),
                Text(
                  "Gönderiler yüklenemedi.",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () {
                    // Sayfayı yenile
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => KullaniciProfilDetayEkrani(
                          userId: _targetUserId,
                        ),
                      ),
                    );
                  },
                  child: const Text("Yeniden Dene"),
                ),
              ],
            ),
          );
        }

        // No data state
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(
                  "Henüz gönderi yok.",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Success state
        return ListView.builder(
          padding: const EdgeInsets.all(12),
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
    if (savedPostIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              "Kaydedilen gönderi yok.",
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final idsToShow = savedPostIds.reversed.take(10).toList();

    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait(idsToShow.map((id) => FirebaseFirestore.instance.collection('gonderiler').doc(id).get())),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                const SizedBox(height: 10),
                Text(
                  "Kaydedilenler yüklenemedi.",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () {
                    // Sayfayı yenile
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => KullaniciProfilDetayEkrani(
                          userId: _targetUserId,
                        ),
                      ),
                    );
                  },
                  child: const Text("Yeniden Dene"),
                ),
              ],
            ),
          );
        }

        // Docs filtering
        final docs = snapshot.data?.where((doc) => doc.exists).toList() ?? [];
        
        // No data state
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(
                  "Kaydedilenler bulunamadı.",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Success state
        return ListView.builder(
          padding: const EdgeInsets.all(12),
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
    final bool isSaved = (_myUserData?['savedPosts'] as List<dynamic>? ?? []).contains(doc.id);
    final String kategori = data['kategori'] ?? 'Genel';

    String formattedTime = '...';
    if (data['zaman'] is Timestamp) {
      formattedTime = timeago.format((data['zaman'] as Timestamp).toDate(), locale: 'tr');
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
        kategori: kategori,
        authorUserId: data['userId'] ?? '',
        isAuthorAdmin: false,
        avatarUrl: data['avatarUrl'] ?? '',
        isGuest: false,
        isAdmin: false, 
        onShowLoginRequired: () {},
        currentUserTakmaAd: '', 
        currentUserRealName: '',
        isSaved: isSaved,
        likes: (data['likes'] as List<dynamic>? ?? []),
        commentCount: (data['commentCount'] as int? ?? 0),
        authorBadges: List<String>.from(data['authorBadges'] ?? []),
      ),
    );
  }

  Future<void> _toggleFollow(bool isFollowing) async {
    final targetRef = FirebaseFirestore.instance.collection('kullanicilar').doc(_targetUserId);
    final myRef = FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId);

    try {
      if (isFollowing) {
        await targetRef.update({
          'followers': FieldValue.arrayRemove([_currentUserId]),
          'followerCount': FieldValue.increment(-1),
        });
        await myRef.update({
          'following': FieldValue.arrayRemove([_targetUserId]),
          'followingCount': FieldValue.increment(-1),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Takip bırakıldı"), duration: Duration(seconds: 2)),
          );
        }
      } else {
        await targetRef.update({
          'followers': FieldValue.arrayUnion([_currentUserId]),
          'followerCount': FieldValue.increment(1),
        });
        await myRef.update({
          'following': FieldValue.arrayUnion([_targetUserId]),
          'followingCount': FieldValue.increment(1),
        });

        // Bildirim gönder
        try {
          final myDoc = await myRef.get();
          final myData = myDoc.data();
          final myName = (myData?['takmaAd'] as String?) ?? 'Bir kullanıcı';

          await FirebaseFirestore.instance.collection('bildirimler').add({
            'userId': _targetUserId,
            'type': 'new_follower',
            'senderId': _currentUserId,
            'senderName': myName,
            'message': 'seni takip etmeye başladı.',
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } catch (notifError) {
          if (kDebugMode) print('Bildirim gönderilemedi: $notifError');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Takip başarılı"), duration: Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("İşlem başarısız: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      if (kDebugMode) print('Takip toggle hatası: $e');
    }
  }

  Future<void> _toggleAdminRole(bool isCurrentlyAdmin) async {
     try {
       final newRole = isCurrentlyAdmin ? 'user' : 'admin';
       await FirebaseFirestore.instance.collection('kullanicilar').doc(_targetUserId).update({
         'role': newRole
       });
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
         content: Text(isCurrentlyAdmin ? "Admin yetkisi alındı." : "Admin yetkisi verildi."),
         backgroundColor: isCurrentlyAdmin ? Colors.orange : AppColors.success,
       ));
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yetki değiştirilemedi. İzniniz olmayabilir.")));
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
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Engellenen Kullanıcılar'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EngellenenKullanicilarEkrani()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Çıkış Yap', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(context);
                  await AuthService().signOut();
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
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}