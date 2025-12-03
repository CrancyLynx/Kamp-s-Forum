import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; 
import 'package:image_picker/image_picker.dart'; 
import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:provider/provider.dart';
import '../../providers/blocked_users_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/typing_indicator.dart'; 

class SohbetDetayEkrani extends StatefulWidget {
  final String chatId;
  final String receiverId;
  final String receiverName;
  final String? receiverAvatarUrl;

  const SohbetDetayEkrani({
    super.key,
    required this.chatId,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatarUrl,
  });

  @override
  State<SohbetDetayEkrani> createState() => _SohbetDetayEkraniState();
}

class _SohbetDetayEkraniState extends State<SohbetDetayEkrani> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  Timer? _typingTimer;
  String? _myUserName;
  String? _myAvatarUrl;
  
  bool _isUploading = false;
  bool _isPickingImage = false;
  final ImagePicker _picker = ImagePicker();

  late Stream<DocumentSnapshot> _chatStream;
  late Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _chatStream = FirebaseFirestore.instance.collection('sohbetler').doc(widget.chatId).snapshots();
    
    _messagesStream = FirebaseFirestore.instance
        .collection('sohbetler')
        .doc(widget.chatId)
        .collection('mesajlar')
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true);

    _markMessagesAsRead();
    _messageController.addListener(_handleTyping);
    _fetchMyInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setTyping(false);
    _messageController.removeListener(_handleTyping);
    _typingTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markMessagesAsRead();
    }
  }

  Future<void> _fetchMyInfo() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId).get();
      if (mounted && doc.exists) {
        setState(() {
          _myUserName = doc.data()?['takmaAd'] ?? doc.data()?['ad'];
          _myAvatarUrl = doc.data()?['avatarUrl'];
        });
      }
    } catch (_) {}
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final docRef = FirebaseFirestore.instance.collection('sohbetler').doc(widget.chatId);
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        docRef.update({'unreadCount.$_currentUserId': 0});
        
        final messagesQuery = docRef.collection('mesajlar')
            .where('senderId', isEqualTo: widget.receiverId)
            .where('isRead', isEqualTo: false);
  
        final snapshot = await messagesQuery.get();
        if (snapshot.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (var doc in snapshot.docs) {
            batch.update(doc.reference, {'isRead': true});
          }
          await batch.commit();
        }
      }
    } catch (_) {
      // Hata olsa bile çökmesini engeller
    }
  }

  void _sendMessage({String? imageUrl, String messageType = 'text'}) async {
    final messageText = _messageController.text.trim();
    if (messageType == 'text' && messageText.isEmpty) return;
    if (messageType == 'image' && imageUrl == null) return;

    _messageController.clear();
    
    final content = messageType == 'text' ? messageText : (imageUrl ?? 'Resim Gönderildi');

    final messageData = {
      'senderId': _currentUserId,
      'content': content,
      'messageType': messageType,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    final chatDocRef = FirebaseFirestore.instance.collection('sohbetler').doc(widget.chatId);

    try {
      // 1. Chat Oda Dokümanını oluştur veya güncelle
      await chatDocRef.set({
        'participants': FieldValue.arrayUnion([_currentUserId, widget.receiverId]),
        'participantsInfo': {
          _currentUserId: {'name': _myUserName ?? 'Ben', 'avatarUrl': _myAvatarUrl},
          widget.receiverId: {'name': widget.receiverName, 'avatarUrl': widget.receiverAvatarUrl},
        },
        'typing': { _currentUserId: false } 
      }, SetOptions(merge: true));

      // 2. Mesajı alt koleksiyona ekle
      await chatDocRef.collection('mesajlar').add(messageData);

      // 3. Mesaj gönderildikten sonraki güncellemeleri yap
      await chatDocRef.update({
        'lastMessage': messageType == 'text' ? messageText : '🖼️ Resim',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': {
          widget.receiverId: FieldValue.increment(1),
        },
      });
      
    } on FirebaseException catch (e) {
      if (mounted) {
        // İzin hatası (perm hatası) veya diğer Firestore hatalarını göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Mesaj gönderme hatası: İzin reddedildi veya bağlantı sorunu. Code: ${e.code}"), backgroundColor: AppColors.error)
        );
      }
      debugPrint("Firestore Hata Kodu: ${e.code}, Mesaj: ${e.message}");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Genel mesaj gönderme hatası: $e"), backgroundColor: AppColors.error)
        );
      }
      debugPrint("Genel Mesaj Gönderme Hatası: $e");
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_isPickingImage) return;
    
    setState(() => _isPickingImage = true);

    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      
      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      final File imageFile = File(pickedFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final storageRef = FirebaseStorage.instance.ref().child('chat_images/${widget.chatId}/$_currentUserId-$timestamp.jpg');
      
      final uploadTask = storageRef.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      _sendMessage(imageUrl: downloadUrl, messageType: 'image');

    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Resim seçilemedi veya yüklenemedi.")));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isPickingImage = false;
        });
      }
    }
  }

  void _handleTyping() {
    _typingTimer?.cancel();
    _setTyping(true); 
    _typingTimer = Timer(const Duration(seconds: 2), () => _setTyping(false));
  }

  Future<void> _setTyping(bool isTyping) async {
    try {
      await FirebaseFirestore.instance.collection('sohbetler').doc(widget.chatId).set({
        'typing': { _currentUserId: isTyping }
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final blockedUsersProvider = Provider.of<BlockedUsersProvider>(context);
    if (blockedUsersProvider.isUserBlocked(widget.receiverId)) {
      return Scaffold(
        appBar: SimpleAppHeader(title: widget.receiverName),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block_flipped, size: 80, color: Colors.grey),
                const SizedBox(height: 20),
                Text(
                  "'${widget.receiverName}' kullanıcısını engellediniz.",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Bu kullanıcıyla mesajlaşmak için engelini kaldırmanız gerekir.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatBackgroundColor = isDark ? const Color(0xFF1E272C) : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SimpleAppHeader(title: widget.receiverName),
      body: Container( 
        color: chatBackgroundColor, 
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _chatStream,
                builder: (context, chatSnapshot) {
                  // YENİ DÜZELTME: Chat Stream Hatası Kontrolü (Beyaz Ekran Sorunu)
                  if (chatSnapshot.hasError) {
                    return Center(child: Text("Sohbet verisi yüklenirken hata oluştu: ${chatSnapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)));
                  }

                  bool isReceiverTyping = false;
                  if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                    final data = chatSnapshot.data!.data() as Map<String, dynamic>;
                    isReceiverTyping = (data['typing'] as Map?)?[widget.receiverId] == true;
                  }
  
                  return StreamBuilder<QuerySnapshot>(
                    stream: _messagesStream,
                    builder: (context, messageSnapshot) {
                      if (messageSnapshot.connectionState == ConnectionState.waiting) {
                        // Veri gelene kadar yükleniyor göster
                        if (!chatSnapshot.hasData) return const Center(child: CircularProgressIndicator()); 
                      }
                      
                      if (messageSnapshot.hasError) {
                         return Center(child: Text("Mesajlar yüklenirken hata oluştu: ${messageSnapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)));
                      }
  
                      final docs = messageSnapshot.data?.docs ?? [];
  
                      return ListView.builder(
                        reverse: true, 
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        itemCount: docs.length + (isReceiverTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          
                          if (isReceiverTyping && index == 0) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 38.0), 
                                child: TypingIndicator(isDark: isDark),
                              ),
                            );
                          }
  
                          final msgIndex = isReceiverTyping ? index - 1 : index;
                          final messageDoc = docs[msgIndex];
                          final messageData = messageDoc.data() as Map<String, dynamic>;
  
                          final bool isLastItem = msgIndex == docs.length - 1;
                          final bool showDateHeader = isLastItem || !_isSameDay(
                            messageData['timestamp'],
                            (docs[msgIndex + 1].data() as Map)['timestamp']
                          );
  
                          return Column(
                            children: [
                              if (showDateHeader) _buildDateHeader(messageData['timestamp']),
                              _buildMessageBubble(messageData, isDark, messageDoc.metadata.hasPendingWrites),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            _buildModernInputArea(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(Timestamp? timestamp) {
    if (timestamp == null) return const SizedBox.shrink();
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    
    String text;
    if (messageDate == today) {
      text = "Bugün";
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      text = "Dün";
    } else {
      text = DateFormat('d MMMM yyyy', 'tr').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  bool _isSameDay(Timestamp? t1, Timestamp? t2) {
    if (t1 == null || t2 == null) return false;
    final d1 = t1.toDate();
    final d2 = t2.toDate();
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isDark, bool isPending) {
    final bool isMe = message['senderId'] == _currentUserId;
    final String content = message['content'] ?? '';
    final String messageType = message['messageType'] ?? 'text';
    final Timestamp? timestamp = message['timestamp'] as Timestamp?;
    final bool isRead = message['isRead'] ?? false;
    
    final String timeStr = timestamp != null 
        ? DateFormat('HH:mm').format(timestamp.toDate()) 
        : '...';

    Widget messageContent;
    if (messageType == 'image') {
      messageContent = Container(
        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 250),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: content,
            placeholder: (context, url) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      messageContent = Text(
        content,
        style: TextStyle(
          color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
          fontSize: 15,
        ),
      );
    }

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: messageType == 'image' ? const EdgeInsets.all(4) : const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: isMe 
            ? AppColors.primary 
            : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(2),
          bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          messageContent,
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.grey,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                if (isPending) 
                  const Icon(Icons.access_time, size: 12, color: Colors.white70)
                else
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead ? Colors.lightBlueAccent : Colors.white70,
                  ),
              ]
            ],
          ),
        ],
      ),
    );

    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: bubble,
      );
    } 
    else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundImage: (widget.receiverAvatarUrl != null && widget.receiverAvatarUrl!.isNotEmpty)
                  ? CachedNetworkImageProvider(widget.receiverAvatarUrl!)
                  : null,
              backgroundColor: Colors.grey[300],
              child: (widget.receiverAvatarUrl == null || widget.receiverAvatarUrl!.isEmpty)
                  ? Text(widget.receiverName.isNotEmpty ? widget.receiverName[0] : '?', style: const TextStyle(fontSize: 12, color: Colors.black54))
                  : null,
            ),
            const SizedBox(width: 8),
            bubble,
          ],
        ),
      );
    }
  }

  Widget _buildModernInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 5)
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            GestureDetector(
              onTap: (_isUploading || _isPickingImage) ? null : _pickAndUploadImage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_isUploading || _isPickingImage) ? Colors.grey : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: _isUploading 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.attach_file_rounded, color: AppColors.primary, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.transparent : Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 5,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: "Mesaj yaz...",
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: (_isUploading || _isPickingImage) ? null : () => _sendMessage(messageType: 'text'),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _messageController.text.trim().isEmpty && !_isUploading ? Colors.grey : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}