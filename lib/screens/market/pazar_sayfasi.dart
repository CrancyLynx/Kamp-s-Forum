import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// İMPORT DÜZELTMELERİ
import 'urun_ekleme_ekrani.dart';
import 'urun_detay_ekrani.dart';
import '../chat/sohbet_listesi_ekrani.dart';
import '../notification/bildirim_ekrani.dart'; // DÜZELTİLDİ: Doğru dosya yolu
import '../../widgets/animated_list_item.dart';
import '../../utils/app_colors.dart';
import '../../utils/maskot_helper.dart';
import '../../widgets/app_header.dart';  // YENİ: Modern header widget'ı
import '../../services/data_preload_service.dart';


class PazarSayfasi extends StatefulWidget {
  const PazarSayfasi({super.key});

  @override
  State<PazarSayfasi> createState() => _PazarSayfasiState();
}

class _PazarSayfasiState extends State<PazarSayfasi> {
  String _selectedCategory = 'Tümü';
  final List<String> _categories = ['Favorilerim', 'Tümü', 'Kitap', 'Notlar', 'Elektronik', 'Ev Eşyası', 'Giyim', 'Diğer'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  
  // Sıralama için state değişkeni
  String _sortOrder = 'newest'; // 'newest', 'price_asc', 'price_desc'

  // Favoriler için state
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  final bool _isGuest = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
  Set<String> _favoriteProductIds = {};

  // --- MASKOT İÇİN KEY'LER ---
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    // Arka planda market cache'ini ısıt
    DataPreloadService.getCachedData('market_products').catchError((e) {
      debugPrint('Market cache warm-up hatasi: $e');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
  }

  void _showTutorial() {
    MaskotHelper.checkAndShow(
      context,
      featureKey: 'pazar_tutorial_gosterildi',
      targets: [
        TargetFocus(
          identify: "search-bar",
          keyTarget: _searchBarKey,
          alignSkip: Alignment.topRight,
          contents: [
            TargetContent(align: ContentAlign.bottom, builder: (context, controller) => MaskotHelper.buildTutorialContent(context, title: 'Aradığını Bul', description: 'Buradan satıştaki ürünler arasında arama yapabilir veya kategorilere göre filtreleyebilirsin.')),
          ],
        ),
        TargetFocus(
          identify: "fab-add-item",
          keyTarget: _fabKey,
          alignSkip: Alignment.topLeft,
          contents: [
            TargetContent(align: ContentAlign.top, builder: (context, controller) => MaskotHelper.buildTutorialContent(context, title: 'İlan Ver', description: 'Kullanmadığın eşyaları, kitapları veya notları satmak için buraya tıklayarak kolayca ilan oluşturabilirsin.', mascotAssetPath: 'assets/images/satici_bay.png')),
          ],
        ),
      ]);
  }

  // Favorileri yükle
  Future<void> _loadFavorites() async {
    if (_userId == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(_userId).get();
    if (userDoc.exists && userDoc.data()!.containsKey('favoriUrunler')) {
      if (mounted) {
        setState(() {
          _favoriteProductIds = Set<String>.from(userDoc.data()!['favoriUrunler']);
        });
      }
    }
  }

  // Favori durumunu değiştir
  Future<void> _toggleFavorite(String productId) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Favorilere eklemek için giriş yapmalısınız.")));
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('kullanicilar').doc(_userId);
    
    setState(() {
      if (_favoriteProductIds.contains(productId)) {
        _favoriteProductIds.remove(productId);
        userRef.update({'favoriUrunler': FieldValue.arrayRemove([productId])});
      } else {
        _favoriteProductIds.add(productId);
        userRef.update({'favoriUrunler': FieldValue.arrayUnion([productId])});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.15),
              theme.scaffoldBackgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ✅ YENİ: Modern senkronize header
              PanelHeader(
              title: 'Kampüs Pazarı',
              subtitle: 'Ürün al ve sat',
              icon: Icons.shopping_bag_rounded,
              accentColor: AppColors.primary,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: 'Mesajlar',
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SohbetListesiEkrani()));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    tooltip: 'Bildirimler',
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const BildirimEkrani()));
                    },
                  ),
                ],
              ),
            ),
            
            // ✅ ARAMA BAR
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: _searchBarKey,
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Ders kitabı, not, eşya ara...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),

            // 2. KATEGORİLER VE SIRALAMA - Kompakt tasarım
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sıralama Butonları
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSortChip('En Yeni', 'newest', Icons.new_releases),
                        const SizedBox(width: 8),
                        _buildSortChip('Fiyat (Artan)', 'price_asc', Icons.arrow_upward),
                        const SizedBox(width: 8),
                        _buildSortChip('Fiyat (Azalan)', 'price_desc', Icons.arrow_downward),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  // Kategori Filtreleri
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            avatar: category == 'Favorilerim' ? Icon(Icons.favorite, color: isSelected ? Colors.white : Colors.redAccent, size: 16) : null,
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (selected) => setState(() => _selectedCategory = category),
                            selectedColor: category == 'Favorilerim' ? Colors.redAccent : AppColors.primary,
                            backgroundColor: Theme.of(context).cardColor,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.bold,
                            ),
                            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // 3. ÜRÜN LİSTESİ
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('urunler').orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Hata: ${snapshot.error}"));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sell_outlined, size: 60, color: Colors.grey[300]), const SizedBox(height: 10), const Text("Bu kategoride ilan yok.", style: TextStyle(color: Colors.grey))]));
                  }

                  var docs = _filterAndSortProducts(snapshot.data!.docs.cast<DocumentSnapshot>());

                  if (docs.isEmpty && _searchQuery.isNotEmpty) {
                    return const Center(child: Text("Arama sonucu bulunamadı."));
                  }

                  return MasonryGridView.count(
                    padding: const EdgeInsets.all(12),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return AnimatedListItem(index: index, child: _buildProductCard(doc));
                    },
                  );
                },
              ),
            ),
          ],
        ),
        ),
      ),
      floatingActionButton: !_isGuest
          ? FloatingActionButton.extended(
              key: _fabKey,
              heroTag: 'pazar_ilan_fab',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const UrunEklemeEkrani()));
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("İlan Ver", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildSortChip(String label, String sortKey, IconData icon) {
    final isSelected = _sortOrder == sortKey;
    return ChoiceChip(
      label: Row(
        children: [
          Icon(icon, size: 16, color: isSelected ? AppColors.primary : Colors.grey[600]),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _sortOrder = sortKey);
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.1),
      backgroundColor: Theme.of(context).cardColor,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Theme.of(context).textTheme.bodyLarge?.color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      side: BorderSide(color: isSelected ? AppColors.primary.withOpacity(0.5) : Colors.grey.withOpacity(0.2)),
    );
  }

  Widget _buildProductCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final price = data['price'] ?? 0;
    final isSold = data['isSold'] ?? false;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UrunDetayEkrani(productId: doc.id, productData: data))),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resim Alanı
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
                  child: AspectRatio(
                    aspectRatio: 1, // 1:1 (kare) oran
                    child: CachedNetworkImage(                      
                      imageUrl: data['imageUrl'] ?? '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  ),
                ),
                if (isSold)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                      child: const Text("SATILDI", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                Positioned(
                  bottom: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                    child: Text("${price}₺", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                // Favori Butonu
                Positioned(
                  top: 0,
                  left: 0,
                  child: IconButton(
                    icon: Icon(
                      _favoriteProductIds.contains(doc.id) ? Icons.favorite : Icons.favorite_border,
                      color: _favoriteProductIds.contains(doc.id) ? Colors.redAccent : Colors.white,
                    ),
                    onPressed: () => _toggleFavorite(doc.id),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.3),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
            // Bilgi Alanı
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title'] ?? 'Ürün', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: (data['sellerAvatar'] != null && (data['sellerAvatar'] as String).isNotEmpty)
                            ? CachedNetworkImageProvider(data['sellerAvatar'])
                            : null,
                        child: (data['sellerAvatar'] == null || (data['sellerAvatar'] as String).isEmpty)
                            ? Icon(Icons.person, size: 12, color: Colors.grey[600])
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(data['sellerName'] ?? 'Satıcı', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DocumentSnapshot> _filterAndSortProducts(List<DocumentSnapshot> docs) {
    // Filtreleme
    docs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().toLowerCase();
      final matchesSearch = title.contains(_searchQuery);

      final matchesCategory = _selectedCategory == 'Tümü' ||
          (_selectedCategory == 'Favorilerim' && _favoriteProductIds.contains(doc.id)) ||
          (data['category'] == _selectedCategory);
      final isNotFavoriteFilter = _selectedCategory != 'Favorilerim';

      return matchesSearch && (isNotFavoriteFilter ? matchesCategory : _favoriteProductIds.contains(doc.id));
    }).toList();

    // Sıralama
    if (_sortOrder == 'price_asc') {
      docs.sort((a, b) {
        final priceA = ((a.data() as Map<String, dynamic>)['price'] ?? 0) as num;
        final priceB = ((b.data() as Map<String, dynamic>)['price'] ?? 0) as num;
        return priceA.compareTo(priceB);
      });
    } else if (_sortOrder == 'price_desc') {
      docs.sort((a, b) {
        final priceA = ((a.data() as Map<String, dynamic>)['price'] ?? 0) as num;
        final priceB = ((b.data() as Map<String, dynamic>)['price'] ?? 0) as num;
        return priceB.compareTo(priceA);
      });
    }

    return docs;
  }
}
