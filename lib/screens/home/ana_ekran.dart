import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; // Hafıza kontrolü için
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart'; // Tanıtım paketi

import '../forum/forum_sayfasi.dart';
import 'kesfet_sayfasi.dart';
import '../market/pazar_sayfasi.dart'; 
import '../chat/sohbet_listesi_ekrani.dart'; 
import '../notification/bildirim_ekrani.dart'; 
import '../profile/profil_ekrani.dart'; 
import '../../utils/app_colors.dart';

class AnaEkran extends StatefulWidget {
  final bool isGuest;
  final bool isAdmin;
  final String userName;
  final String realName;

  const AnaEkran({
    super.key,
    required this.isGuest,
    required this.isAdmin,
    required this.userName,
    required this.realName,
  });

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  int _selectedIndex = 0;
  // PageController SİLİNDİ (IndexedStack kullanacağız)
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // --- TANITIM İÇİN KEY'LER (KONUM BELİRLEYİCİLER) ---
  final GlobalKey keyKesfet = GlobalKey();
  final GlobalKey keyPazar = GlobalKey();
  final GlobalKey keyForum = GlobalKey();
  final GlobalKey keyProfil = GlobalKey();
  // ----------------------------------------------------

  @override
  void initState() {
    super.initState();
    // PageController init SİLİNDİ
    
    if (!_currentUserId.isEmpty && !widget.isGuest) {
      _verifyCounters();
    }

    // Sayfa açıldıktan hemen sonra tanıtımı kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  // Tanıtımı Gösterme Mantığı
  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    // 'isTutorialShown' false ise veya null ise tanıtımı göster
    bool isShown = prefs.getBool('isTutorialShown') ?? false;

    if (!isShown) {
      // Biraz bekle ki ekran tam yüklensin
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _createTutorial();
      // Gösterildi olarak işaretle
      await prefs.setBool('isTutorialShown', true);
    }
  }

  void _createTutorial() {
    TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black, // Arka plan kararma rengi
      textSkip: "ATLA",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        debugPrint("Tanıtım bitti");
      },
      onClickTarget: (target) {
        debugPrint("Hedefe tıklandı: $target");
      },
      onSkip: () {
        debugPrint("Tanıtım geçildi");
        return true; 
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    // 1. HEDEF: PAZAR ALANI
    targets.add(
      TargetFocus(
        identify: "Pazar",
        keyTarget: keyPazar,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag, color: Colors.white, size: 50),
                  SizedBox(height: 10),
                  Text(
                    "Kampüs Pazarı",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Buradan ders notlarını satabilir veya ikinci el eşyalar bulabilirsin.",
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 2. HEDEF: FORUM ALANI
    targets.add(
      TargetFocus(
        identify: "Forum",
        keyTarget: keyForum,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.forum, color: Colors.white, size: 50),
                  SizedBox(height: 10),
                  Text(
                    "Forum & İtiraflar",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Kampüs gündemini buradan takip et. İstersen anonim itiraflarda bulun.",
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 3. HEDEF: PROFIL
    targets.add(
      TargetFocus(
        identify: "Profil",
        keyTarget: keyProfil,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.person, color: Colors.white, size: 50),
                  SizedBox(height: 10),
                  Text(
                    "Profilin",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Rozetlerini görmek, ayarlarını yapmak ve çıkış yapmak için burayı kullan.",
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
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
          debugPrint("Sayaçlar onarıldı.");
        }
      }
    } catch (e) {
      debugPrint("Sayaç kontrol hatası: $e");
    }
  }

  @override
  void dispose() {
    // PageController dispose SİLİNDİ
    super.dispose();
  }

  void _onItemTapped(int index) {
    // PageView olmadığı için animateToPage kullanmıyoruz, sadece index güncelliyoruz.
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Sayfaları burada liste olarak tanımlıyoruz
    final List<Widget> pages = [
      const KesfetSayfasi(),
      const PazarSayfasi(), 
      ForumSayfasi(
        isGuest: widget.isGuest,
        isAdmin: widget.isAdmin,
        userName: widget.userName,
        realName: widget.realName,
      ),
      const ProfilEkrani(),
    ];

    return Scaffold(
      appBar: (_selectedIndex == 0) ? _buildKesfetAppBar() : null,
      
      // PERFORMANS DÜZELTMESİ: PageView yerine IndexedStack
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined, key: keyKesfet),
              activeIcon: const Icon(Icons.explore),
              label: 'Keşfet'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined, key: keyPazar),
              activeIcon: const Icon(Icons.shopping_bag),
              label: 'Pazar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.forum_outlined, key: keyForum),
              activeIcon: const Icon(Icons.forum),
              label: 'Forum'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, key: keyProfil),
              activeIcon: const Icon(Icons.person),
              label: 'Profil'),
        ],
      ),
    );
  }

  AppBar _buildKesfetAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      title: Row(
        children: [
          const Icon(Icons.school, color: AppColors.primary, size: 24),
          const SizedBox(width: 8),
          Text(
            "Kampüs", 
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)
          ),
        ],
      ),
      actions: [
        StreamBuilder<DocumentSnapshot>(
          stream: _currentUserId.isEmpty
              ? null
              : FirebaseFirestore.instance
                  .collection('kullanicilar')
                  .doc(_currentUserId)
                  .snapshots(),
          builder: (context, snapshot) {
            int unreadMsgCount = 0;
            int unreadNotifCount = 0;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null) {
                unreadMsgCount = data['totalUnreadMessages'] ?? 0;
                unreadNotifCount = data['unreadNotifications'] ?? 0;
              }
            }

            return Row(
              children: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey),
                      onPressed: () {
                        if (widget.isGuest) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giriş yapmalısınız.")));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const SohbetListesiEkrani()));
                        }
                      },
                    ),
                    if (unreadMsgCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadMsgCount > 9 ? '9+' : unreadMsgCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: Colors.grey),
                      onPressed: () {
                         if (widget.isGuest) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giriş yapmalısınız.")));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const BildirimEkrani()));
                        }
                      },
                    ),
                    if (unreadNotifCount > 0)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}