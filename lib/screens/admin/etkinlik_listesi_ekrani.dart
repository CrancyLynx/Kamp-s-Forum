import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; 
import '../../utils/app_colors.dart';
import 'etkinlik_ekleme_ekrani.dart'; 
import '../event/etkinlik_detay_ekrani.dart';
import 'kullanici_listesi_ekrani.dart'; 

class EtkinlikListesiEkrani extends StatefulWidget {
  const EtkinlikListesiEkrani({super.key});

  @override
  State<EtkinlikListesiEkrani> createState() => _EtkinlikListesiEkraniState();
}

class _EtkinlikListesiEkraniState extends State<EtkinlikListesiEkrani> {
  // En yeni etkinlikleri en üstte göster (Orijinal sıralama korundu)
  final Stream<QuerySnapshot> _eventsStream = FirebaseFirestore.instance
      .collection('etkinlikler')
      .orderBy('date', descending: true)
      .snapshots();

  Future<void> _deleteEvent(String eventId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Silmeyi Onayla"),
        content: const Text("Bu etkinliği kalıcı olarak silmek istediğinizden emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('etkinlikler').doc(eventId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Etkinlik başarıyla silindi."), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Hata oluştu: $e"), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
  
  // Katılımcı Listesini Gösteren Fonksiyon (Orijinal Veri Tipi Cast işlemi korundu)
  void _showAttendees(String title, List<dynamic> attendees) {
    if (attendees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu etkinlikte henüz katılımcı yok."), backgroundColor: AppColors.info));
      return;
    }
    
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => KullaniciListesiEkrani(
          title: "$title Katılımcıları (${attendees.length})", 
          userIds: attendees.cast<String>(), // Katılımcı ID'leri string listesine çevrildi
          hideAppBar: false, // Yeni sayfada AppBar göster
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Arka plan NestedScrollView'dan gelir
      body: StreamBuilder<QuerySnapshot>(
        stream: _eventsStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Bir şeyler ters gitti.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Henüz etkinlik eklenmemiş.", style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // FAB boşluğu
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
               return _buildEventCard(snapshot.data!.docs[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addEventFAB',
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const EtkinlikEklemeEkrani()));
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Yeni Etkinlik", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 4,
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot eventDoc) {
    final data = eventDoc.data() as Map<String, dynamic>;
    final DateTime eventDate = (data['date'] as Timestamp).toDate();
    final List<dynamic> attendees = data['attendees'] ?? []; 
    final bool isPast = eventDate.isBefore(DateTime.now());

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Etkinlik Detay Ekranına Yönlendirme
          Navigator.push(context, MaterialPageRoute(builder: (_) => EtkinlikDetayEkrani(eventDoc: eventDoc)));
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Resim Alanı
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: data['imageUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey[200]),
                            errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                          )
                        : Container(color: AppColors.primaryLight, child: const Icon(Icons.event_note, size: 50, color: AppColors.primary)),
                  ),
                ),
                if(isPast)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: const Text("TAMAMLANDI", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  )
              ],
            ),
            
            // Bilgi Alanı
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Expanded(child: Text(data['title'] ?? 'Başlıksız Etkinlik', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                       if(isPast) const Icon(Icons.history, color: Colors.grey),
                     ],
                   ),
                   const SizedBox(height: 8),
                   Row(
                     children: [
                       const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                       const SizedBox(width: 8),
                       Text(DateFormat('dd MMMM yyyy - HH:mm', 'tr_TR').format(eventDate), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                     ],
                   ),
                   const SizedBox(height: 4),
                   Row(
                     children: [
                       const Icon(Icons.location_on, size: 16, color: Colors.grey),
                       const SizedBox(width: 8),
                       Text(data['location'] ?? 'Konum Belirtilmemiş', style: const TextStyle(color: Colors.grey)),
                     ],
                   ),
                   const Divider(height: 24),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       TextButton.icon(
                         onPressed: () => _showAttendees(data['title'] ?? '', attendees),
                         icon: const Icon(Icons.people_alt, color: AppColors.success),
                         label: Text("${attendees.length} Katılımcı", style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                       ),
                       Row(
                         children: [
                           IconButton(
                             icon: const Icon(Icons.edit, color: AppColors.info),
                             onPressed: () {
                               Navigator.push(context, MaterialPageRoute(builder: (context) => EtkinlikEklemeEkrani(event: eventDoc)));
                             },
                             tooltip: 'Düzenle',
                           ),
                           IconButton(
                             icon: const Icon(Icons.delete_forever, color: AppColors.error),
                             onPressed: () => _deleteEvent(eventDoc.id),
                             tooltip: 'Sil',
                           ),
                         ],
                       ),
                     ],
                   )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}