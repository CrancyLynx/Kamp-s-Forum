import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../../providers/blocked_users_provider.dart';
import '../../utils/app_colors.dart';
import '../../models/badge_model.dart';
import '../badge_widget.dart';
import '../../screens/forum/gonderi_detay_ekrani.dart';
import '../../screens/profile/kullanici_profil_detay_ekrani.dart';
import '../../services/cloud_functions_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class GonderiKarti extends StatefulWidget {
  final String postId;
  final String adSoyad;
  final String? realUsername;
  final String baslik;
  final String mesaj;
  final String zaman;
  final String kategori;
  final bool isAuthorAdmin;
  final String authorUserId;
  final String? avatarUrl;
  final bool isGuest;
  final bool isAdmin;
  final VoidCallback onShowLoginRequired;
  final String currentUserTakmaAd;
  final String currentUserRealName;
  final bool isSaved;
  final List<dynamic> likes;
  final int commentCount;
  final List<String> authorBadges;
  final bool isPinned;
  final List<String> imageUrls;

  const GonderiKarti({
    super.key,
    required this.postId,
    required this.adSoyad,
    this.realUsername,
    required this.baslik,
    required this.mesaj,
    required this.zaman,
    required this.kategori,
    required this.authorUserId,
    this.isAuthorAdmin = false,
    this.avatarUrl,
    required this.isGuest,
    this.isAdmin = false,
    required this.onShowLoginRequired,
    required this.currentUserTakmaAd,
    required this.currentUserRealName,
    required this.isSaved,
    required this.likes,
    required this.commentCount,
    required this.authorBadges,
    this.isPinned = false,
    this.imageUrls = const [],
  });

  @override
  State<GonderiKarti> createState() => _GonderiKartiState();
}

class _GonderiKartiState extends State<GonderiKarti> with SingleTickerProviderStateMixin {
  late bool _isLikedByCurrentUser;
  late AnimationController _likeController;
  late Animation<double> _likeScale;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _isLikedByCurrentUser = currentUserId != null && widget.likes.contains(currentUserId);

