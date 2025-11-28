import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
// Düzeltilmiş Importlar
import '../../utils/app_colors.dart';
import '../profile/kullanici_profil_detay_ekrani.dart';


import '../forum/gonderi_detay_ekrani.dart';
import '../map/kampus_haritasi_sayfasi.dart';
import '../../widgets/animated_list_item.dart';

class AramaSayfasi extends StatefulWidget {
  const AramaSayfasi({super.key});

  @override
  State<AramaSayfasi> createState() => _AramaSayfasiState();
}

class _AramaSayfasiState extends State<AramaSayfasi> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _query = "";
  Timer? _debounce;

  // HARİTA VERİLERİNİN AYNISI (Arama için yerel liste)
  final List<Map<String, dynamic>> _allLocations = [
    {'title': 'Merkez Yemekhane', 'type': 'yemek', 'subtitle': 'Kampüs içi uygun menü'},
    {'title': 'Mühendislik Kantini', 'type': 'yemek', 'subtitle': 'Hızlı atıştırmalık'},
    {'title': 'Ana Giriş Durağı', 'type': 'durak', 'subtitle': 'Otobüs ve Minibüs'},
    {'title': 'Metro Çıkışı', 'type': 'durak', 'subtitle': 'M4 Hattı'},
    {'title': 'Merkez Kütüphane', 'type': 'kutuphane', 'subtitle': '7/24 Açık'},
    {'title': 'İTÜ Maslak', 'type': 'universite', 'subtitle': 'Üniversite Kampüsü'},
    {'title': 'Boğaziçi Üniversitesi', 'type': 'universite', 'subtitle': 'Üniversite Kampüsü'},
    {'title': 'İstanbul Galata Üniversitesi', 'type': 'universite', 'subtitle': 'Şişhane Kampüsü'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _query = _searchController.text.trim();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Ara (Kullanıcı, Konu, Mekan)...",
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.white70),
              contentPadding: EdgeInsets.only(top: 4),
            ),
            cursorColor: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: "Kullanıcılar"),
            Tab(text: "Konular"),
            Tab(text: "Mekanlar"),
          ],
        ),
      ),
      body: _query.isEmpty
          ? _buildEmptyState(isDark)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(),
                _buildPostsTab(),
                _buildLocationsTab(),
              ],
            ),
    );
  }

  // --- 1. KULLANICI ARAMA ---
  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      // Firestore'da "like" sorgusu olmadığı için basit bir aralık sorgusu kullanıyoruz
      stream: FirebaseFirestore.instance
          .collection('kullanicilar')
          .where('takmaAd', isGreaterThanOrEqualTo: _query)
          .where('takmaAd', isLessThan: '${_query}z')
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        // Eğer takma ad ile bulunamazsa, 'ad' alanı ile de filtrelemeyi deneyebiliriz (client-side)
        // Ancak şimdilik basit tutuyoruz.
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNotFound("Kullanıcı bulunamadı.");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return AnimatedListItem(
              index: index,
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (data['avatarUrl'] != null) ? CachedNetworkImageProvider(data['avatarUrl']) : null,
                    child: (data['avatarUrl'] == null) ? Text(data['takmaAd'][0].toUpperCase()) : null,
                  ),
                  title: Text(data['takmaAd'] ?? 'Bilinmeyen', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['ad'] ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => KullaniciProfilDetayEkrani(userId: doc.id, userName: data['takmaAd'])));
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 2. KONU (FORUM) ARAMA ---
  Widget _buildPostsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gonderiler')
          .where('baslik', isGreaterThanOrEqualTo: _query)
          .where('baslik', isLessThan: '${_query}z')
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNotFound("İlgili konu bulunamadı.");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return AnimatedListItem(
              index: index,
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.article, color: AppColors.primary),
                  title: Text(data['baslik'] ?? 'Başlıksız', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['mesaj'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => GonderiDetayEkrani.fromDoc(doc)));
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 3. MEKAN ARAMA (YEREL LİSTE) ---
  Widget _buildLocationsTab() {
    final filteredList = _allLocations.where((loc) {
      final title = loc['title'].toString().toLowerCase();
      final queryLower = _query.toLowerCase();
      return title.contains(queryLower);
    }).toList();

    if (filteredList.isEmpty) return _buildNotFound("Mekan bulunamadı.");

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final loc = filteredList[index];
        IconData icon = Icons.place;
        Color color = Colors.red;

        if (loc['type'] == 'yemek') { icon = Icons.restaurant; color = Colors.orange; }
        else if (loc['type'] == 'durak') { icon = Icons.directions_bus; color = Colors.blue; }
        else if (loc['type'] == 'kutuphane') { icon = Icons.menu_book; color = Colors.purple; }
        else if (loc['type'] == 'universite') { icon = Icons.school; color = Colors.red; }

        return AnimatedListItem(
          index: index,
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
              title: Text(loc['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(loc['subtitle'] ?? ''),
              trailing: const Icon(Icons.map, color: Colors.grey),
              onTap: () {
                // Haritayı aç ve o filtreyi uygula
                Navigator.push(context, MaterialPageRoute(builder: (_) => KampusHaritasiSayfasi(initialFilter: loc['type'])));
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 80, color: isDark ? Colors.grey[800] : Colors.grey[300]),
          const SizedBox(height: 20),
          Text("Aramak için yazmaya başlayın", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildNotFound(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sentiment_dissatisfied_rounded, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}