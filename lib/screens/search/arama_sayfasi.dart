import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_colors.dart';
import '../profile/kullanici_profil_detay_ekrani.dart';
import '../forum/gonderi_detay_ekrani.dart';
import '../map/kampus_haritasi_sayfasi.dart';
import '../../widgets/animated_list_item.dart';
import '../../utils/maskot_helper.dart'; // EKLENDİ
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart'; // HATA DÜZELTMESİ: Eksik import

class AramaSayfasi extends StatefulWidget {
  const AramaSayfasi({super.key});

  @override
  State<AramaSayfasi> createState() => _AramaSayfasiState();
}

class _AramaSayfasiState extends State<AramaSayfasi> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  Timer? _debounce;
  Future<List<Map<String, dynamic>>>? _searchResultsFuture;

  // --- YENİ SİSTEM İÇİN GLOBAL KEY ---
  final GlobalKey _searchBarKey = GlobalKey();

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
    _searchController.addListener(_onSearchChanged);

    // --- YENİ SİSTEM İLE MASKOT KODU ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MaskotHelper.checkAndShow(context,
          featureKey: 'arama_tutorial_gosterildi',
          targets: [
            TargetFocus(
                identify: "search-bar",
                keyTarget: _searchBarKey,
                alignSkip: Alignment.bottomRight,
                contents: [
                  TargetContent(
                    align: ContentAlign.top, builder: (context, controller) =>
                      MaskotHelper.buildTutorialContent(
                          context,
                          title: 'Ne Aramıştın?',
                          description: 'Öğrenciler, etkinlikler, ders notları veya topluluklar... Aklına ne geliyorsa buradan kolayca bulabilirsin.',
                          mascotAssetPath: 'assets/images/mutlu_bay.png'),
                  )
                ])
          ]);
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        final newQuery = _searchController.text.trim();
        if (_query != newQuery) {
          setState(() {
            _query = newQuery;
            _searchResultsFuture = _fetchSearchResults(newQuery);
          });
        }
      }
    });
  }

  // --- EVRENSEL ARAMA MANTIĞI ---
  Future<List<Map<String, dynamic>>> _fetchSearchResults(String query) async {
    if (query.isEmpty) return [];

    final queryLower = query.toLowerCase();
    
    // Firestore'da arama yapmak için toUpperCase'in bir sonrası
    final String queryEnd = '${query}z'; 
    
    // 1. Kullanıcı Arama (takmaAd üzerinden)
    final usersFuture = FirebaseFirestore.instance
        .collection('kullanicilar')
        .where('takmaAd', isGreaterThanOrEqualTo: query)
        .where('takmaAd', isLessThan: queryEnd)
        .limit(5)
        .get();

    // 2. Konu (Forum) Arama (baslik üzerinden)
    final postsFuture = FirebaseFirestore.instance
        .collection('gonderiler')
        .where('baslik', isGreaterThanOrEqualTo: query)
        .where('baslik', isLessThan: queryEnd)
        .limit(5)
        .get();
        
    // 3. Mekan Arama (Yerel liste filtresi)
    final locations = _allLocations
        .where((loc) => loc['title'].toString().toLowerCase().contains(queryLower))
        .take(5)
        .map((loc) => {
          'type': 'mekan',
          'title': loc['title'],
          'subtitle': loc['subtitle'],
          'loc_type': loc['type'] 
        })
        .toList();

    // Tüm Firestore sorgularının bitmesini bekle
    final results = await Future.wait([usersFuture, postsFuture]);
    final usersSnapshot = results[0];
    final postsSnapshot = results[1];
    
    List<Map<String, dynamic>> mergedList = [];

    // Kullanıcıları Ekle
    for (var doc in usersSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      // Sadece prefix eşleşenleri veya tam eşleşenleri al
      if ((data['takmaAd'] ?? '').toLowerCase().startsWith(queryLower)) { 
        mergedList.add({
          'type': 'kullanici',
          'id': doc.id,
          'title': data['takmaAd'],
          'subtitle': data['ad'],
          'avatarUrl': data['avatarUrl'],
        });
      }
    }

    // Konuları Ekle
    for (var doc in postsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      // Sadece prefix eşleşenleri veya tam eşleşenleri al
      if ((data['baslik'] ?? '').toLowerCase().startsWith(queryLower)) {
        mergedList.add({
          'type': 'konu',
          'doc': doc, // Detay ekranı için DocumentSnapshot
          'title': data['baslik'],
          'subtitle': data['mesaj'],
        });
      }
    }

    // Mekanları Ekle
    mergedList.addAll(locations);
    
    // Sonuçları başlığa göre alfabetik sıralayarak daha tutarlı bir görünüm elde edebiliriz.
    mergedList.sort((a, b) => (a['title'] ?? '').toString().toLowerCase().compareTo((b['title'] ?? '').toString().toLowerCase()));
    
    return mergedList;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Container(
          key: _searchBarKey, // --- KEY EKLE ---
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(51),
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Tüm uygulamada ara...",
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.white70),
              contentPadding: EdgeInsets.only(top: 4),
            ),
            cursorColor: Colors.white,
          ),
        ),
        // TabBar kaldırıldı
      ),
      body: _query.isEmpty
          ? _buildEmptyState(isDark)
          : _buildUnifiedResults(), // Tekil sonuç listesi gösterilir
    );
  }

  // --- TEKİL SONUÇ LİSTESİ WIDGET'I ---
  Widget _buildUnifiedResults() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchResultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return _buildNotFound("Aramanızla eşleşen sonuç bulunamadı.");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];
            return _buildResultTile(context, item, index);
          },
        );
      },
    );
  }

  Widget _buildResultTile(BuildContext context, Map<String, dynamic> item, int index) {
    final String type = item['type'];
    Widget leading;
    String subtitle;
    VoidCallback onTap;

    // Sonuç tipini sağ üstte gösteren küçük bir etiket
    String typeLabel = type == 'kullanici' ? 'KULLANICI' : (type == 'konu' ? 'KONU' : 'MEKAN');
    Color typeColor = type == 'kullanici' ? AppColors.success : (type == 'konu' ? AppColors.primary : Colors.orange);


    switch (type) {
      case 'kullanici':
        leading = CircleAvatar(
          backgroundImage: (item['avatarUrl'] != null) ? CachedNetworkImageProvider(item['avatarUrl']) : null,
          child: (item['avatarUrl'] == null && item['title'] != null && item['title'].isNotEmpty) 
            ? Text(item['title'][0].toUpperCase()) 
            : const Icon(Icons.person),
        );
        subtitle = item['subtitle'] ?? '';
        onTap = () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => KullaniciProfilDetayEkrani(userId: item['id'], userName: item['title'])));
        };
        break;
        
      case 'konu':
        leading = const Icon(Icons.article, color: AppColors.primary, size: 30);
        // Post mesajının ilk 50 karakteri
        subtitle = (item['subtitle'] as String? ?? '').length > 50 ? item['subtitle'].substring(0, 50) + '...' : item['subtitle']; 
        onTap = () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => GonderiDetayEkrani.fromDoc(item['doc'] as DocumentSnapshot)));
        };
        break;
        
      case 'mekan':
        IconData icon = Icons.place;
        Color color = Colors.red;
        final locType = item['loc_type'];
        if (locType == 'yemek') { icon = Icons.restaurant; color = Colors.orange; }
        else if (locType == 'durak') { icon = Icons.directions_bus; color = Colors.blue; }
        else if (locType == 'kutuphane') { icon = Icons.menu_book; color = Colors.purple; }
        else if (locType == 'universite') { icon = Icons.school; color = Colors.red; }
        
        leading = CircleAvatar(backgroundColor: color.withAlpha(26), child: Icon(icon, color: color));
        subtitle = item['subtitle'] ?? '';
        onTap = () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => KampusHaritasiSayfasi(initialFilter: locType)));
        };
        break;
        
      default:
        leading = const Icon(Icons.help_outline);
        subtitle = 'Bilinmeyen sonuç tipi';
        onTap = () {};
    }


    return AnimatedListItem(
      index: index,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: ListTile(
          leading: leading,
          title: Text(item['title'] ?? 'Başlıksız', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                typeLabel, 
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor.withAlpha(179)),
              )
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 80, color: isDark ? Colors.grey[800] : Colors.grey[300]),
          const SizedBox(height: 20),
          Text("Tüm uygulamada arama yapın", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          Text("Kullanıcılar, konular ve mekanlar tek listede.", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
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