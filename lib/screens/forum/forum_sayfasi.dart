import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:timeago/timeago.dart' as timeago; // Timeago eklendi
import '../../services/auth_service.dart';
import '../../widgets/animated_list_item.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_header.dart';  // YENİ: Modern header widget'ı
import '../notification/bildirim_ekrani.dart';
import 'gonderi_ekleme_ekrani.dart';
import 'anket_ekleme_ekrani.dart';
import '../../widgets/anket_karti.dart';
import '../chat/sohbet_listesi_ekrani.dart';
import '../../widgets/forum/gonderi_karti.dart'; // ÖNEMLİ: Yeni dosya import edildi

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

// In-memory cache
class _ForumCache {
  static List<DocumentSnapshot>? _posts;
  static List<DocumentSnapshot>? _pinnedPosts;
  static DocumentSnapshot? _lastDocument;
  static bool _hasMore = true;

  static void clear() {
    _posts = null;
    _pinnedPosts = null;
    _lastDocument = null;
    _hasMore = true;
  }
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


  @override
  void initState() {
    super.initState();
    _resetAndFetch();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchMorePosts();
      }
    });

    // Sayfa kapandığında scroll controller'ı temizle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('Forum sayfası açıldı - Gönderiler yükleniyor...');
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    debugPrint('Forum sayfası kapatıldı');
    super.dispose();
  }

  void _showLoginRequiredDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text("Giriş Gerekli"),
        content: const Text("Bu özelliği kullanmak için giriş yapmanız gerekmektedir."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Kapat")),
          ElevatedButton(onPressed: () async { Navigator.of(ctx).pop(); await AuthService().signOut(); }, child: const Text("Giriş Yap")),
        ],
      ));
  }

  Future<void> _resetAndFetch() async {
    _ForumCache.clear();
    if (!mounted) return;
    setState(() { _posts = []; _pinnedPosts = []; _lastDocument = null; _hasMore = true; });
    await _fetchInitialPosts();
  }

  Future<void> _fetchPosts({bool isInitial = false}) async {
    if (_isLoading) return;
    if (mounted) setState(() { _isLoading = true; });

    if (isInitial && _ForumCache._posts != null) {
      if(mounted) {
        setState(() {
          _posts = _ForumCache._posts!;
          _pinnedPosts = _ForumCache._pinnedPosts!;
          _lastDocument = _ForumCache._lastDocument;
          _hasMore = _ForumCache._hasMore;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // Pinned posts'u al
      if (isInitial) {
        try {
          final pinnedQuerySnapshot = await FirebaseFirestore.instance
              .collection('gonderiler')
              .where('isPinned', isEqualTo: true)
              .orderBy('zaman', descending: true)
              .limit(10)
              .get();
          if (mounted) setState(() => _pinnedPosts = pinnedQuerySnapshot.docs);
          _ForumCache._pinnedPosts = _pinnedPosts;

        } catch (e) {
          debugPrint('Pinned posts yükleme hatası: $e');
          if (mounted) setState(() => _pinnedPosts = []);
        }
      }

      // Normal posts'u al
      Query query = FirebaseFirestore.instance.collection('gonderiler');
      
      // Filter ekle
      if (_selectedFilter != 'Tümü') {
        query = query.where('kategori', isEqualTo: _selectedFilter);
      }

      // Sort ekle
      switch (_currentSort) {
        case SortType.newestTopics:
          query = query.where('isPinned', isEqualTo: false).orderBy('zaman', descending: true);
          break;
        case SortType.mostActive:
          query = query.where('isPinned', isEqualTo: false).orderBy('lastCommentTimestamp', descending: true);
          break;
        case SortType.mostPopular:
          query = query.where('isPinned', isEqualTo: false).orderBy('commentCount', descending: true);
          break;
      }

      // Pagination
      if (_lastDocument != null && !isInitial) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await query.limit(15).get();

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        if (mounted) {
          setState(() {
            _posts.addAll(querySnapshot.docs);
          });
        }
        _ForumCache._lastDocument = _lastDocument;
        _ForumCache._posts = _posts;
      }
      
      // _hasMore flag'ini güncelle
      if (querySnapshot.docs.length < 15) {
        if (mounted) setState(() => _hasMore = false);
        _ForumCache._hasMore = false;
      }

    } on FirebaseException catch (e) {
      debugPrint('Firebase hatası: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() => _hasMore = false); // ✅ DÜZELTME: Hata durumunda pagination durdur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gönderiler yüklenemedi: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Genel hata: $e');
      if (mounted) {
        setState(() => _hasMore = false); // ✅ DÜZELTME: Hata durumunda pagination durdur
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bir hata oluştu. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchInitialPosts() async => await _fetchPosts(isInitial: true);
  Future<void> _fetchMorePosts() async => await _fetchPosts();

  void _showCreateOptions(BuildContext context) {
    if (widget.isGuest) { 
      _showLoginRequiredDialog(); 
      return; 
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_note, color: AppColors.primary),
                  title: const Text("Forum Konusu / İtiraf"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GonderiEklemeEkrani(userName: widget.userName),
                      ),
                    ).then((_) => _resetAndFetch());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.poll, color: Colors.purple),
                  title: const Text("Anket Oluştur"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnketEklemeEkrani(userName: widget.userName),
                      ),
                    ).then((_) => _resetAndFetch());
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.15),
              theme.scaffoldBackgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              PanelHeader(
              title: 'Kampüs Forum',
              subtitle: 'Soru, fikir ve tartışmaları paylaş',
              icon: Icons.forum_rounded,
              accentColor: AppColors.primary,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isGuest) ...[
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      tooltip: 'Mesajlar',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SohbetListesiEkrani()));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      tooltip: 'Bildirimler',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const BildirimEkrani()));
                      },
                    ),
                  ]
                ],
              ),
            ),

            // Kategori filtreleri - Kompakt tasarım
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kFilterCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                    selectedColor: AppColors.primary,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: widget.isGuest ? null : FirebaseFirestore.instance.collection('kullanicilar').doc(FirebaseAuth.instance.currentUser!.uid).snapshots(),
              builder: (context, userSnapshot) {
                final Set<String> savedPostIds = (userSnapshot.hasData && userSnapshot.data!.exists) 
                    ? Set<String>.from((userSnapshot.data!.data() as Map<String, dynamic>)['savedPosts'] ?? []) 
                    : {};

                return RefreshIndicator(
                  onRefresh: _resetAndFetch,
                  child: _posts.isEmpty && _pinnedPosts.isEmpty && _isLoading
                      ? ListView.builder(itemCount: 5, itemBuilder: (_, __) => const GonderiKartiSkeleton())
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _pinnedPosts.length + _posts.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _pinnedPosts.length + _posts.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));

                            final bool isPinnedSection = index < _pinnedPosts.length;
                            final doc = isPinnedSection ? _pinnedPosts[index] : _posts[index - _pinnedPosts.length];
                            final data = doc.data()! as Map<String, dynamic>;
                            
                            if (data['type'] == 'anket') {
                              return AnketKarti(docId: doc.id, data: data, isGuest: widget.isGuest, onShowLoginRequired: _showLoginRequiredDialog, isAdmin: widget.isAdmin);
                            }

                            // Zaman formatlama
                            String formattedTime = '';
                            if (data['zaman'] is Timestamp) {
                              formattedTime = timeago.format((data['zaman'] as Timestamp).toDate(), locale: 'tr');
                            }

                            return AnimatedListItem(
                              index: index,
                              child: GonderiKarti(
                                key: ValueKey(doc.id),
                                postId: doc.id,
                                adSoyad: data['ad'] ?? 'Anonim',
                                realUsername: data['realUsername'],
                                baslik: data['baslik'] ?? '',
                                mesaj: data['mesaj'] ?? '',
                                zaman: formattedTime,
                                kategori: data['kategori'] ?? 'Genel',
                                authorUserId: data['userId'] ?? '',
                                avatarUrl: data['avatarUrl'],
                                isGuest: widget.isGuest,
                                isAdmin: widget.isAdmin,
                                onShowLoginRequired: _showLoginRequiredDialog,
                                currentUserTakmaAd: widget.isGuest ? '' : widget.userName,
                                currentUserRealName: widget.isGuest ? '' : widget.realName,
                                isSaved: savedPostIds.contains(doc.id),
                                likes: data['likes'] ?? [],
                                commentCount: data['commentCount'] ?? 0,
                                authorBadges: List<String>.from(data['authorBadges'] ?? []),
                                isPinned: isPinnedSection,
                                imageUrls: List<String>.from(data['imageUrls'] ?? []),
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
        ),
      ),
      floatingActionButton: !widget.isGuest ? FloatingActionButton(
        heroTag: 'forum_create',
        onPressed: () => _showCreateOptions(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }
}
