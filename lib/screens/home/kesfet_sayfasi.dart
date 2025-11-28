import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
import '../search/arama_sayfasi.dart';
import '../forum/gonderi_detay_ekrani.dart';
import '../../services/news_service.dart';
import '../map/kampus_haritasi_sayfasi.dart';
import '../../utils/app_colors.dart';
import '../profile/kullanici_profil_detay_ekrani.dart'; 

class KesfetSayfasi extends StatefulWidget {
  const KesfetSayfasi({super.key});

  @override
  State<KesfetSayfasi> createState() => _KesfetSayfasiState();
}

class _KesfetSayfasiState extends State<KesfetSayfasi> with TickerProviderStateMixin {
  late Future<List<Article>> _newsFuture;
  late Future<List<DocumentSnapshot>> _forumPostsFuture;
  late Future<List<DocumentSnapshot>> _topPostersFuture; 
  late Future<List<DocumentSnapshot>> _mostLikedFuture; 
  late Future<List<DocumentSnapshot>> _eventsFuture; // YENİ: Etkinlikler için Future
  
  String _selectedNewsCategory = 'general';

  late TabController _tabController;
  late TabController _leaderboardTabController; 

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
    _tabController = TabController(length: 2, vsync: this);
    _leaderboardTabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _leaderboardTabController.dispose();
    super.dispose();
  }

  void _loadData() {
    // Haber servisini saat başı veya yeniledikçe çekmeye devam ediyoruz.
    setState(() {
      _newsFuture = NewsService().fetchTopHeadlines(category: _selectedNewsCategory);
      _forumPostsFuture = _fetchPopularForumPosts();
      _topPostersFuture = _fetchTopUsers(sortBy: 'postCount');
      _mostLikedFuture = _fetchTopUsers(sortBy: 'likeCount');
      _eventsFuture = _fetchUpcomingEvents(); // YENİ: Etkinlikleri de çek
    });
  }

  // YENİ: Firestore'dan etkinlikleri çeken fonksiyon
  Future<List<DocumentSnapshot>> _fetchUpcomingEvents() async {
    try {
      // Sadece bugünden sonraki etkinlikleri getir ve tarihe göre sırala
      final querySnapshot = await FirebaseFirestore.instance
          .collection('etkinlikler')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .orderBy('date', descending: false)
          .limit(5)
          .get();
      return querySnapshot.docs;
    } catch (e) {
      debugPrint("Yaklaşan etkinlikler çekilemedi: $e");
      return [];
    }
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
      debugPrint("Popüler tartışmalar çekilemedi: $e");
      return [];
    }
  }

  Future<List<DocumentSnapshot>> _fetchTopUsers({required String sortBy}) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('kullanicilar')
          .orderBy(sortBy, descending: true)
          .limit(5)
          .get();
      return querySnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data[sortBy] is int && data[sortBy] > 0;
      }).toList();
    } catch (e) {
      debugPrint("Liderlik tablosu çekilemedi ($sortBy): $e");
      return [];
    }
  }

  void _onCategorySelected(String categoryKey) {
    setState(() {
      _selectedNewsCategory = categoryKey;
      _newsFuture = NewsService().fetchTopHeadlines(category: categoryKey);
    });
  }

  String _getSmartFallbackImage(String title) {
    final t = title.toLowerCase();
    
    if (t.contains('teknoloji') || t.contains('yapay') || t.contains('kod') || t.contains('yazılım') || t.contains('hackathon')) {
      return "https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&q=80";
    } else if (t.contains('sanat') || t.contains('tiyatro') || t.contains('sinema') || t.contains('konser') || t.contains('müzik') || t.contains('festival')) {
      return "https://images.unsplash.com/photo-1499364615650-ec387c147984?w=600&q=80"; 
    } else if (t.contains('spor') || t.contains('maç') || t.contains('turnuva') || t.contains('futbol') || t.contains('basketbol')) {
      return "https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=600&q=80"; 
    } else if (t.contains('sağlık') || t.contains('beslenme') || t.contains('psikoloji') || t.contains('yoga')) {
      return "https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=600&q=80"; 
    } else if (t.contains('ekonomi') || t.contains('kariyer') || t.contains('staj') || t.contains('iş') || t.contains('zirve')) {
      return "https://images.unsplash.com/photo-1565514020176-dbf2238cd872?w=600&q=80"; 
    } else if (t.contains('bilim') || t.contains('uzay') || t.contains('araştırma') || t.contains('proje')) {
      return "https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=600&q=80"; 
    } else if (t.contains('yemek') || t.contains('kahvaltı') || t.contains('piknik')) {
      return "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&q=80"; 
    } else if (t.contains('gezi') || t.contains('kamp') || t.contains('doğa')) {
      return "https://images.unsplash.com/photo-1507608616759-54f48f0af0ee?w=600&q=80"; 
    }
    
    return "https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=600&q=80"; 
  }

  String _formatEventDate(DateTime date) {
    const months = ["", "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
    return "${date.day} ${months[date.month]}";
  }

  // SİLİNDİ: Statik _generateUpcomingEvents metodu

  Widget _buildTabIcon() {
    IconData icon;
    Color color;

    if (_tabController.index == 0) {
      icon = Icons.local_fire_department_rounded;
      color = Colors.red;
    } else {
      // En İyi Katılımcılar (Ateş + Profil karışımı)
      return Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.local_fire_department, color: Colors.orange.shade700, size: 24),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Icon(Icons.person, color: Colors.white, size: 12),
          ),
        ],
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadData(),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // ARAMA BARI
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
                    _buildEventsSlider(), // YENİ: Dinamik Event Slider
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // LİDERLİK TABLOSU & POPÜLER TARTIŞMALAR (Birleştirilmiş Bölüm)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sekme Başlığı (TabBar)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: AnimatedBuilder(
                              animation: _tabController,
                              builder: (context, child) {
                                return _buildTabIcon();
                              },
                            ),
                          ),
                          Expanded(
                            child: TabBar(
                              controller: _tabController,
                              indicatorSize: TabBarIndicatorSize.label,
                              labelColor: AppColors.primary,
                              unselectedLabelColor: Colors.grey,
                              indicator: const UnderlineTabIndicator(
                                borderSide: BorderSide(width: 3.0, color: AppColors.primary),
                                insets: EdgeInsets.symmetric(horizontal: 0),
                              ),
                              tabs: const [
                                Tab(child: Text("Popüler Tartışmalar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                Tab(child: Text("En İyi Katılımcılar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // İçerik (PageView)
                    SizedBox(
                      height: 380, 
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Sekme 1: Popüler Tartışmalar
                          FutureBuilder<List<DocumentSnapshot>>(
                            future: _forumPostsFuture,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Center(child: Text("Henüz popüler tartışma yok."));
                              }
                              return ListView.builder(
                                physics: const NeverScrollableScrollPhysics(), 
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final post = snapshot.data![index];
                                  final data = post.data() as Map<String, dynamic>;
                                  return _buildForumTile(context, post, data, index + 1);
                                },
                              );
                            },
                          ),
                          
                          // Sekme 2: Liderlik Tablosu (İç İçe TabBarView)
                          _buildLeaderboardTabs(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  // YENİ: Dinamik Etkinlik Slider'ı
  Widget _buildEventsSlider() {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text("Şu anda yaklaşan etkinlik bulunmamaktadır.", style: TextStyle(color: Colors.grey[600])),
          );
        }

        final events = snapshot.data!;
        
        return SizedBox(
          height: 160, 
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final eventDoc = events[index];
              final data = eventDoc.data() as Map<String, dynamic>;
              
              final DateTime eventDate = (data['date'] as Timestamp).toDate();
              final String dateString = "${_formatEventDate(eventDate)} - ${data['location'] ?? 'Kampüs Alanı'}";
              
              // Resmi akıllıca seç
              final String imageUrl = (data['imageUrl'] != null && data['imageUrl']!.isNotEmpty) 
                  ? data['imageUrl']! 
                  : _getSmartFallbackImage(data['title'] ?? '');
                  
              return _buildEventCard(data['title'] ?? 'Etkinlik', dateString, imageUrl);
            },
          ),
        );
      },
    );
  }

  // Liderlik Tablosu İç İçe Sekmeleri
  Widget _buildLeaderboardTabs() {
    return Column(
      children: [
        TabBar(
          controller: _leaderboardTabController,
          labelColor: AppColors.success,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.success,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: "En Çok Gönderi"),
            Tab(text: "En Çok Beğeni"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _leaderboardTabController,
            children: [
              _buildLeaderboard(
                context, 
                _topPostersFuture, 
                metricKey: 'postCount',
                metricLabel: 'Gönderi'
              ),
              _buildLeaderboard(
                context, 
                _mostLikedFuture, 
                metricKey: 'likeCount',
                metricLabel: 'Beğeni'
              ),
            ],
          ),
        ),
      ],
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
              final img = (article.urlToImage != null && article.urlToImage!.isNotEmpty) 
                  ? article.urlToImage! 
                  : _getSmartFallbackImage(article.title);
                  
              return GestureDetector(
                onTap: () async { 
                  final url = Uri.parse(article.url);
                  if(await canLaunchUrl(url)) {
                    launchUrl(url, mode: LaunchMode.externalApplication); 
                  }
                },
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GonderiDetayEkrani.fromDoc(post))),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                _buildRankBadge(rank),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['baslik'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.comment_outlined, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            "${data['commentCount'] ?? 0} yorum",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              data['ad'] ?? 'Anonim',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (rank <= 3)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(
                      Icons.local_fire_department,
                      color: rank == 1 ? const Color(0xFFFF512F) : (rank == 2 ? const Color(0xFFFF9966) : const Color(0xFFF09819)),
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboard(BuildContext context, Future<List<DocumentSnapshot>> future, {required String metricKey, required String metricLabel}) {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("Henüz $metricLabel kategorisinde veri yok."));
        }
        
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final userDoc = snapshot.data![index];
            final data = userDoc.data() as Map<String, dynamic>;
            final userName = data['takmaAd'] ?? data['ad'] ?? 'Kullanıcı';
            final avatarUrl = data['avatarUrl'];
            final metricValue = data[metricKey] ?? 0;
            final rank = index + 1;
            
            return _buildUserLeaderboardTile(
              context, 
              userDoc.id,
              userName, 
              avatarUrl, 
              metricValue, 
              metricLabel, 
              rank,
            );
          },
        );
      },
    );
  }

  Widget _buildUserLeaderboardTile(BuildContext context, String userId, String name, String? avatarUrl, int metricValue, String metricLabel, int rank) {
    List<Color> colors;
    
    if (rank == 1) {
      colors = [const Color(0xFFF7941D), const Color(0xFFFF512F)];
    } else if (rank == 2) {
      colors = [const Color(0xFFC0C0C0), const Color(0xFF8C8C8C)];
    } else if (rank == 3) {
      colors = [const Color(0xFFCD7F32), const Color(0xFFB87333)];
    } else {
      colors = [Theme.of(context).cardColor, Theme.of(context).cardColor];
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KullaniciProfilDetayEkrani(userId: userId, userName: name))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: rank <= 3 ? Border.all(color: colors.first.withOpacity(0.5), width: 1.5) : null,
          boxShadow: rank <= 3 
              ? [BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 10)] 
              : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: rank <= 3 ? LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                color: rank > 3 ? Colors.grey.shade300 : null,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  "#$rank",
                  style: TextStyle(
                    color: rank <= 3 ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? CachedNetworkImageProvider(avatarUrl) : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 12),
            
            // İsim
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Metrik Değeri
            Text(
              "$metricValue $metricLabel",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: rank <= 3 ? colors.first : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    List<Color> colors;
    double size = 42;
    double fontSize = 18;
    BoxShadow? shadow;

    if (rank == 1) {
      colors = [const Color(0xFFFF512F), const Color(0xFFDD2476)]; // Kırmızı/Pembe Alev
      shadow = BoxShadow(color: const Color(0xFFFF512F).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4));
    } else if (rank == 2) {
      colors = [const Color(0xFFFF9966), const Color(0xFFFF5E62)]; // Turuncu Alev
      shadow = BoxShadow(color: const Color(0xFFFF9966).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4));
    } else if (rank == 3) {
      colors = [const Color(0xFFF09819), const Color(0xFFEDDE5D)]; // Sarı/Altın Alev
      shadow = BoxShadow(color: const Color(0xFFF09819).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4));
    } else {
      colors = [Colors.grey.shade200, Colors.grey.shade300];
      size = 36;
      fontSize = 14;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: shadow != null ? [shadow] : [],
      ),
      child: Center(
        child: Text(
          "#$rank",
          style: TextStyle(
            color: rank <= 3 ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            fontStyle: rank <= 3 ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}