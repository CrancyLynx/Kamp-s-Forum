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
  // En yeni etkinlikleri en üstte göster
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
  
  // Katılımcı Listesini Gösteren Fonksiyon
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
          userIds: attendees.cast<String>(), // Katılımcı ID'leri string olmalı
          hideAppBar: false, // Yeni sayfada AppBar göster
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold, AdminPanelEkrani'nda sekme içinde kullanılmak üzere ayarlandı.
    return Scaffold(
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

          return ListView(
            padding: const EdgeInsets.all(10.0),
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
              final DateTime eventDate = (data['date'] as Timestamp).toDate();
              final List<dynamic> attendees = data['attendees'] ?? []; 

              return _buildEventCard(document, eventDate, attendees);
            }).toList(),
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

  Widget _buildEventCard(DocumentSnapshot eventDoc, DateTime eventDate, List<dynamic> attendees) {
    final data = eventDoc.data() as Map<String, dynamic>;
    final String title = data['title'] ?? 'Başlıksız Etkinlik';
    final String location = data['location'] ?? 'Konum Belirtilmemiş';
    final String? imageUrl = data['imageUrl'];
    final bool isPast = eventDate.isBefore(DateTime.now());

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isPast ? Colors.grey[100] : Theme.of(context).cardColor,
      child: InkWell(
        onTap: () {
          // Etkinlik Detay Ekranına Yönlendirme
          Navigator.push(context, MaterialPageRoute(builder: (_) => EtkinlikDetayEkrani(eventDoc: eventDoc)));
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(width: 60, height: 60, color: Colors.grey[300], child: const Icon(Icons.event, color: Colors.grey)),
                          errorWidget: (context, url, error) => Container(width: 60, height: 60, color: AppColors.primaryLight, child: const Icon(Icons.event_note, color: AppColors.primary)),
                        )
                      : Container(width: 60, height: 60, color: AppColors.primaryLight, child: const Icon(Icons.event_note, color: AppColors.primary)),
                ),
                title: Text(
                  title, 
                  style: TextStyle(fontWeight: FontWeight.bold, color: isPast ? Colors.grey[600] : AppColors.black87)
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd MMMM yyyy - HH:mm', 'tr_TR').format(eventDate),
                      style: TextStyle(color: isPast ? Colors.grey : AppColors.primary, fontSize: 13, fontWeight: isPast ? FontWeight.normal : FontWeight.w600),
                    ),
                    Text(
                      location,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    if (isPast) 
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text("Sona Erdi", style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              
              // YENİ: Katılımcı Bilgileri ve Aksiyonlar
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Katılımcı Sayısı Butonu
                    TextButton.icon(
                      onPressed: () => _showAttendees(title, attendees),
                      icon: const Icon(Icons.people_alt, color: AppColors.success),
                      label: Text(
                        "${attendees.length} Katılımcı", 
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)
                      ),
                    ),
                    // Düzenle/Sil Butonları
                    Row(
                      mainAxisSize: MainAxisSize.min,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}