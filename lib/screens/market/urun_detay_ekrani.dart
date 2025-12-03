import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../chat/sohbet_detay_ekrani.dart';
// Düzeltilmiş Importlar
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../utils/app_colors.dart';
import '../profile/kullanici_profil_detay_ekrani.dart';

class UrunDetayEkrani extends StatelessWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const UrunDetayEkrani({super.key, required this.productId, required this.productData});

  void _contactSeller(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final sellerId = productData['sellerId'];

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giriş yapmalısınız.")));
      return;
    }
    if (currentUserId == sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu sizin kendi ilanınız.")));
      return;
    }

    List<String> ids = [currentUserId, sellerId];
    ids.sort();
    String chatId = ids.join('_');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SohbetDetayEkrani(
          chatId: chatId,
          receiverId: sellerId,
          receiverName: productData['sellerName'],
          receiverAvatarUrl: productData['sellerAvatar'],
        ),
      ),
    );
  }

  void _toggleSoldStatus(BuildContext context) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != productData['sellerId']) return;

    bool newStatus = !(productData['isSold'] ?? false);
    await FirebaseFirestore.instance.collection('urunler').doc(productId).update({'isSold': newStatus});
    Navigator.pop(context);
  }

  void _deleteProduct(BuildContext context) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != productData['sellerId']) return;

    await FirebaseFirestore.instance.collection('urunler').doc(productId).delete();
    Navigator.pop(context);
  }

  // YENİ: Ürün Şikayet Fonksiyonu
  void _reportProduct(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ürünü Şikayet Et"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Lütfen şikayet sebebinizi belirtin:"),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: "Örn: Sahte ürün, yanlış kategori, dolandırıcılık...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir sebep belirtin.")));
                return;
              }

              Navigator.pop(ctx);
              final currentUser = FirebaseAuth.instance.currentUser;

              try {
                await FirebaseFirestore.instance.collection('sikayetler').add({
                  'reporterId': currentUser?.uid,
                  'reporterName': currentUser?.displayName ?? 'Kullanıcı',
                  'targetId': productId,
                  'targetType': 'product',
                  'targetTitle': productData['title'], // Ürün başlığı
                  'targetOwnerId': productData['sellerId'],
                  'reason': reason,
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'pending',
                });

                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şikayetiniz alındı."), backgroundColor: AppColors.success));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bir hata oluştu: $e"), backgroundColor: AppColors.error));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text("Şikayet Et"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMyProduct = FirebaseAuth.instance.currentUser?.uid == productData['sellerId'];
    final bool isSold = productData['isSold'] ?? false;
    final timeStr = productData['timestamp'] != null 
        ? timeago.format((productData['timestamp'] as Timestamp).toDate(), locale: 'tr') 
        : '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    cacheManager: DefaultCacheManager(), // YENİ: Merkezi önbellek yöneticisi kullanılıyor.
                    imageUrl: productData['imageUrl'] ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_,__) => Container(color: Colors.grey[300]),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (isMyProduct)
                PopupMenuButton<String>(
                  icon: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.more_vert, color: Colors.white)),
                  onSelected: (val) {
                    if (val == 'sold') _toggleSoldStatus(context);
                    if (val == 'delete') _deleteProduct(context);
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: 'sold', child: Text(isSold ? "Satışa Geri Al" : "Satıldı Olarak İşaretle")),
                    const PopupMenuItem(value: 'delete', child: Text("İlanı Sil", style: TextStyle(color: Colors.red))),
                  ],
                )
              else
                // YENİ: Başkası için Şikayet Et butonu
                IconButton(
                  onPressed: () => _reportProduct(context),
                  icon: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.flag, color: Colors.white)),
                  tooltip: "Şikayet Et",
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${productData['price']}₺", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                        child: Text(timeStr, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(productData['title'] ?? 'Ürün', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(productData['category'] ?? 'Diğer', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 20),
                  const Text("Açıklama", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    productData['description'] ?? 'Açıklama yok.',
                    style: TextStyle(fontSize: 15, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8), height: 1.5),
                  ),
                  // YENİ: Satıcı bilgileri daha belirgin hale getirildi.
                  const SizedBox(height: 30),
                  const Text("Satıcı Bilgileri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KullaniciProfilDetayEkrani(userId: productData['sellerId'], userName: productData['sellerName']))),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundImage: (productData['sellerAvatar'] != null && productData['sellerAvatar'].isNotEmpty) ? CachedNetworkImageProvider(productData['sellerAvatar'], cacheManager: DefaultCacheManager()) : null,
                              child: (productData['sellerAvatar'] == null || productData['sellerAvatar'].isEmpty) ? const Icon(Icons.person, size: 30) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(productData['sellerName'] ?? 'Satıcı', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  const Text("Profilini Görüntüle", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: (isMyProduct || isSold) ? null : () => _contactSeller(context),
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(isMyProduct ? "Sizin İlanınız" : (isSold ? "Bu Ürün Satıldı" : "Satıcıya Mesaj At")),
            style: ElevatedButton.styleFrom(
              backgroundColor: (isSold) ? Colors.grey : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}