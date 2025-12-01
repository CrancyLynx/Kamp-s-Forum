// (Importlar aynı kalacak, sadece FloatingActionButton kısmını değiştiriyoruz)
// Kodun tamamını veriyorum ki kopyala yapıştır yaparken hata olmasın.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/animated_list_item.dart';
import '../../utils/app_colors.dart';
import '../profile/kullanici_profil_detay_ekrani.dart';

import '../admin/admin_panel_ekrani.dart';
import 'gonderi_detay_ekrani.dart';
import '../../models/badge_model.dart';

import '../notification/bildirim_ekrani.dart';
import 'gonderi_ekleme_ekrani.dart';
import 'anket_ekleme_ekrani.dart';
import '../../widgets/anket_karti.dart';
import '../../widgets/badge_widget.dart';
import '../chat/sohbet_listesi_ekrani.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

const List<String> kCategories = ['Eğitim', 'Okul', 'Dersler', 'Sınavlar', 'Etkinlikler', 'Sosyal', 'Diğer'];
const List<String> kFilterCategories = ['Tümü', ...kCategories];

enum SortType { newestTopics, mostActive, mostPopular }

class ForumSayfasi extends StatefulWidget {
  final bool isGuest;
  final bool isAdmin;
  final String userName;
  final String realName;

  const ForumSayfasi({
    super.key,
    this.isGuest = false,
    this.isAdmin = false,
    required this.userName,
    required this.realName
  });

  @override
  State<ForumSayfasi> createState() => _ForumSayfasiState();
}

class _ForumSayfasiState extends State<ForumSayfasi> {
  SortType _currentSort = SortType.newestTopics;
  String _selectedFilter = 'Tümü';

  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _posts = [];
  List<DocumentSnapshot> _pinnedPosts = []; 
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  String? _errorMessage;

