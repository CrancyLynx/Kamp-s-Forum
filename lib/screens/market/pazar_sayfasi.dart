import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'urun_ekleme_ekrani.dart';
import 'urun_detay_ekrani.dart';
import '../../widgets/animated_list_item.dart';
import '../../utils/app_colors.dart';

class PazarSayfasi extends StatefulWidget {
  const PazarSayfasi({super.key});

  @override
  State<PazarSayfasi> createState() => _PazarSayfasiState();
}

class _PazarSayfasiState extends State<PazarSayfasi> {
  String _selectedCategory = 'Tümü';
  final List<String> _categories = ['Tümü', 'Kitap', 'Notlar', 'Elektronik', 'Ev Eşyası', 'Giyim', 'Diğer'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Performans için Query oluşturucu
  Query _buildQuery() {
    Query query = FirebaseFirestore.instance.collection('urunler');

    // 1. Kategori Filtresi (Server-Side)
    if (_selectedCategory != 'Tümü') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    // 2. Sıralama (En yeniden eskiye)
    // Not: Kategori ile birlikte orderBy kullanmak için Firestore'da Index oluşturmanız gerekebilir.
    // Console'da hata alırsanız linke tıklayıp index'i oluşturun.
    query = query.orderBy('timestamp', descending: true);

    return query;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ÜST BAR & ARAMA
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 28),
                      const SizedBox(width: 8),
                      Text("Kampüs Pazarı", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UrunEklemeEkrani())),
                        icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 30),
                        tooltip: "İlan Ver",
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Arama Çubuğu
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      // Arama metni değiştiğinde setState ile UI'ı yenile
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: "Ürün ara...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // KATEGORİLER
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                          // Kategori değişince aramayı temizlemiyoruz, kullanıcı deneyimi için kalabilir.
                        });
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: Theme.of(context).cardColor,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ÜRÜN LİSTESİ
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _buildQuery().snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Hata: ${snapshot.error}"));
                  }
                  
                  // Firebase'den gelen ham liste
                  var docs = snapshot.data?.docs ?? [];

                  // Arama Filtresi (Client-Side)
                  // Not: Firestore tam metin aramayı (full-text search) desteklemez.
                  // Başlık araması için client-side filtreleme şu anlık en iyi yöntemdir.
                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['title'] ?? '').toString().toLowerCase();
                      return title.contains(_searchQuery);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sell_outlined, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          const Text("Bu kategoride ürün bulunamadı.", style: TextStyle(color: Colors.grey))
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.70, // Kartları biraz daha uzun yaptım
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      return AnimatedListItem(index: index, child: _buildProductCard(docs[index]));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
            Expanded(
              child: Stack(
                children: [
                  Hero( // Resim geçiş efekti
                    tag: 'product_${doc.id}',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: SizedBox(
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: data['imageUrl'] ?? '',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title'] ?? 'Ürün', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(child: Text(data['sellerName'] ?? 'Satıcı', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
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
}