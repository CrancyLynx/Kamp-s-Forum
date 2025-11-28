import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'arama_sayfasi.dart';
import 'app_colors.dart';
import 'gonderi_detay_ekrani.dart';
import 'news_service.dart';
import 'kampus_haritasi_sayfasi.dart';

class KesfetSayfasi extends StatefulWidget {
  const KesfetSayfasi({super.key});

  @override
  State<KesfetSayfasi> createState() => _KesfetSayfasiState();
}

class _KesfetSayfasiState extends State<KesfetSayfasi> {
  late Future<List<Article>> _newsFuture;
  late Future<List<DocumentSnapshot>> _forumPostsFuture;
  String _selectedNewsCategory = 'general';

  // Haber Kategorileri
  final Map<String, String> _newsCategories = {
    'general': 'Gündem',
    'technology': 'Teknoloji',
    'science': 'Bilim',
    'business': 'Ekonomi',
    'entertainment': 'Kültür',
    'health': 'Sağlık',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _newsFuture = NewsService().fetchTopHeadlines(category: _selectedNewsCategory);
      _forumPostsFuture = _fetchPopularForumPosts();
    });
  }

  Future<List<DocumentSnapshot>> _fetchPopularForumPosts() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('gonderiler')
          .orderBy('commentCount', descending: true)
          .limit(5)
          .get();
      return querySnapshot.docs;
    } catch (e) {
      return [];
    }
  }

  void _onCategorySelected(String categoryKey) {
    setState(() {
      _selectedNewsCategory = categoryKey;
      _newsFuture = NewsService().fetchTopHeadlines(category: categoryKey);
    });
  }

  // --- AKILLI RESİM SEÇİCİ (GERİ GELDİ) ---
  // Başlık analizi yaparak en uygun Unsplash görselini döndürür.
  String _getSmartFallbackImage(String title) {
    final t = title.toLowerCase();
    
    if (t.contains('teknoloji') || t.contains('yapay') || t.contains('kod') || t.contains('yazılım') || t.contains('hackathon')) {
      return "https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&q=80"; // Tech
    } else if (t.contains('sanat') || t.contains('tiyatro') || t.contains('sinema') || t.contains('konser') || t.contains('müzik') || t.contains('festival')) {
      return "https://images.unsplash.com/photo-1499364615650-ec387c147984?w=600&q=80"; // Sanat/Müzik
    } else if (t.contains('spor') || t.contains('maç') || t.contains('turnuva') || t.contains('futbol') || t.contains('basketbol')) {
      return "https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=600&q=80"; // Spor
    } else if (t.contains('sağlık') || t.contains('beslenme') || t.contains('psikoloji') || t.contains('yoga')) {
      return "https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=600&q=80"; // Sağlık
    } else if (t.contains('ekonomi') || t.contains('kariyer') || t.contains('staj') || t.contains('iş') || t.contains('zirve')) {
      return "https://images.unsplash.com/photo-1565514020176-dbf2238cd872?w=600&q=80"; // Kariyer
    } else if (t.contains('bilim') || t.contains('uzay') || t.contains('araştırma') || t.contains('proje')) {
      return "https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=600&q=80"; // Bilim
    } else if (t.contains('yemek') || t.contains('kahvaltı') || t.contains('piknik')) {
      return "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&q=80"; // Yemek
    } else if (t.contains('gezi') || t.contains('kamp') || t.contains('doğa')) {
      return "https://images.unsplash.com/photo-1507608616759-54f48f0af0ee?w=600&q=80"; // Doğa
    }
    
    // Varsayılan
    return "https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=600&q=80"; 
  }

  // --- TARİH FORMATLAYICI ---
  String _formatEventDate(DateTime date) {
    const months = ["", "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
    return "${date.day} ${months[date.month]}";
  }

  // --- DİNAMİK ETKİNLİK LİSTESİ (GERİ GELDİ) ---
  List<Map<String, String>> _generateUpcomingEvents() {
    final now = DateTime.now();
    return [
      {
        'title': 'Yapay Zeka ve Gelecek Semineri',
        'date': '${_formatEventDate(now.add(const Duration(days: 2)))} - Konferans Salonu',
        'image': 'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=600&q=80',
      },
      {
        'title': 'Kampüs Bahar Konseri',
        'date': '${_formatEventDate(now.add(const Duration(days: 5)))} - Stadyum',
        'image': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
      },
      {
        'title': 'Vize Öncesi Motivasyon Kahvaltısı',
        'date': '${_formatEventDate(now.add(const Duration(days: 7)))} - Sosyal Tesisler',
        'image': '', // Resim yok, akıllı sistem çalışacak (Yemek)
      },
      {
        'title': 'Kariyer Zirvesi 2025',
        'date': '${_formatEventDate(now.add(const Duration(days: 10)))} - Kültür Merkezi',
        'image': 'https://images.unsplash.com/photo-1515187029135-18ee286d815b?w=600&q=80',
      },
      {
        'title': 'Bölümler Arası Futbol Turnuvası',
        'date': '${_formatEventDate(now.add(const Duration(days: 12)))} - Halı Saha',
        'image': '', // Resim yok, akıllı sistem çalışacak (Spor)
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final events = _generateUpcomingEvents();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadData(),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // ARAMA BARINI (AppBar Yokken Gerekli)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GestureDetector(
                    onTap: () {
                       Navigator.push(context, MaterialPageRoute(builder: (context) => const AramaSayfasi()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey[600]),
                          const SizedBox(width: 10),
                          Text("Kampüste ara...", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // HIZLI MENÜ
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildQuickAction(Icons.restaurant, "Yemek", Colors.orange),
                      _buildQuickAction(Icons.directions_bus, "Durak", Colors.blue),
                      _buildQuickAction(Icons.local_library, "Kütüphane", Colors.brown),
                      _buildQuickAction(Icons.map, "Harita", Colors.green),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // HABERLER
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Gündem", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            value: _selectedNewsCategory,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.filter_list, size: 20),
                            items: _newsCategories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                            onChanged: (v) => v != null ? _onCategorySelected(v) : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildNewsSlider(),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ETKİNLİKLER
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text("Yaklaşan Etkinlikler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160, 
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          // Resmi akıllıca seç
                          final String imageToUse = (event['image'] != null && event['image']!.isNotEmpty) 
                              ? event['image']! 
                              : _getSmartFallbackImage(event['title']!);
                              
                          return _buildEventCard(event['title']!, event['date']!, imageToUse);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // POPÜLER KONULAR
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: const Text("Popüler Tartışmalar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              
              FutureBuilder<List<DocumentSnapshot>>(
                future: _forumPostsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const SliverToBoxAdapter(child: SizedBox(height: 50));
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = snapshot.data![index];
                        final data = post.data() as Map<String, dynamic>;
                        return _buildForumTile(context, post, data, index + 1);
                      },
                      childCount: snapshot.data!.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        String filter = 'all';
        if (label == 'Yemek') filter = 'yemek';
        if (label == 'Durak') filter = 'durak';
        if (label == 'Kütüphane') filter = 'kutuphane';
        Navigator.push(context, MaterialPageRoute(builder: (context) => KampusHaritasiSayfasi(initialFilter: filter)));
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 20.0),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsSlider() {
    return FutureBuilder<List<Article>>(
      future: _newsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container(height: 180, margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)));
        final articles = snapshot.data!;
        if (articles.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 180,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.9),
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              // AKILLI RESİM KULLANIMI BURADA DA VAR
              final img = (article.urlToImage != null && article.urlToImage!.isNotEmpty) 
                  ? article.urlToImage! 
                  : _getSmartFallbackImage(article.title);
                  
              return GestureDetector(
                onTap: () async { if(await canLaunchUrl(Uri.parse(article.url))) launchUrl(Uri.parse(article.url)); },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: img, 
                            fit: BoxFit.cover, 
                            errorWidget: (_,__,___) => Container(color: Colors.grey)
                          ),
                        ),
                      ),
                      Positioned.fill(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)], stops: const [0.5, 1.0])))),
                      Positioned(
                        bottom: 12, left: 12, right: 12, 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                              child: Text(article.sourceName, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 4),
                            Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEventCard(String title, String date, String imageUrl) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12), 
            child: CachedNetworkImage(
              imageUrl: imageUrl, 
              height: 90, 
              width: double.infinity, 
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(color: Colors.grey[300], child: Icon(Icons.event, color: Colors.grey)),
            )
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(date, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildForumTile(BuildContext context, DocumentSnapshot post, Map<String, dynamic> data, int rank) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: rank <= 3 ? AppColors.primary : Colors.grey[200],
        child: Text("#$rank", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: rank <= 3 ? Colors.white : Colors.black54)),
      ),
      title: Text(data['baslik'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text("${data['commentCount']} yorum • ${data['ad'] ?? 'Anonim'}", style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GonderiDetayEkrani.fromDoc(post))),
    );
  }
}