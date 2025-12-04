import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import '../../providers/blocked_users_provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../utils/maskot_helper.dart';
import '../../utils/app_colors.dart';
import '../../utils/guest_security_helper.dart';
import '../../widgets/animated_list_item.dart';
import 'sohbet_detay_ekrani.dart';

class SohbetListesiEkrani extends StatefulWidget {
  const SohbetListesiEkrani({super.key});

  @override
  State<SohbetListesiEkrani> createState() => _SohbetListesiEkraniState();
}

class _SohbetListesiEkraniState extends State<SohbetListesiEkrani> {
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final GlobalKey _emptyStateKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  
  // PAGINATION: Başlangıç limiti (Daha fazla sohbet varsa otomatik artacak)
  int _limit = 20; 
  final int _limitIncrement = 20;
  
  late Stream<QuerySnapshot> _chatListStream;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('tr', timeago.TrMessages());
    
    // GUEST KONTROLÜ: Misafir kullanıcılar sohbet listesin göremez
    if (GuestSecurityHelper.isGuest()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GuestSecurityHelper.showGuestBlockedDialog(
          context,
          title: "Mesajlaşma Engellendi",
          message: "Mesajlaşmak için giriş yapmalısınız.",
        );
      });
      return; // Stream'i başlatma, hemen dön
    }
    
    _initStream();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        _loadMore();
      }
    });

    // Maskot Tanıtımı
    _chatListStream.first.then((snapshot) {
      if (snapshot.docs.isEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          MaskotHelper.checkAndShow(context, featureKey: 'sohbet_listesi_tutorial', targets: [
             TargetFocus(identify: "empty", keyTarget: _emptyStateKey, contents: [TargetContent(align: ContentAlign.bottom, builder: (c,_) => MaskotHelper.buildTutorialContent(c, title: 'Mesajlaş', description: 'Arkadaşlarınla mesajların burada görünür.', mascotAssetPath: 'assets/images/mutlu_bay.png'))])
          ]);
        });
      }
    });
  }

  void _initStream() {
    _chatListStream = FirebaseFirestore.instance
            .collection('sohbetler')
            .where('participants', arrayContains: _currentUserId)
            .orderBy('lastMessageTimestamp', descending: true)
            .limit(_limit) 
            .snapshots();
  }

  void _loadMore() {
    setState(() {
      _limit += _limitIncrement;
      _initStream(); 
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.message_rounded,
                color: Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Mesajlar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatListStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             if (_limit == 20) return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // Misafir kullanıcılar için özel mesaj
            if (GuestSecurityHelper.isGuest()) {
              return Center(
                key: _emptyStateKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 60, color: Colors.orange[400]),
                    const SizedBox(height: 16),
                    const Text("Mesajlaşma için giriş yapın", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => GuestSecurityHelper.requireLogin(context),
                      child: const Text("Giriş Yap"),
                    ),
                  ],
                ),
              );
            }
            
            return Center(
              key: _emptyStateKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("Henüz mesajın yok", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            );
          }

          // Engellenen kullanıcıları filtrele
          final blockedUsersProvider = Provider.of<BlockedUsersProvider>(context);
          final docs = snapshot.data!.docs.where((doc) {
             final data = doc.data() as Map<String, dynamic>;
             final List parts = data['participants'] ?? [];
             final otherId = parts.firstWhere((id) => id != _currentUserId, orElse: () => '');
             return !blockedUsersProvider.isUserBlocked(otherId);
          }).toList();

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final chatDoc = docs[index];
              final chatData = chatDoc.data() as Map<String, dynamic>;
              final parts = chatData['participants'] ?? [];
              final otherId = parts.firstWhere((id) => id != _currentUserId, orElse: () => '');
              final otherUserData = (chatData['participantsInfo'] as Map?)?[otherId] ?? {};
              
              final name = otherUserData['name'] ?? 'Kullanıcı';
              final avatar = otherUserData['avatarUrl'];
              final lastMsg = chatData['lastMessage'] ?? '';
              final time = chatData['lastMessageTimestamp'] as Timestamp?;
              final unread = (chatData['unreadCount'] as Map?)?[_currentUserId] ?? 0;
              final bool isTyping = (chatData['typing'] as Map?)?[otherId] == true;

              return AnimatedListItem(
                index: index,
                child: Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.1))),
                  color: Theme.of(context).cardColor,
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundImage: (avatar != null && avatar.isNotEmpty) ? CachedNetworkImageProvider(avatar) : null,
                          child: (avatar == null || avatar.isEmpty) ? Text(name.isNotEmpty ? name[0] : '?') : null,
                        ),
                        if (unread > 0)
                          Positioned(
                            right: 0, top: 0,
                            child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)))),
                          ),
                      ],
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: isTyping 
                        ? const Text("Yazıyor...", style: TextStyle(color: AppColors.primary, fontStyle: FontStyle.italic))
                        : Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(time != null ? timeago.format(time.toDate(), locale: 'tr') : '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        if (unread > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SohbetDetayEkrani(
                        chatId: chatDoc.id,
                        receiverId: otherId,
                        receiverName: name,
                        receiverAvatarUrl: avatar,
                      )));
                    },
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