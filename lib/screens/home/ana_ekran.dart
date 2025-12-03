import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart'; 

import '../forum/forum_sayfasi.dart';
import 'kesfet_sayfasi.dart';
import '../market/pazar_sayfasi.dart'; 
import '../chat/sohbet_listesi_ekrani.dart'; 
import '../notification/bildirim_ekrani.dart'; 
import '../profile/profil_ekrani.dart'; 
import '../../utils/maskot_helper.dart';
import '../../utils/app_colors.dart';

class AnaEkran extends StatefulWidget {
  final bool isGuest;
  final VoidCallback? showLoginPrompt;
  final bool isAdmin;
  final String userName;
  final String realName;

  const AnaEkran({
    super.key,
    this.isGuest = false,
    this.showLoginPrompt,
    this.isAdmin = false,
    this.userName = 'Misafir',
    this.realName = 'Misafir',
  });

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  int _selectedIndex = 0;
  late final PageController _pageController;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final GlobalKey keyKesfet = GlobalKey();
  final GlobalKey keyPazar = GlobalKey();
  final GlobalKey keyForum = GlobalKey();
  final GlobalKey keyProfil = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    
    if (!_currentUserId.isEmpty && !widget.isGuest) {
      _verifyCounters();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // YENİ SİSTEM: MaskotHelper ile tanıtımı göster
      MaskotHelper.checkAndShow(
        context,
        featureKey: 'ana_ekran_tutorial_gosterildi',
        targets: [
          // 1. PAZAR
          TargetFocus(
            identify: "Pazar",
            keyTarget: keyPazar,
            alignSkip: Alignment.topRight,
            shape: ShapeLightFocus.RRect,
            radius: 15,
            contents: [
              TargetContent(
                align: ContentAlign.top,
                builder: (context, controller) => MaskotHelper.buildTutorialContent(context,
                    title: 'Kampüs Pazarı 🛍️',
                    description: 'Ders notlarını sat, ikinci el eşya bul. Burası senin ticaret merkezin!',
                    mascotAssetPath: 'assets/images/düsünceli_bay.png'),
              ),
            ],
          ),
          // 2. FORUM
          TargetFocus(
            identify: "Forum",
            keyTarget: keyForum,
            alignSkip: Alignment.topRight,
            contents: [
              TargetContent(
                align: ContentAlign.top,
                builder: (context, controller) => MaskotHelper.buildTutorialContent(context,
                    title: 'Forum & İtiraflar 📢',
                    description: 'Kampüste neler oluyor? Tartışmalara katıl, istersen anonim içini dök.',
                    mascotAssetPath: 'assets/images/duyuru_bay.png'),
              ),
            ],
          ),
        ],
      );
    });
  }
  
  Future<void> _verifyCounters() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && (data['totalUnreadMessages'] == null || data['unreadNotifications'] == null)) {
          await FirebaseFunctions.instanceFor(region: 'europe-west1')
              .httpsCallable('recalculateUserCounters')
              .call();
        }
      }
    } catch (e) {
      debugPrint("Sayaç kontrol hatası: $e");
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    // Misafir kullanıcı profil sekmesine tıklarsa işlem yapma
    if (widget.isGuest && index == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil alanını görmek için giriş yapmalısınız.")),
      );
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleGuestAction() {
    if (widget.isGuest) {
      widget.showLoginPrompt?.call();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bu özelliği kullanmak için giriş yapmalısınız.")));
    }
  }

  @override
  Widget build(BuildContext context) {

    final List<Widget> pages = [
      const KesfetSayfasi(),
      const PazarSayfasi(),
      ForumSayfasi(
        isGuest: widget.isGuest,
        isAdmin: widget.isAdmin,
        userName: widget.userName,
        realName: widget.realName,
      ),
      // Misafir değilse profil sayfasını ekle
      if (!widget.isGuest) const ProfilEkrani(),
    ];

    final List<BottomNavigationBarItem> navBarItems = [
      BottomNavigationBarItem(
        icon: Icon(Icons.explore_outlined, key: keyKesfet),
        activeIcon: const Icon(Icons.explore),
        label: 'Keşfet',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.shopping_bag_outlined, key: keyPazar),
        activeIcon: const Icon(Icons.shopping_bag),
        label: 'Pazar',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.forum_outlined, key: keyForum),
        activeIcon: const Icon(Icons.forum),
        label: 'Forum',
      ),
      // Misafir değilse profil butonunu ekle
      if (!widget.isGuest)
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline, key: keyProfil),
          activeIcon: const Icon(Icons.person),
          label: 'Profil',
        ),
    ];


    return Scaffold(
      appBar: (_selectedIndex == 0) ? _buildKesfetAppBar(context) : null,
      floatingActionButton: widget.isGuest ? FloatingActionButton.extended(
              onPressed: widget.showLoginPrompt,
              label: const Text("Giriş Yap"),
              icon: const Icon(Icons.login),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
      
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        physics: const NeverScrollableScrollPhysics(),
        children: pages, // Değiştirilen kısım
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: navBarItems, // Değiştirilen kısım
      ),
    );
  }

  AppBar _buildKesfetAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget logo;

    if (isDark) {
      logo = ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0, 0, 0, 0, 255, // Red
                      0, 0, 0, 0, 255, // Green
                      0, 0, 0, 0, 255, // Blue
                      0, 0, 0, 1, 0,   // Alpha
                    ]),
        child: Image.asset('assets/images/app_logo3.png', height: 40),
                  );
    } else {
      logo = Image.asset('assets/images/app_icon2.png', height: 60);
    }
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      title: Row(
        children: [
          logo,
          const SizedBox(width: 8),
          Text(
            "Kampüs Forum", 
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)
          ),
        ],
      ),
      actions: [
        if (widget.isGuest) ...[
          _AppBarIcon(icon: Icons.chat_bubble_outline_rounded, onPressed: _handleGuestAction),
          _AppBarIcon(icon: Icons.notifications_none_rounded, onPressed: _handleGuestAction),
        ] else
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId).snapshots(),
            builder: (context, snapshot) {
              int unreadMsgCount = 0;
              int unreadNotifCount = 0;

              if (snapshot.hasData && snapshot.data?.exists == true) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                unreadMsgCount = data?['totalUnreadMessages'] ?? 0;
                unreadNotifCount = data?['unreadNotifications'] ?? 0;
              }

              return Row(
                children: [
                  _AppBarIcon(
                    icon: Icons.chat_bubble_outline_rounded,
                    badgeCount: unreadMsgCount,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SohbetListesiEkrani())),
                  ),
                  _AppBarIcon(
                    icon: Icons.notifications_none_rounded,
                    hasNotificationDot: unreadNotifCount > 0,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BildirimEkrani())),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;
  final bool hasNotificationDot;

  const _AppBarIcon({
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
    this.hasNotificationDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.grey),
          onPressed: onPressed,
        ),
        if (badgeCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badgeCount > 9 ? '9+' : badgeCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (hasNotificationDot)
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}