import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Tarih formatı için
import '../../utils/app_colors.dart';

class BildirimEkrani extends StatefulWidget {
  const BildirimEkrani({super.key});

  @override
  State<BildirimEkrani> createState() => _BildirimEkraniState();
}

class _BildirimEkraniState extends State<BildirimEkrani> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    // Ekran açıldığında eski bildirimleri temizle
    _cleanupOldNotifications();
  }

  /// 7 günden eski ve OKUNMUŞ bildirimleri otomatik siler
  Future<void> _cleanupOldNotifications() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshot = await FirebaseFirestore.instance
          .collection('bildirimler')
          .where('userId', isEqualTo: _currentUserId)
          .where('isRead', isEqualTo: true)
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint("${snapshot.docs.length} eski bildirim temizlendi.");
      }
    } catch (e) {
      debugPrint("Otomatik temizlik hatası: $e");
    }
  }

  /// Tekil bildirim silme fonksiyonu
  Future<void> _deleteNotification(String docId) async {
    await FirebaseFirestore.instance.collection('bildirimler').doc(docId).delete();
  }

  /// Tümünü okundu işaretle
  Future<void> _markAllAsRead() async {
    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance
        .collection('bildirimler')
        .where('userId', isEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Bildirime tıklandığında detayına gitme veya okundu yapma
  void _handleNotificationTap(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Okunmadıysa okundu yap
    if (data['isRead'] == false) {
      doc.reference.update({'isRead': true});
    }

    // Bildirim tipine göre yönlendirme yapılabilir
    // Örneğin: if (data['type'] == 'follow') ...
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bildirimler"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: "Tümünü Okundu Say",
            onPressed: _markAllAsRead,
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bildirimler')
            .where('userId', isEqualTo: _currentUserId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _buildNotificationItem(doc, context);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(DocumentSnapshot doc, BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final bool isRead = data['isRead'] ?? false;
    final String message = data['message'] ?? 'Bildirim';
    final String senderName = data['senderName'] ?? 'Sistem';
    final Timestamp? timestamp = data['timestamp'];
    final String timeAgo = timestamp != null ? _formatTimestamp(timestamp) : '';

    // Kaydırarak Silme Widget'ı
    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart, // Sadece sağdan sola kaydırma
      onDismissed: (direction) {
        _deleteNotification(doc.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bildirim silindi"), duration: Duration(seconds: 1)),
        );
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
      ),
      child: Card(
        elevation: isRead ? 0 : 2,
        color: isRead ? Colors.grey[50] : Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isRead ? BorderSide.none : BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1),
        ),
        child: InkWell(
          onTap: () => _handleNotificationTap(doc),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // İkon veya Avatar
                _buildNotificationIcon(data['type']),
                const SizedBox(width: 15),
                // İçerik
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.black87, fontSize: 14, fontFamily: 'Segoe UI'), // Font ailesini projenize göre ayarlayın
                          children: [
                            TextSpan(
                              text: "$senderName ",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: message.replaceAll(senderName, '')), // Mesajda isim tekrar ederse temizle
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeAgo,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Okunmadı İşareti
                if (!isRead)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 5),
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String? type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'like':
        icon = Icons.favorite;
        color = Colors.redAccent;
        break;
      case 'comment':
        icon = Icons.comment;
        color = Colors.blueAccent;
        break;
      case 'follow': // 'new_follower' olabilir, veritabanına göre ayarla
      case 'new_follower':
        icon = Icons.person_add;
        color = Colors.green;
        break;
      default:
        icon = Icons.notifications;
        color = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "Hiç bildiriminiz yok.",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return "Şimdi";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes}dk önce";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}sa önce";
    } else if (diff.inDays < 7) {
      return "${diff.inDays}g önce";
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}