  // ... (Diyalog fonksiyonları aynı)
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Giriş Gerekli"),
        content: const Text("Bu özelliği kullanmak için giriş yapmanız gerekmektedir."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Kapat")),
          ElevatedButton(
            onPressed: () {
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null && currentUser.isAnonymous) {
                currentUser.delete();
              }
              Navigator.of(ctx).pop();
            },
            child: const Text("Giriş Yap"),
          ),
        ],
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    if (widget.isGuest) {
      _showLoginRequiredDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Wrap(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.edit_note, color: AppColors.primary, size: 28),
                  ),
                  title: const Text("Forum Konusu / İtiraf", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Bir tartışma başlat veya anonim içini dök."),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => GonderiEklemeEkrani(userName: widget.userName)))
                        .then((_) => _resetAndFetch());
                  },
                ),
                const Divider(indent: 20, endIndent: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.poll, color: Colors.purple, size: 28),
                  ),
                  title: const Text("Anket Oluştur", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Topluluğun fikrini al."),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AnketEklemeEkrani(userName: widget.userName)))
                        .then((_) => _resetAndFetch());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialPosts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resetAndFetch() async {
    if (!mounted) return;
    setState(() {
      _posts = [];
      _pinnedPosts = [];
      _lastDocument = null;
      _hasMore = true;
      _errorMessage = null;
    });
    await _fetchInitialPosts();
  }

  Future<void> _fetchPosts({bool isInitial = false}) async {
    if (_isLoading) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      if (isInitial) {
        final pinnedQuerySnapshot = await FirebaseFirestore.instance
            .collection('gonderiler')
            .where('isPinned', isEqualTo: true)
            .get();
        if (mounted) {
          setState(() {
            _pinnedPosts = pinnedQuerySnapshot.docs;
          });
        }
      }

      Query query = FirebaseFirestore.instance.collection('gonderiler');

      if (_selectedFilter != 'Tümü') {
        query = query.where('kategori', isEqualTo: _selectedFilter);
      }

      switch (_currentSort) {
        case SortType.newestTopics:
          query = query.orderBy('zaman', descending: true);
          break;
        case SortType.mostActive:
          query = query.orderBy('lastCommentTimestamp', descending: true);
          break;
        case SortType.mostPopular:
          query = query.orderBy('commentCount', descending: true);
          break;
      }

      if (_lastDocument != null && !isInitial) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await query.limit(15).get();

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        if (mounted) {
          setState(() {
            final newPosts = querySnapshot.docs.where((doc) {
              return !_pinnedPosts.any((pinned) => pinned.id == doc.id);
            }).toList();
            
            _posts.addAll(newPosts);
          });
        }
      }

      if (querySnapshot.docs.length < 15) {
        if (mounted) setState(() => _hasMore = false);
      }
    } on FirebaseException catch (e) {
      debugPrint("Firebase Veri Çekme Hatası: ${e.code} - ${e.message}");
      if (mounted) {
        if (e.code == 'unavailable') {
          setState(() => _errorMessage = "İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin.");
        } else if (e.code == 'permission-denied') {
          setState(() => _errorMessage = "Verilere erişim izniniz yok. Lütfen yönetici ile iletişime geçin.");
        } else if (e.code == 'failed-precondition') {
          setState(() => _errorMessage = "Sorgu indeksi oluşturuluyor, lütfen biraz bekleyip tekrar deneyin.");
        } else {
          setState(() => _errorMessage = "Gönderiler yüklenemedi. Hata: ${e.message}");
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchInitialPosts() async {
    await _fetchPosts(isInitial: true);
  }

  Future<void> _fetchMorePosts() async {
    await _fetchPosts();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
          Image.asset('assets/images/app_logo3.png', height: 40),
            const SizedBox(width: 10),
            const Text(
              "Kampüs Forum",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          if (!widget.isGuest) ...[
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SohbetListesiEkrani()));
              },
            ),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bildirimler')
                  .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                int unreadCount = 0;
                if (snapshot.hasData) {
                  unreadCount = snapshot.data!.docs.length;
                }

                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const BildirimEkrani()));
                      },
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ] 
        ],
      ),

      body: Column(
        children: [
          // Filtreler (Kodun kalanı aynı)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
            ),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildSortChip('Yeni', SortType.newestTopics, Icons.access_time_rounded),
                      const SizedBox(width: 8),
                      _buildSortChip('Aktif', SortType.mostActive, Icons.local_fire_department_rounded),
                      const SizedBox(width: 8),
                      _buildSortChip('Popüler', SortType.mostPopular, Icons.trending_up_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: kFilterCategories.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = kFilterCategories[index];
                      final isSelected = _selectedFilter == category;
                      return ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          if (selected) {
                            setState(() => _selectedFilter = category);
                            _resetAndFetch();
                          }
                        },
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: widget.isGuest
                  ? null
                  : FirebaseFirestore.instance.collection('kullanicilar').doc(FirebaseAuth.instance.currentUser!.uid).snapshots(),
              builder: (context, userSnapshot) {
                final Set<String> savedPostIds;
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final data = userSnapshot.data!.data() as Map<String, dynamic>;
                  savedPostIds = Set<String>.from(data['savedPosts'] ?? []);
                } else {
                  savedPostIds = {};
                }

                return RefreshIndicator(
                  onRefresh: () async => _resetAndFetch(),
                  color: AppColors.primary,
                  child: _isLoading && _posts.isEmpty && _pinnedPosts.isEmpty
                      ? _buildSkeletonLoader()
                      : _errorMessage != null && _posts.isEmpty && _pinnedPosts.isEmpty
                      ? _buildErrorWidget(_errorMessage!)
                      : _posts.isEmpty && _pinnedPosts.isEmpty
                      ? _buildEmptyListWidget()
                      : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: _pinnedPosts.length + _posts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _pinnedPosts.length + _posts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final bool isPinnedSection = index < _pinnedPosts.length;
                      final DocumentSnapshot document;
                      
                      if (isPinnedSection) {
                        document = _pinnedPosts[index];
                      } else {
                        document = _posts[index - _pinnedPosts.length];
                      }

                      Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

                      String type = data['type'] ?? 'gonderi';
                      bool isPinned = isPinnedSection || (data['isPinned'] ?? false);
                      String realUsername = data['realUsername'] ?? data['takmaAd'] ?? '';

                      if (type == 'anket') {
                        return AnimatedListItem(
                          index: index,
                          child: AnketKarti(
                            docId: document.id,
                            data: data,
                            isGuest: widget.isGuest,
                            onShowLoginRequired: _showLoginRequiredDialog,
                            isAdmin: widget.isAdmin,
                            realUsername: realUsername,
                          ),
                        );
                      }

                      String formattedTime = '...';
                      if (data['zaman'] is Timestamp) {
                        Timestamp t = data['zaman'] as Timestamp;
                        DateTime date = t.toDate();
                        final now = DateTime.now();
                        final diff = now.difference(date);

                        if (diff.inDays > 0) {
                          formattedTime = "${diff.inDays}g önce";
                        } else if (diff.inHours > 0) {
                          formattedTime = "${diff.inHours}s önce";
                        } else if (diff.inMinutes > 0) {
                          formattedTime = "${diff.inMinutes}dk önce";
                        } else {
                          formattedTime = "Şimdi";
                        }
                      }

                      final String authorUserId = data['userId'] ?? '';

                      return AnimatedListItem(
                        index: index,
                        child: GonderiKarti(
                          key: ValueKey(document.id),
                          postId: document.id,
                          adSoyad: data['ad'] ?? 'Anonim',
                          realUsername: realUsername, 
                          baslik: data['baslik'] ?? 'Başlıksız',
                          mesaj: data['mesaj'] ?? 'Boş mesaj',
                          zaman: formattedTime,
                          kategori: data['kategori'] ?? 'Genel',
                          isAuthorAdmin: false,
                          authorUserId: authorUserId,
                          avatarUrl: data['avatarUrl'],
                          isGuest: widget.isGuest,
                          isAdmin: widget.isAdmin, 
                          onShowLoginRequired: _showLoginRequiredDialog,
                          currentUserTakmaAd: widget.isGuest ? 'Misafir' : widget.userName,
                          currentUserRealName: widget.isGuest ? 'Misafir' : widget.realName,
                          isSaved: savedPostIds.contains(document.id),
                          likes: (data['likes'] as List<dynamic>? ?? []),
                          isPinned: isPinned,
                          commentCount: (data['commentCount'] as int? ?? 0),
                          authorBadges: List<String>.from(data['authorBadges'] ?? []),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // DÜZELTME: heroTag eklendi
      floatingActionButton: widget.isGuest ? null : FloatingActionButton.extended(
        heroTag: 'forum_create_fab', // BENZERSİZ TAG
        onPressed: () => _showCreateOptions(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Oluştur", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 4,
      ),
    );
  }

  // ... (Geri kalan yardımcı widgetlar - _buildSortChip, _buildSkeletonLoader vs aynı kalıyor)
  Widget _buildSortChip(String label, SortType sortType, IconData icon) {
    final isSelected = _currentSort == sortType;
    return GestureDetector(
      onTap: () {
        setState(() => _currentSort = sortType);
        _resetAndFetch();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => const GonderiKartiSkeleton(),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.greyText, size: 60),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AppColors.greyDark)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _resetAndFetch,
              icon: const Icon(Icons.refresh),
              label: const Text("Tekrar Dene"),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyListWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FaIcon(FontAwesomeIcons.comments, size: 70, color: AppColors.greyMedium),
          const SizedBox(height: 24),
          const Text(
            "Henüz hiç konu yok!",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.greyDark),
          ),
          const SizedBox(height: 8),
          const Text("Sessizliği bozan ilk kişi sen ol.", style: TextStyle(color: AppColors.greyText, fontSize: 16)),
        ],
      ),
    );
  }
}

