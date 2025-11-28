import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'forum_sayfasi.dart';
import 'kesfet_sayfasi.dart';
import 'pazar_sayfasi.dart'; // YENİ: Pazar sayfası import edildi
import 'sohbet_listesi_ekrani.dart'; // Mesajlara gitmek için
import 'bildirim_ekrani.dart'; // Bildirimlere gitmek için
import 'app_colors.dart';

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
  late final PageController _pageController;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SADECE KEŞFET SAYFASINDA ÖZEL APP BAR GÖSTERELİM
      // Diğer sayfalarda kendi AppBar'ları var.
      appBar: (_selectedIndex == 0) ? _buildKesfetAppBar() : null,
      
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        physics: const NeverScrollableScrollPhysics(), // Sayfalar arası kaydırmayı engelle
        children: [
          const KesfetSayfasi(),
          const PazarSayfasi(), // HATA DÜZELTME: Pazar sayfası 2. sıraya (index 1) alındı.
          ForumSayfasi(
            isGuest: widget.isGuest,
            isAdmin: widget.isAdmin,
            userName: widget.userName,
            realName: widget.realName,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // 3'ten fazla item için gerekli
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Keşfet'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              activeIcon: Icon(Icons.shopping_bag),
              label: 'Pazar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.forum_outlined),
              activeIcon: Icon(Icons.forum),
              label: 'Forum'),
        ],
      ),
    );
  }

  // --- ÖZEL APP BAR (Mesaj Sayacı İçeren) ---
  AppBar _buildKesfetAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      title: Row(
        children: [
          // Küçük bir logo veya başlık
          Icon(Icons.school, color: AppColors.primary, size: 24),
          SizedBox(width: 8),
          Text(
            "Kampüs", 
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)
          ),
        ],
      ),
      actions: [
        // 1. MESAJ İKONU (SAYAÇLI)
        StreamBuilder<QuerySnapshot>(
          // HATA DÜZELTME: Kullanıcı ID'si boşsa (misafir vb.) sorguyu çalıştırma.
          stream: _currentUserId.isEmpty
              ? null
              : FirebaseFirestore.instance
                  .collection('sohbetler')
                  .where('participants', arrayContains: _currentUserId)
                  .snapshots(),
          builder: (context, snapshot) {
            int unreadCount = 0;
            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final countMap = data['unreadCount'] as Map<String, dynamic>?;
                if (countMap != null) {
                  unreadCount += (countMap[_currentUserId] as int? ?? 0);
                }
              }
            }

            return Stack(
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
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // 2. BİLDİRİM İKONU (SAYAÇLI)
        StreamBuilder<QuerySnapshot>(
          // HATA DÜZELTME: Kullanıcı ID'si boşsa (misafir vb.) sorguyu çalıştırma.
          stream: _currentUserId.isEmpty
              ? null
              : FirebaseFirestore.instance
                  .collection('bildirimler')
                  .where('userId', isEqualTo: _currentUserId)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
          builder: (context, snapshot) {
            int notifCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
            
            return Stack(
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
                if (notifCount > 0)
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
            );
          },
        ),
      ],
    );
  }
}