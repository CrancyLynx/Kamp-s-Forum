import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';

class EtkinlikDetayEkrani extends StatefulWidget {
  final DocumentSnapshot eventDoc;

  const EtkinlikDetayEkrani({super.key, required this.eventDoc});

  @override
  State<EtkinlikDetayEkrani> createState() => _EtkinlikDetayEkraniState();
}

class _EtkinlikDetayEkraniState extends State<EtkinlikDetayEkrani> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isAttending = false;
  int _attendeeCount = 0;
  
  // Etkinlik güncellemelerini dinlemek için Stream
  late Stream<DocumentSnapshot> _eventStream;

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'tr_TR';
    _eventStream = widget.eventDoc.reference.snapshots();
  }

  // RSVP (Kayıt) işlemini yönetir
  void _toggleRsvp(List attendees, String? registrationLink) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu işlemi yapmak için giriş yapmalısınız."), backgroundColor: AppColors.warning));
      return;
    }
    
    final isAlreadyAttending = attendees.contains(_currentUserId);
    
    // Eğer kayıt linki varsa ve kullanıcı daha önce RSVP yapmadıysa, linke yönlendir
    if (registrationLink != null && registrationLink.isNotEmpty && !isAlreadyAttending) {
       await _launchRegistrationLink(registrationLink);
       // Kullanıcı linke gittikten sonra otomatik RSVP yapıyoruz (isteğe bağlı bir tasarım kararı)
    }


    final eventRef = widget.eventDoc.reference;
    final bool newStatus = !isAlreadyAttending; // isAlreadyAttending yerine newStatus kullan

    // Optimistik Güncelleme
    setState(() {
      _isAttending = newStatus;
      _attendeeCount += newStatus ? 1 : -1;
    });

    try {
      if (newStatus) {
        await eventRef.update({
          'attendees': FieldValue.arrayUnion([_currentUserId]),
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Etkinliğe katılıyorsunuz!"), backgroundColor: AppColors.success));
      } else {
        await eventRef.update({
          'attendees': FieldValue.arrayRemove([_currentUserId]),
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Katılımınız iptal edildi."), backgroundColor: AppColors.error));
      }
    } catch (e) {
      // Hata durumunda state'i geri al
      if (mounted) {
        setState(() {
          _isAttending = !newStatus;
          _attendeeCount -= newStatus ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata oluştu: $e"), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _launchRegistrationLink(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt linki açılamadı: $urlString')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _eventStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(appBar: AppBar(title: const Text("Etkinlik Silinmiş")), body: const Center(child: Text("Bu etkinlik artık mevcut değil.")));
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final List attendees = data['attendees'] ?? [];
        final String title = data['title'] ?? 'Etkinlik';
        final String location = data['location'] ?? 'Kampüs Alanı';
        final String? description = data['description'];
        final String? imageUrl = data['imageUrl'];
        final String? registrationLink = data['registrationLink'];
        final DateTime eventDate = (data['date'] as Timestamp).toDate();
        
        // Gerçek zamanlı güncellemeler için state'i güncel tut
        _attendeeCount = attendees.length;
        _isAttending = _currentUserId != null && attendees.contains(_currentUserId);
        
        // Etkinlik sona ermiş mi?
        final bool isPastEvent = eventDate.isBefore(DateTime.now());

        return Scaffold(
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 250,
                    pinned: true,
                    backgroundColor: AppColors.primary,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      centerTitle: true,
                      background: (imageUrl != null && imageUrl.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: Colors.grey[300]),
                              errorWidget: (context, url, error) => Container(color: AppColors.primaryLight, child: const Icon(Icons.event, size: 50, color: AppColors.primaryDark)),
                            )
                          : Container(color: AppColors.primaryDarker),
                    ),
                  ),
                  
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tarih, Konum ve Katılımcı Bilgileri
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildInfoColumn(Icons.calendar_today, AppColors.info, DateFormat('dd MMMM', 'tr_TR').format(eventDate), DateFormat('EEEE', 'tr_TR').format(eventDate)),
                                  _buildInfoColumn(Icons.access_time, AppColors.info, DateFormat('HH:mm', 'tr_TR').format(eventDate), "Saat"),
                                  _buildInfoColumn(Icons.people_alt, AppColors.success, _attendeeCount.toString(), "Katılımcı"),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Konum
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  location, 
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 30),

                          // Açıklama
                          const Text("Açıklama", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          const SizedBox(height: 10),
                          Text(
                            description ?? "Etkinlik için detaylı bir açıklama bulunmamaktadır.", 
                            style: TextStyle(fontSize: 16, height: 1.5, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8)),
                          ),
                          
                          const SizedBox(height: 100), 
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // FAB / BottomSheet
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isPastEvent ? null : () => _toggleRsvp(attendees, registrationLink),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPastEvent ? Colors.grey : (_isAttending ? AppColors.error : AppColors.success),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(isPastEvent ? Icons.event_busy : (_isAttending ? Icons.cancel_outlined : Icons.check_circle_outline)),
                          label: Text(
                            isPastEvent ? "Etkinlik Sona Erdi" 
                            : (registrationLink != null && registrationLink.isNotEmpty && !_isAttending) 
                                ? "Kayıt Ol (RSVP ve Link)" 
                                : (_isAttending ? "Katılımı İptal Et" : "Katılıyorum (RSVP)")
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildInfoColumn(IconData icon, Color color, String bigText, String smallText) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(bigText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(smallText, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}