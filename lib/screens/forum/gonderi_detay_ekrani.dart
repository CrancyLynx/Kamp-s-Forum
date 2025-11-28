import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart'; 
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart'; // Resim seçici
import 'package:firebase_storage/firebase_storage.dart'; // Storage
import 'dart:io';
// Düzeltilmiş Importlar
import '../../utils/app_colors.dart';
import '../profile/kullanici_profil_detay_ekrani.dart';
 
import 'gonderi_duzenleme_ekrani.dart';
import '../../widgets/animated_list_item.dart';

class GonderiDetayEkrani extends StatefulWidget {
  final String postId;
  final String adSoyad;
  final String authorUserId;
  final String baslik;
  final String mesaj;
  final dynamic zaman; 
  final String kategori;
  final bool isAdmin;
  final String userName; 
  final String? avatarUrl;
  final List<dynamic> imageUrls;

  const GonderiDetayEkrani({
    super.key,
    required this.postId,
    required this.adSoyad,
    required this.authorUserId,
    required this.baslik,
    required this.mesaj,
    required this.zaman,
    required this.kategori,
    required this.userName,
    this.isAdmin = false,
    this.avatarUrl,
    this.imageUrls = const [],
  });

  factory GonderiDetayEkrani.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final currentUser = FirebaseAuth.instance.currentUser;
    const List<String> admins = ["oZ2RIhV1JdYVIr0xyqCwhX9fJYq1", "VD8MeJIhhRVtbT9iiUdMEaCe3MO2"];
    final bool isAdministrator = admins.contains(currentUser?.uid);

    return GonderiDetayEkrani(
      postId: doc.id,
      adSoyad: data['ad'] ?? 'Bilinmiyor',
      authorUserId: data['userId'] ?? '',
      baslik: data['baslik'] ?? 'Başlıksız',
      mesaj: data['mesaj'] ?? '',
      zaman: data['zaman'], 
      kategori: data['kategori'] ?? 'Genel',
      userName: currentUser?.displayName ?? data['takmaAd'] ?? 'Kullanıcı',
      isAdmin: isAdministrator,
      avatarUrl: data['avatarUrl'] as String?,
      imageUrls: data['imageUrls'] ?? [],
    );
  }

  @override
  State<GonderiDetayEkrani> createState() => _GonderiDetayEkraniState();
}