// ... (GonderiKarti ve GonderiKartiSkeleton sınıfları dosyanın sonunda olduğu gibi kalacak)
// Sadece GonderiKartiSkeleton ve GonderiKarti'yi buraya tekrar yazarak kodu tamamlarsınız.
// Yukarıdaki kodun orijinalindeki GonderiKarti sınıfını aynen koruyun.
class GonderiKartiSkeleton extends StatelessWidget {
  const GonderiKartiSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 20, backgroundColor: Colors.white),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 100, height: 14, color: Colors.white),
                    const SizedBox(height: 4),
                    Container(width: 60, height: 10, color: Colors.white),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(width: double.infinity, height: 18, color: Colors.white),
            const SizedBox(height: 8),
            Container(width: double.infinity, height: 14, color: Colors.white),
            const SizedBox(height: 4),
            Container(width: 200, height: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

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
  });

  @override
  State<GonderiKarti> createState() => _GonderiKartiState();
}

class _GonderiKartiState extends State<GonderiKarti> with SingleTickerProviderStateMixin {
  late List<dynamic> _currentLikes;
  late bool _isLikedByCurrentUser;
  late AnimationController _likeController;
  late Animation<double> _likeScale;

  @override
  void initState() {
    super.initState();
    _currentLikes = List.from(widget.likes);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _isLikedByCurrentUser = currentUserId != null && _currentLikes.contains(currentUserId);

    _likeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _likeScale = Tween<double>(begin: 1.0, end: 1.4).animate(CurvedAnimation(parent: _likeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Future<void> _sendLikeNotification(String senderId, String senderName, String receiverId, String postId, String postTitle) async {
    if (senderId == receiverId) return;
    if (!mounted) return;

    await FirebaseFirestore.instance.collection('bildirimler').add({
      'userId': receiverId,
      'postId': postId,
      'postTitle': postTitle,
      'type': 'like',
      'senders': [{'id': senderId, 'name': senderName}],
      'message': '$senderName gönderini beğendi.',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }


  Future<void> _removeLikeNotification(String senderId, String receiverId, String postId) async {
    if (senderId == receiverId) return;
    if (!mounted) return;

    final notificationsRef = FirebaseFirestore.instance.collection('bildirimler');
    final query = await notificationsRef
        .where('userId', isEqualTo: receiverId)
        .where('postId', isEqualTo: postId)
        .where('type', isEqualTo: 'like')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final docId = query.docs.first.id;
      await notificationsRef.doc(docId).update({
        'senders': FieldValue.arrayRemove([{'id': senderId, 'name': widget.currentUserTakmaAd}])
      });
    }
  }

  void _toggleSave(String? currentUserId, bool isSaved) {
    if (widget.isGuest || currentUserId == null) {
      widget.onShowLoginRequired();
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('kullanicilar').doc(currentUserId);

    if (isSaved) {
      userRef.update({'savedPosts': FieldValue.arrayRemove([widget.postId])});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kaydedilenlerden kaldırıldı."), backgroundColor: AppColors.info));
    } else {
      userRef.update({'savedPosts': FieldValue.arrayUnion([widget.postId])});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gönderi kaydedildi!"), backgroundColor: AppColors.success));
    }
  }

  void _toggleLike() {
    if (widget.isGuest) {
      widget.onShowLoginRequired();
      return;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final postRef = FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId);

    if (_isLikedByCurrentUser) {
      postRef.update({'likes': FieldValue.arrayRemove([currentUserId])});
      _removeLikeNotification(currentUserId, widget.authorUserId, widget.postId);
      FirebaseFirestore.instance.collection('kullanicilar').doc(widget.authorUserId).update({'likeCount': FieldValue.increment(-1)});
      setState(() {
        _currentLikes.remove(currentUserId);
        _isLikedByCurrentUser = false;
      });
    } else {
      _likeController.forward().then((_) => _likeController.reverse());
      postRef.update({'likes': FieldValue.arrayUnion([currentUserId])});
      _sendLikeNotification(currentUserId, widget.currentUserTakmaAd, widget.authorUserId, widget.postId, widget.baslik);
      final authorRef = FirebaseFirestore.instance.collection('kullanicilar').doc(widget.authorUserId);
      authorRef.update({'likeCount': FieldValue.increment(1)}).then((_) => _checkAndAwardLikeBadges(authorRef));
      setState(() {
        _currentLikes.add(currentUserId);
        _isLikedByCurrentUser = true;
      });
    }
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

  // Gönderiyi sabitleme/kaldırma fonksiyonu
  void _togglePin() {
    if (!widget.isAdmin) return;

    final postRef = FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId);
    final newPinStatus = !widget.isPinned;

    postRef.update({'isPinned': newPinStatus}).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newPinStatus ? "Gönderi sabitlendi." : "Gönderi sabitten kaldırıldı."),
        backgroundColor: newPinStatus ? AppColors.success : AppColors.info,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId).snapshots(),
      builder: (context, snapshot) {
        
        int liveCommentCount = widget.commentCount;
        List<dynamic> liveLikes = widget.likes;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          liveCommentCount = data['commentCount'] ?? 0;
          liveLikes = data['likes'] as List<dynamic>? ?? [];
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: widget.isPinned
                ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5)
                : null,
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
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                          backgroundImage: (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                              ? CachedNetworkImageProvider(widget.avatarUrl!)
                              : null,
                          child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
                              ? Text(widget.adSoyad.isNotEmpty ? widget.adSoyad[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                              : null,
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
                                Text(widget.kategori, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.authorBadges.isNotEmpty)
                        _buildAuthorBadges(widget.authorBadges),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    widget.baslik,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.mesaj,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8), height: 1.4),
                  ),

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
                                    child: Icon(
                                      _isLikedByCurrentUser ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: _isLikedByCurrentUser ? AppColors.like : Colors.grey,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    liveLikes.length.toString(),
                                    style: TextStyle(
                                      color: _isLikedByCurrentUser ? AppColors.like : Colors.grey[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.mode_comment_outlined, color: Colors.grey, size: 22),
                                  const SizedBox(width: 6),
                                  Text(
                                    liveCommentCount.toString(),
                                    style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _toggleSave(FirebaseAuth.instance.currentUser?.uid, widget.isSaved),
                            icon: Icon(
                              widget.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              color: widget.isSaved ? AppColors.primary : Colors.grey,
                            ),
                            tooltip: "Kaydet",
                          ),
                          // Admin için sabitleme butonu
                          if (widget.isAdmin)
                            IconButton(
                              onPressed: _togglePin,
                              icon: FaIcon(
                                FontAwesomeIcons.thumbtack,
                                color: widget.isPinned ? AppColors.primary : Colors.grey,
                              ),
                              tooltip: widget.isPinned ? "Sabitlemeyi Kaldır" : "Gönderiyi Sabitle",
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