import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../forum/gonderi_detay_ekrani.dart';
import '../auth/dogrulama_ekrani.dart'; 

import '../../widgets/animated_list_item.dart';
// Düzeltilmiş Importlar
import '../../utils/app_colors.dart';


class BildirimEkrani extends StatefulWidget {
  const BildirimEkrani({super.key});

  @override
  State<BildirimEkrani> createState() => _BildirimEkraniState();
}

class _BildirimEkraniState extends State<BildirimEkrani> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  late Stream<QuerySnapshot> _notificationsStream;

  @override
  void initState() {
    super.initState();
    // Stream'i bir kez başlat
    _notificationsStream = FirebaseFirestore.instance
        .collection('bildirimler')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  void handleNotificationTap(BuildContext context, Map<String, dynamic> data, String notificationId) async {
    final String type = data['type'] ?? '';
    await FirebaseFirestore.instance.collection('bildirimler').doc(notificationId).update({'isRead': true});
    if (!context.mounted) return;
    
    switch (type) {
      case 'new_comment':
      case 'like':
      case 'new_mention':
        final postId = data['postId'];
        if (postId != null) {
          final postDoc = await FirebaseFirestore.instance.collection('gonderiler').doc(postId).get();
          if (postDoc.exists && context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => GonderiDetayEkrani.fromDoc(postDoc)));
          }
        }
        break;
      case 'verification_approved':
      case 'verification_rejected':
        if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => const DogrulamaEkrani()));
        break;
      case 'new_follower':
        // Takip eden kişiye git
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bildirimler", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary, 
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: "Tümünü Okundu Say",
            onPressed: () {
               final batch = FirebaseFirestore.instance.batch();
               FirebaseFirestore.instance.collection('bildirimler').where('userId', isEqualTo: currentUserId).where('isRead', isEqualTo: false).get().then((snapshot) {
                for (var doc in snapshot.docs) {
                  batch.update(doc.reference, {'isRead': true});
                }
                batch.commit();
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationsStream, // OPTIMIZE EDİLDİ
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             if(!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(FontAwesomeIcons.bellSlash, size: 60, color: AppColors.greyMedium),
                  SizedBox(height: 20),
                  Text("Henüz bildirim yok", style: TextStyle(fontSize: 18, color: AppColors.greyText)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final notification = snapshot.data!.docs[index];
              final data = notification.data() as Map<String, dynamic>;
              final notificationId = notification.id;
              
              final Timestamp? t = data['timestamp'] as Timestamp?;
              final String time = t != null ? _formatTimestamp(t) : '';

              IconData notificationIcon;
              Color iconColor;
              String notificationTitle;
              final bool isUnread = data['isRead'] == false;

              switch (data['type']) {
                case 'new_comment':
                  notificationIcon = Icons.comment_rounded;
                  iconColor = Colors.blue;
                  notificationTitle = "${data['senderName']} yorum yaptı.";
                  break;
                case 'like':
                  notificationIcon = Icons.favorite_rounded;
                  iconColor = Colors.red;
                  final List<dynamic> senders = data['senders'] ?? [];
                  notificationTitle = senders.length > 1 ? "${senders.first['name']} ve ${senders.length - 1} kişi beğendi." : "${senders.first['name']} beğendi.";
                  break;
                case 'new_follower':
                  notificationIcon = Icons.person_add_rounded;
                  iconColor = Colors.purple;
                  notificationTitle = "Yeni bir takipçin var.";
                  break;
                case 'verification_approved':
                  notificationIcon = Icons.verified_user_rounded;
                  iconColor = Colors.green;
                  notificationTitle = "Hesabın doğrulandı!";
                  break;
                case 'verification_rejected':
                  notificationIcon = Icons.gpp_bad_rounded;
                  iconColor = Colors.orange;
                  notificationTitle = "Doğrulama reddedildi.";
                  break;
                default:
                  notificationIcon = Icons.notifications_rounded;
                  iconColor = Colors.grey;
                  notificationTitle = data['message'] ?? "Bildirim";
              }

              return AnimatedListItem(
                index: index,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUnread ? AppColors.primary.withOpacity(0.08) : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isUnread ? AppColors.primary.withOpacity(0.3) : Colors.transparent),
                    boxShadow: [
                      if (!isUnread) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
                    ]
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(notificationIcon, color: iconColor, size: 24),
                    ),
                    title: Text(notificationTitle, style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w500, fontSize: 15)),
                    subtitle: Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    trailing: isUnread ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)) : null,
                    onTap: () => handleNotificationTap(context, data, notificationId),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp t) {
    final now = DateTime.now();
    final date = t.toDate();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${date.day}.${date.month}';
  }
}