class _GonderiDetayEkraniState extends State<GonderiDetayEkrani> with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String? _replyingToUserName;
  String? _replyingToCommentId;
  bool _isPosting = false;
  
  bool _isLiked = false;
  int _likeCount = 0;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnim;

  File? _commentImage;
  final ImagePicker _picker = ImagePicker();

  // --- PERFORMANS DÜZELTMESİ: STREAM'LERİ HAFIZAYA AL ---
  late Stream<DocumentSnapshot> _postStream;
  late Stream<QuerySnapshot> _commentsStream;

  @override
  void initState() {
    super.initState();
    
    // 1. Stream'leri burada bir kez başlatıyoruz. 
    // Böylece klavye açılınca veya scroll yapınca yeniden yüklenmiyor.
    _postStream = FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId).snapshots();
    
    _commentsStream = FirebaseFirestore.instance
          .collection('gonderiler')
          .doc(widget.postId)
          .collection('yorumlar')
          .orderBy('timestamp', descending: false)
          .snapshots();

    _likeAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _likeScaleAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    _likeAnimController.dispose();
    super.dispose();
  }

  // ... (Geri kalan fonksiyonlar aynı: _handleLike, _postComment, _deletePost vb.) ...
  // Kodun geri kalan mantığı değişmediği için sadece değiştirilmesi gereken widget yapısını veriyorum.
  // Bu dosyanın tamamını kopyalayıp yapıştırabilirsin, fonksiyonları aşağıya ekledim.

  void _handleLike(List<dynamic> currentLikes) {
    if (_currentUserId.isEmpty) return;
    final postRef = FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId);
    final userRef = FirebaseFirestore.instance.collection('kullanicilar').doc(widget.authorUserId);

    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likeCount--;
        postRef.update({'likes': FieldValue.arrayRemove([_currentUserId])});
        userRef.update({'likeCount': FieldValue.increment(-1)});
      } else {
        _isLiked = true;
        _likeCount++;
        _likeAnimController.forward().then((_) => _likeAnimController.reverse());
        postRef.update({'likes': FieldValue.arrayUnion([_currentUserId])});
        userRef.update({'likeCount': FieldValue.increment(1)});
        _sendLikeNotification();
      }
    });
  }

  Future<void> _sendLikeNotification() async {
    if (_currentUserId == widget.authorUserId) return;
    await FirebaseFirestore.instance.collection('bildirimler').add({
      'userId': widget.authorUserId,
      'postId': widget.postId,
      'postTitle': widget.baslik,
      'type': 'like',
      'senders': [{'id': _currentUserId, 'name': widget.userName}],
      'message': '${widget.userName} gönderini beğendi.',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _pickCommentImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _commentImage = File(pickedFile.path);
      });
    }
  }

  void _removeCommentImage() {
    setState(() {
      _commentImage = null;
    });
  }

  Future<void> _postComment() async {
    if ((_commentController.text.trim().isEmpty && _commentImage == null) || _isPosting) return;
    
    setState(() => _isPosting = true);

    final content = _commentController.text.trim();
    final replyToId = _replyingToCommentId;
    final replyToName = _replyingToUserName;
    String? imageUrl;

    try {
      if (_commentImage != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final ref = FirebaseStorage.instance.ref().child('yorum_resimleri/$_currentUserId-$timestamp.jpg');
        final uploadTask = ref.putFile(_commentImage!, SettableMetadata(contentType: 'image/jpeg'));
        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      _commentController.clear();
      setState(() {
        _replyingToUserName = null;
        _replyingToCommentId = null;
        _commentImage = null;
      });
      FocusScope.of(context).unfocus();

      final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId).get();
      final myAvatar = userDoc.data()?['avatarUrl'];
      final myName = userDoc.data()?['takmaAd'] ?? userDoc.data()?['ad'] ?? 'Kullanıcı';

      await FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId).collection('yorumlar').add({
        'postId': widget.postId,
        'userId': _currentUserId,
        'userName': myName,
        'userAvatar': myAvatar,
        'content': content,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'replyToCommentId': replyToId,
        'replyToUserName': replyToName,
      });

      await FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId).update({
        'commentCount': FieldValue.increment(1),
        'lastCommentTimestamp': FieldValue.serverTimestamp(),
        if (myAvatar != null) 'recentCommenterAvatars': FieldValue.arrayUnion([myAvatar]),
      });

      await FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId).update({
        'commentCount': FieldValue.increment(1),
      });

      if (_currentUserId != widget.authorUserId) {
        await FirebaseFirestore.instance.collection('bildirimler').add({
          'userId': widget.authorUserId,
          'senderName': myName,
          'type': 'new_comment',
          'postId': widget.postId,
          'message': '$myName gönderine yorum yaptı.',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata oluştu.")));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Silmek istediğine emin misin?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("SİL", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('deletePost');
      await callable.call({'postId': widget.postId});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gönderi silindi."), backgroundColor: Colors.red));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    String timeStr = '';
    if (widget.zaman is Timestamp) {
      timeStr = timeago.format((widget.zaman as Timestamp).toDate(), locale: 'tr');
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<DocumentSnapshot>(
        // DÜZELTME: Artık initState'de oluşturduğumuz _postStream'i kullanıyoruz.
        stream: _postStream, 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             // Eğer ilk kez açılıyorsa (veri yoksa) yükleniyor göster
             // Ancak veri varsa (klavye açılıp kapanınca), eski veriyi göstermeye devam et
             if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text("Bu gönderi silinmiş."));

          final postData = snapshot.data!.data() as Map<String, dynamic>;
          final List likes = postData['likes'] ?? [];
          final List postImages = postData['imageUrls'] ?? widget.imageUrls;
          
          if (!_isPosting) {
             _likeCount = likes.length;
             _isLiked = likes.contains(_currentUserId);
          }

          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 0,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    elevation: 0,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Theme.of(context).cardColor, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_back_ios_new, size: 18),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(
                      "Gönderi Detayı", 
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)
                    ),
                    centerTitle: true,
                    actions: [
                      _buildMoreButton(widget.authorUserId == _currentUserId),
                    ],
                  ),

                  // GÖNDERİ İÇERİĞİ
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KullaniciProfilDetayEkrani(userId: widget.authorUserId, userName: widget.adSoyad))),
                            child: Row(
                              children: [
                                Hero(
                                  tag: 'avatar_${widget.postId}',
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundImage: (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty) 
                                        ? CachedNetworkImageProvider(widget.avatarUrl!) 
                                        : null,
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
                                        ? Text(widget.adSoyad[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.adSoyad, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text("$timeStr • ${widget.kategori}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          Text(widget.baslik, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                          const SizedBox(height: 12),
                          Text(widget.mesaj, style: TextStyle(fontSize: 16, height: 1.6, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.9))),
                          
                          // GÖNDERİ RESİMLERİ (Varsa Göster)
                          if (postImages.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 250,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: postImages.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: CachedNetworkImage(
                                        imageUrl: postImages[index],
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
                                        errorWidget: (context, url, error) => const Icon(Icons.error),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => _handleLike(likes),
                                  child: Row(
                                    children: [
                                      ScaleTransition(
                                        scale: _likeScaleAnim,
                                        child: Icon(
                                          _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                          color: _isLiked ? Colors.red : Colors.grey,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text("$_likeCount", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _isLiked ? Colors.red : Colors.grey[700])),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.mode_comment_outlined, color: Colors.grey, size: 24),
                                    const SizedBox(width: 8),
                                    Text("${postData['commentCount'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text("Yorumlar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  _buildCommentsList(),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 150)), 
                ],
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: _buildModernInputArea(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      // DÜZELTME: Artık initState'de oluşturduğumuz _commentsStream'i kullanıyoruz.
      stream: _commentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (!snapshot.hasData) return SliverToBoxAdapter(child: _buildShimmerLoading());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text("Henüz yorum yok. Sessizliği boz!", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final doc = snapshot.data!.docs[index];
              final cData = doc.data() as Map<String, dynamic>;
              return AnimatedListItem(
                index: index,
                child: _buildCommentItem(doc.id, cData),
              );
            },
            childCount: snapshot.data!.docs.length,
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(String commentId, Map<String, dynamic> data) {
    final bool isMyComment = data['userId'] == _currentUserId;
    final bool isAdminComment = data['userId'] == widget.authorUserId;
    
    String timeStr = '';
    if (data['timestamp'] != null) {
      timeStr = timeago.format((data['timestamp'] as Timestamp).toDate(), locale: 'tr');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
               if(data['userId'] != null) {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => KullaniciProfilDetayEkrani(userId: data['userId'], userName: data['userName'])));
               }
            },
            child: CircleAvatar(
              radius: 18,
              backgroundImage: (data['userAvatar'] != null) ? CachedNetworkImageProvider(data['userAvatar']) : null,
              backgroundColor: Colors.grey[200],
              child: (data['userAvatar'] == null) ? Text(data['userName']?[0] ?? '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(data['userName'] ?? 'Anonim', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    if (isAdminComment)
                      Padding(padding: const EdgeInsets.only(left: 4.0), child: Icon(Icons.verified, size: 14, color: AppColors.primary)),
                    const SizedBox(width: 6),
                    Text(timeStr, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
                
                if (data['replyToUserName'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text("@${data['replyToUserName']}", style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                
                const SizedBox(height: 2),
                if (data['content'] != null && data['content'].isNotEmpty)
                  Text(data['content'], style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8), fontSize: 14, height: 1.3)),
                
                // YORUM RESMİ (Varsa)
                if (data['imageUrl'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: data['imageUrl'],
                        width: 150,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(height: 100, width: 150, color: Colors.grey[200]),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _replyingToUserName = data['userName'];
                            _replyingToCommentId = commentId;
                          });
                          _commentFocusNode.requestFocus();
                        },
                        child: Text("Yanıtla", style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      if (widget.isAdmin || isMyComment) ...[
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _deleteComment(commentId, data['userId']),
                          child: Text("Sil", style: TextStyle(color: Colors.red[300], fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ]
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _deleteComment(String commentId, String? userId) async {
    final ref = FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId);
    await ref.collection('yorumlar').doc(commentId).delete();
    await ref.update({'commentCount': FieldValue.increment(-1)});
    if(userId != null) {
      FirebaseFirestore.instance.collection('kullanicilar').doc(userId).update({'commentCount': FieldValue.increment(-1)});
    }
  }

  Widget _buildModernInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor, 
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 16),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Yanıtlanıyor Barı
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _replyingToUserName != null
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: AppColors.primary.withOpacity(0.08),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Yanıtlanıyor: @$_replyingToUserName", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                          GestureDetector(
                            onTap: () => setState(() { _replyingToUserName = null; _replyingToCommentId = null; }),
                            child: const Icon(Icons.close, size: 16, color: AppColors.primary),
                          )
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Seçilen Resim Önizlemesi
            if (_commentImage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_commentImage!, height: 80, width: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 0, right: 0,
                      child: GestureDetector(
                        onTap: _removeCommentImage,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            
            // Input Alanı
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Resim Seçme Butonu
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                    child: GestureDetector(
                      onTap: _pickCommentImage,
                      child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.grey, size: 28),
                    ),
                  ),
                  
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        maxLines: 4,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: "Yorumunu yaz...",
                          hintStyle: TextStyle(fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: GestureDetector(
                      onTap: _isPosting ? null : _postComment,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: _isPosting ? Colors.grey[300] : AppColors.primary,
                        child: _isPosting 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreButton(bool isAuthor) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (val) {
        if (val == 'delete') _deletePost();
        if (val == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => GonderiDuzenlemeEkrani(postId: widget.postId, initialTitle: widget.baslik, initialMessage: widget.mesaj)));
      },
      itemBuilder: (ctx) => [
        if (isAuthor || widget.isAdmin) ...[
          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Düzenle")])),
          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Sil", style: TextStyle(color: Colors.red))])),
        ] else
          const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag, size: 18), SizedBox(width: 8), Text("Şikayet Et")])),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(children: List.generate(3, (index) => Container(margin: const EdgeInsets.all(16), height: 20, color: Colors.white))),
    );
  }
}