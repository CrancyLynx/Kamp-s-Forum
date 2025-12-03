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
  late Stream<QuerySnapshot> _eventsStream;
  final Set<String> _deletingEvents = {}; // Silme işlemindeki etkinlikleri takip et

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  void _initializeStream() {
    _eventsStream = FirebaseFirestore.instance
        .collection('etkinlikler')
        .orderBy('date', descending: true)
        .snapshots();
  }

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
        // UI'ı hemen güncelle (optimistik update)
        setState(() {
          _deletingEvents.add(eventId);
        });

        // Firestore'dan sil
        await FirebaseFirestore.instance.collection('etkinlikler').doc(eventId).delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Etkinlik başarıyla silindi."),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } on FirebaseException catch (e) {
        setState(() {
          _deletingEvents.remove(eventId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Hata oluştu: ${e.message ?? 'Bilinmeyen hata'}"),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _deletingEvents.remove(eventId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Beklenmeyen hata: $e"),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
            ),
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
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: _eventsStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          // Hata durumu
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    const Text("Etkinlikler yüklenemedi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _initializeStream()),
                      icon: const Icon(Icons.refresh),
                      label: const Text("Tekrar Dene"),
                    ),
                  ],
                ),
              ),
            );
          }

          // Yükleniyor
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Boş liste
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text("Henüz etkinlik eklenmemiş", 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Text("Yeni etkinlik eklemek için + butonunu kullan", 
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ],
                ),
              ),
            );
          }

          // Etkinlik Listesi
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final eventDoc = snapshot.data!.docs[index];
              // Silme işlemindeyse kartı gizle
              if (_deletingEvents.contains(eventDoc.id)) {
                return const SizedBox.shrink();
              }
              return _buildEventCard(eventDoc);
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
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                            ),
                          )
                        : Container(
                            color: AppColors.primaryLight,
                            child: const Icon(Icons.event_note, size: 50, color: AppColors.primary),
                          ),
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