    _likeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _likeScale = Tween<double>(begin: 1.0, end: 1.4).animate(CurvedAnimation(parent: _likeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Future<void> _sendLikeNotification(String senderId, String senderName, String receiverId, String postId, String postTitle) async {
    if (senderId == receiverId || !mounted) return;

    final senderDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(senderId).get();
    final senderData = senderDoc.data() ?? {};
    final senderAvatarUrl = senderData['profilFotografi'] ?? '';
    final senderUniversity = senderData['universite'] ?? '';

    final notificationQuery = await FirebaseFirestore.instance
        .collection('bildirimler')
        .where('postId', isEqualTo: postId)
        .where('type', isEqualTo: 'like')
        .where('userId', isEqualTo: receiverId)
        .limit(1)
        .get();

    if (notificationQuery.docs.isNotEmpty) {
      final docId = notificationQuery.docs.first.id;
      await FirebaseFirestore.instance.collection('bildirimler').doc(docId).update({
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatarUrl': senderAvatarUrl,
        'senderUniversity': senderUniversity,
        'message': '$senderName ve diğerleri gönderini beğendi.',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance.collection('bildirimler').add({
        'userId': receiverId,
        'postId': postId,
        'postTitle': postTitle,
        'type': 'like',
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatarUrl': senderAvatarUrl,
        'senderUniversity': senderUniversity,
        'message': '$senderName gönderini beğendi.',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _toggleLike() async {
    if (widget.isGuest) {
      widget.onShowLoginRequired();
      return;
    }
    if (_isLiking) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() {
      _isLiking = true;
      _isLikedByCurrentUser = !_isLikedByCurrentUser;
      if (_isLikedByCurrentUser) {
        _likeController.forward().then((_) => _likeController.reverse());
      }
    });

    final postRef = FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId);
    final authorRef = FirebaseFirestore.instance.collection('kullanicilar').doc(widget.authorUserId);

    try {
      if (_isLikedByCurrentUser) {
        await Future.wait([
          postRef.update({'likes': FieldValue.arrayUnion([currentUserId])}),
          authorRef.update({'likeCount': FieldValue.increment(1)}),
        ]);
        await _sendLikeNotification(currentUserId, widget.currentUserTakmaAd, widget.authorUserId, widget.postId, widget.baslik);
        _checkAndAwardLikeBadges(authorRef);
      } else {
        await Future.wait([
          postRef.update({'likes': FieldValue.arrayRemove([currentUserId])}),
          authorRef.update({'likeCount': FieldValue.increment(-1)}),
        ]);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLikedByCurrentUser = !_isLikedByCurrentUser;
        });
        _showErrorDialog("İşlem başarısız oldu. Lütfen tekrar deneyin.");
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.red.shade50,
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/uzgun_bay.png',
                width: 100,
                height: 100,
                errorBuilder: (c, e, s) => Icon(
                  Icons.error_outline_rounded,
                  size: 80,
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Hata ⚠️",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Anlaşıldı",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSave(String? currentUserId, bool isSaved) {
    if (widget.isGuest || currentUserId == null) {
      widget.onShowLoginRequired();
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('kullanicilar').doc(currentUserId);

    if (isSaved) {
      userRef.update({'savedPosts': FieldValue.arrayRemove([widget.postId])});
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kaydedilenlerden kaldırıldı."), backgroundColor: AppColors.info));
    } else {
      userRef.update({'savedPosts': FieldValue.arrayUnion([widget.postId])});
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gönderi kaydedildi!"), backgroundColor: AppColors.success));
    }
  }

  void _showReportDialog() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (widget.isGuest || currentUserId == null) {
      widget.onShowLoginRequired();
      return;
    }

    final descriptionController = TextEditingController();
    String selectedReason = 'spam';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gönderiyi Bildir'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Neden bildiriyorsunuz?', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setState) => DropdownButton<String>(
                  value: selectedReason,
                  isExpanded: true,
                  items: ['spam', 'inappropriate', 'harassment', 'misinformation', 'copyright', 'other']
                      .map((reason) => DropdownMenuItem(
                            value: reason,
                            child: Text(reason),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => selectedReason = value ?? 'spam');
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('Açıklama (isteğe bağlı)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Neler yanlış olduğunu açıklayın...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance.collection('reports').add({
                  'reportedUserId': widget.authorUserId,
                  'reportType': 'post',
                  'reportedItemId': widget.postId,
                  'reason': selectedReason,
                  'description': descriptionController.text,
                  'reporterUserId': currentUserId,
                  'status': 'pending',
                  'createdAt': Timestamp.now(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gönderi bildirildi. Teşekkürler!'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showErrorDialog('Bildir gönderirken hata oluştu');
                }
              }
            },
            child: const Text('Bildir'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndAwardLikeBadges(DocumentReference authorRef) async {
    final authorSnapshot = await authorRef.get();
    if (!authorSnapshot.exists) return;

    final authorData = authorSnapshot.data() as Map<String, dynamic>;
    final likeCount = authorData['likeCount'] ?? 0;
    final earnedBadges = List<String>.from(authorData['earnedBadges'] ?? []);

    if (likeCount >= 50 && !earnedBadges.contains('popular_author')) {
      await authorRef.update({'earnedBadges': FieldValue.arrayUnion(['popular_author'])});
    }
    if (likeCount >= 250 && !earnedBadges.contains('campus_phenomenon')) {
      await authorRef.update({'earnedBadges': FieldValue.arrayUnion(['campus_phenomenon'])});
    }
  }

  void _togglePin() {
    if (!widget.isAdmin) return;
    final postRef = FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId);
    final newPinStatus = !widget.isPinned;

    postRef.update({'isPinned': newPinStatus}).then((_) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newPinStatus ? "Gönderi sabitlendi." : "Gönderi sabitten kaldırıldı."),
          backgroundColor: newPinStatus ? AppColors.success : AppColors.info,
        ));
      }
    });
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gönderiyi Sil'),
        content: const Text('Bu gönderiyi silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await CloudFunctionsService.deletePost(widget.postId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gönderi başarıyla silindi.'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showErrorDialog('Gönderi silinirken bir hata oluştu.');
                }
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final blockedUsersProvider = Provider.of<BlockedUsersProvider>(context);
    if (blockedUsersProvider.isUserBlocked(widget.authorUserId)) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).disabledColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.block_flipped, color: Colors.grey),
            SizedBox(width: 16),
            Expanded(child: Text("Engellenen bir kullanıcının gönderisi gizlendi.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
          ],
        ),
      );
    }

    // StreamBuilder ekleyerek canlı beğeni/yorum sayısı takibi sağlıyoruz
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId).snapshots(),
      builder: (context, snapshot) {
        int liveCommentCount = widget.commentCount;
        List<dynamic> liveLikes = widget.likes;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          liveCommentCount = data['commentCount'] ?? 0;
          liveLikes = data['likes'] as List<dynamic>? ?? [];
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          _isLikedByCurrentUser = currentUserId != null && liveLikes.contains(currentUserId);
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            border: widget.isPinned ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5) : null,
          ),
          child: InkWell(
            onTap: () {
              if (widget.isGuest) {
                widget.onShowLoginRequired();
              } else {
                FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId).get().then((doc) {
                    if (doc.exists && mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => GonderiDetayEkrani.fromDoc(doc)));
                    }
                });
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          FaIcon(FontAwesomeIcons.thumbtack, size: 12, color: AppColors.primary.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          Text("SABİTLENMİŞ GÖNDERİ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary.withOpacity(0.8), letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (widget.authorUserId.isNotEmpty) {
                            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                            if (widget.authorUserId == currentUserId) {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const KullaniciProfilDetayEkrani(userId: null)));
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => KullaniciProfilDetayEkrani(userId: widget.authorUserId, userName: widget.adSoyad)));
                            }
                          }
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                              ? ClipOval(child: CachedNetworkImage(imageUrl: widget.avatarUrl!, width: 40, height: 40, fit: BoxFit.cover, cacheManager: DefaultCacheManager()))
                              : Text(widget.adSoyad.isNotEmpty ? widget.adSoyad[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: [
                                        TextSpan(
                                          text: widget.adSoyad,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        if (widget.isAdmin && widget.realUsername != null && widget.adSoyad == 'Anonim')
                                          TextSpan(
                                            text: ' (${widget.realUsername})',
                                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                      ],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.isAuthorAdmin)
                                  const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: AppColors.primary)),
                              ],
                            ),
                            Row(
                              children: [
                                Text(widget.zaman, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                const SizedBox(width: 6),
                                Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(widget.kategori, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.authorBadges.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: _buildAuthorBadges(widget.authorBadges),
                        ),
                      const Spacer(),
                      if (!widget.isGuest && (FirebaseAuth.instance.currentUser?.uid == widget.authorUserId || widget.isAdmin))
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              _showDeleteConfirmationDialog();
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Sil'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Resim Önizleme (Varsa)
                  if (widget.imageUrls.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.imageUrls.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) {
                                  return Scaffold(
                                    backgroundColor: Colors.black,
                                    appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
                                    body: Center(child: InteractiveViewer(child: CachedNetworkImage(imageUrl: widget.imageUrls[index], fit: BoxFit.contain))),
                                  );
                                }));
                              },
                              child: Container(
                                width: 200,
                                margin: const EdgeInsets.only(right: 10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(imageUrl: widget.imageUrls[index], fit: BoxFit.cover, placeholder: (_,__) => Container(color: Colors.grey[200])),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  Text(widget.baslik, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.2)),
                  const SizedBox(height: 8),
                  Text(widget.mesaj, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8), height: 1.4)),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: _toggleLike,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                                children: [
                                  ScaleTransition(
                                    scale: _likeScale,
                                    child: Icon(_isLikedByCurrentUser ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _isLikedByCurrentUser ? AppColors.like : Colors.grey, size: 22),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(liveLikes.length.toString(), style: TextStyle(color: _isLikedByCurrentUser ? AppColors.like : Colors.grey[700], fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              const Icon(Icons.mode_comment_outlined, color: Colors.grey, size: 22),
                              const SizedBox(width: 6),
                              Text(liveCommentCount.toString(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(onPressed: () => _toggleSave(FirebaseAuth.instance.currentUser?.uid, widget.isSaved), icon: Icon(widget.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: widget.isSaved ? AppColors.primary : Colors.grey)),
                          if (widget.isAdmin) IconButton(onPressed: _togglePin, icon: FaIcon(FontAwesomeIcons.thumbtack, color: widget.isPinned ? AppColors.primary : Colors.grey)),
                          IconButton(
                            onPressed: _showReportDialog,
                            icon: const Icon(Icons.flag_outlined, color: Colors.grey, size: 22),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildAuthorBadges(List<String> badgeIds) {
    final badgesToShow = allBadges.where((b) => badgeIds.contains(b.id)).take(1).toList();
    if (badgesToShow.isEmpty) return const SizedBox.shrink();
    return BadgeWidget(badge: badgesToShow.first, iconSize: 10, fontSize: 10);
  }
}

class GonderiKartiSkeleton extends StatelessWidget {
  const GonderiKartiSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Row(children: [const CircleAvatar(radius: 20), const SizedBox(width: 12), Container(width: 100, height: 14, color: Colors.white)]),
            const SizedBox(height: 16),
            Container(width: double.infinity, height: 18, color: Colors.white),
            const SizedBox(height: 8),
            Container(width: double.infinity, height: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }
}