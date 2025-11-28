import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'sohbet_detay_ekrani.dart';
import 'app_colors.dart';
import 'widgets/animated_list_item.dart';

class SohbetListesiEkrani extends StatefulWidget {
  const SohbetListesiEkrani({super.key});

  @override
  State<SohbetListesiEkrani> createState() => _SohbetListesiEkraniState();
}

class _SohbetListesiEkraniState extends State<SohbetListesiEkrani> {
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  // PERFORMANS: Stream'i sakla
  late Stream<QuerySnapshot> _chatListStream;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('tr', timeago.TrMessages());
    
    // 1. Stream'i bir kere tanımla
    _chatListStream = FirebaseFirestore.instance
            .collection('sohbetler')
            .where('participants', arrayContains: _currentUserId)
            .orderBy('lastMessageTimestamp', descending: true)
            .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Mesajlar", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatListStream, // OPTIMIZE EDİLDİ
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded, size: 50, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Henüz mesajın yok",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text("Arkadaşlarının profiline gidip mesaj atabilirsin.", style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final chatDoc = snapshot.data!.docs[index];
              final chatData = chatDoc.data() as Map<String, dynamic>;
              
              final List<dynamic> participants = chatData['participants'] ?? [];
              final String otherUserId = participants.firstWhere((id) => id != _currentUserId, orElse: () => '');
              final Map<String, dynamic> participantsInfo = chatData['participantsInfo'] ?? {};
              final Map<String, dynamic> otherUserData = participantsInfo[otherUserId] ?? {};
              
              final String userName = otherUserData['name'] ?? 'Kullanıcı';
              final String? avatarUrl = otherUserData['avatarUrl'];
              final String lastMessage = chatData['lastMessage'] ?? 'Resim gönderildi';
              final Timestamp? lastTime = chatData['lastMessageTimestamp'] as Timestamp?;
              
              final Map<String, dynamic> unreadCountMap = chatData['unreadCount'] ?? {};
              final int myUnreadMessages = unreadCountMap[_currentUserId] ?? 0;
              final bool isTyping = (chatData['typing'] as Map?)?[otherUserId] == true;

              return AnimatedListItem(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  child: Card(
                    elevation: 0,
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Stack(
                        children: [
                          Hero(
                            tag: 'avatar_$otherUserId',
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? CachedNetworkImageProvider(avatarUrl) : null,
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 20))
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        userName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: isTyping 
                          ? const Text("Yazıyor...", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))
                          : Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: myUnreadMessages > 0 ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                                fontWeight: myUnreadMessages > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            lastTime != null ? timeago.format(lastTime.toDate(), locale: 'tr') : '',
                            style: TextStyle(fontSize: 11, color: myUnreadMessages > 0 ? AppColors.primary : Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          if (myUnreadMessages > 0)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: Text(
                                myUnreadMessages.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => SohbetDetayEkrani(
                          chatId: chatDoc.id,
                          receiverId: otherUserId,
                          receiverName: userName,
                          receiverAvatarUrl: avatarUrl,
                        )));
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}