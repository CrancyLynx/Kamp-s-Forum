import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_colors.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../utils/maskot_helper.dart';
import '../../services/data_preload_service.dart';
import '../forum/gonderi_detay_ekrani.dart';
import '../profile/kullanici_profil_detay_ekrani.dart';

class BildirimEkrani extends StatefulWidget {
  const BildirimEkrani({super.key});

  @override
  State<BildirimEkrani> createState() => _BildirimEkraniState();
}

class _BildirimEkraniState extends State<BildirimEkrani> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Global Key'ler
  final GlobalKey _markAllReadButtonKey = GlobalKey();
  final GlobalKey _firstNotificationKey = GlobalKey();
  final GlobalKey _emptyStateKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Arka planda notification cache'ini ısıt
    DataPreloadService.getCachedData('notifications').catchError((e) {
      debugPrint('Notification cache warm-up hatasi: $e');
    });
    _cleanupOldNotifications();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeMaskot();
  }

  void _initializeMaskot() {
    FirebaseFirestore.instance
        .collection('bildirimler')
        .where('userId', isEqualTo: _currentUserId)
        .limit(1)
        .get()
        .then((snapshot) {
      if (!mounted) return;
      
      // Firestore sorgusu tamamlandıktan sonra widget ağacının render edilmesini bekle
      Future.delayed(Duration(milliseconds: 500), () {
        if (!mounted) return;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showMaskotTutorial(snapshot);
        });
      });
    }).catchError((e) {
      debugPrint('🔴 Bildirim maskotu hata: $e');
    });
  }

  void _showMaskotTutorial(QuerySnapshot snapshot) {
    List<TargetFocus> targets = [];

    // 1. Mark All Read Button - Her zaman göster (güvenli)
    if (_markAllReadButtonKey.currentContext != null) {
      targets.add(TargetFocus(
          identify: "mark-all-read",
          keyTarget: _markAllReadButtonKey,
          alignSkip: Alignment.bottomRight,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) =>
                  MaskotHelper.buildTutorialContent(context,
                      title: 'Bildirimlerini Yönet',
                      description:
                          'Bu butonla tüm bildirimlerini tek seferde okundu olarak işaretleyebilirsin.',
                      mascotAssetPath: 'assets/images/duyuru_bay.png'),
            )
          ]));
    }

    // 2. Conditional target - Notifications varsa göster, yoksa empty state göster
    bool hasNotifications = snapshot.docs.isNotEmpty;
    GlobalKey? targetKey = hasNotifications ? _firstNotificationKey : _emptyStateKey;
    
    if (targetKey.currentContext != null) {
      targets.add(TargetFocus(
          identify: hasNotifications ? "first-notification" : "empty-state",
          keyTarget: targetKey,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) =>
                  MaskotHelper.buildTutorialContent(context,
                      title: 'Gözün Burada Olsun',
                      description:
                          'Biri gönderini beğendiğinde, yorum yaptığında veya takip ettiğinde buradan haberin olacak.',
                      mascotAssetPath: 'assets/images/duyuru_bay.png'),
            )
          ]));
    }

    // Hedef varsa göster, yoksa debug log
    if (targets.isNotEmpty) {
      MaskotHelper.checkAndShowSafe(
        context,
        featureKey: 'bildirim_tutorial_gosterildi',
        rawTargets: targets,
        delay: Duration(milliseconds: 300),
        maxRetries: 2,
      );
    } else {
      debugPrint('⚠️ Bildirim maskotu: Geçerli hedef bulunamadı (keys null)');
    }
  }

  // DÜZELTME: Batch Limit Kontrolü Eklendi
  Future<void> _cleanupOldNotifications() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      
      // Döngüsel silme (Her seferinde 500 adet)
      while (true) {
        final snapshot = await FirebaseFirestore.instance
            .collection('bildirimler')
            .where('userId', isEqualTo: _currentUserId)
            .where('isRead', isEqualTo: true)
            .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
            .limit(500) // Firestore limitine uy
            .get();

        if (snapshot.docs.isEmpty) break;

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

  Future<void> _deleteNotification(String docId) async {
    await FirebaseFirestore.instance.collection('bildirimler').doc(docId).delete();
  }

  Future<void> _markAllAsRead() async {
    // Okunmamışları parça parça çekip güncelle
    while (true) {
        final snapshot = await FirebaseFirestore.instance
            .collection('bildirimler')
            .where('userId', isEqualTo: _currentUserId)
            .where('isRead', isEqualTo: false)
            .limit(500)
            .get();
        
        if (snapshot.docs.isEmpty) break;

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
    }

    // unreadNotifications counter'ını 0'a ayarla
    await FirebaseFirestore.instance
        .collection('kullanicilar')
        .doc(_currentUserId)
        .update({'unreadNotifications': 0});
  }

  Future<void> _handleNotificationTap(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null || data.isEmpty) return;

    final String? senderId = data['senderId'];
    final String? postId = data['postId'];
    final String? senderName = data['senderName'];
    final bool isSpam = data['isSpam'] ?? false;

    // Spam bildirimine tıklanırsa görmezden gel
    if (isSpam) {
      debugPrint('[NOTIFICATION] Spam bildirimine tıklandı - görmezden gel');
      return;
    }

    // Sender ID validasyonu
    if (senderId == null || senderId.isEmpty) {
      debugPrint('[NOTIFICATION] SenderId boş - navigasyon yapılamadı');
      return;
    }

    // Önce okundu olarak işaretle
    if (data['isRead'] == false) {
      doc.reference.update({'isRead': true});
      
      // unreadNotifications counter'ını azalt
      await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(_currentUserId)
          .update({'unreadNotifications': FieldValue.increment(-1)});
    }

    // Yönlendirme yap
    final notificationType = data['type'] as String?;
    if ((notificationType == 'like' || notificationType == 'new_comment' || notificationType == 'comment_reply') && postId != null) {
      // Gönderi detayına git
      FirebaseFirestore.instance.collection('gonderiler').doc(postId).get().then((postDoc) {
        if (postDoc.exists && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GonderiDetayEkrani.fromDoc(postDoc)),
          );
        } else {
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İlgili gönderi bulunamadı veya silinmiş.")));
        }
      });
    } else if (notificationType == 'new_follower' || notificationType == 'follow') {
      // Takipçinin profiline git
       Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => KullaniciProfilDetayEkrani(userId: senderId, userName: senderName ?? 'Kullanıcı')),
      );
    }
    // Diğer bildirim türleri için de benzer yönlendirmeler eklenebilir
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.notifications_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Bildirimler',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 2,
        actions: [
          IconButton(
            key: _markAllReadButtonKey, 
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
            .where('isSpam', isNotEqualTo: true) // Spam bildirimleri filtrele
            .orderBy('isSpam')
            .orderBy('timestamp', descending: true)
            .limit(500) // En son 500 bildirim
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ DÜZELTME: Stream error kontrolü - daha detaylı hata gösterimi
          if (snapshot.hasError) {
            final error = snapshot.error.toString();
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Uzgun_bay mascot with asset fallback
                  Image.asset(
                    'assets/images/uzgun_bay.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.error_outline, size: 60, color: Colors.red[300]);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Bildirimler yüklenemedi 😢",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      error.length > 200 ? error.substring(0, 200) + '...' : error,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Yeniden Dene"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
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
              return KeyedSubtree(
                key: index == 0 ? _firstNotificationKey : null, 
                child: _buildNotificationItem(doc, context),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(DocumentSnapshot doc, BuildContext context) {
    final data = doc.data() as Map<String, dynamic>?;
    
    // Null safety check
    if (data == null || data.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isRead = data['isRead'] ?? false;
    final String message = data['message'] ?? 'Bildirim';
    final String senderName = data['senderName'] ?? 'Sistem';
    final Timestamp? timestamp = data['timestamp'];
    final bool isSpam = data['isSpam'] ?? false;
    final String timeAgo = timestamp != null ? _formatTimestamp(timestamp) : '';

    // Spam bildirimi UI'da gösterilmeyecek
    if (isSpam) {
      return const SizedBox.shrink();
    }

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart, 
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
          side: isRead ? BorderSide.none : BorderSide(color: AppColors.primary.withAlpha(77), width: 1),
        ),
        child: InkWell(
          onTap: () async => await _handleNotificationTap(doc),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotificationIcon(doc),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.black87, fontSize: 14, fontFamily: 'Segoe UI'), 
                          children: [
                            TextSpan(
                              text: "${senderName.isNotEmpty ? senderName : 'Bir kullanıcı'} ",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: message), 
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

  Widget _buildNotificationIcon(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return _buildDefaultIcon(data?['type']);

    // Like bildirimi - sender avatar'ı göster
    if (data['type'] == 'like' && data['senderAvatarUrl'] != null && (data['senderAvatarUrl'] as String).isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.redAccent, width: 2),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: data['senderAvatarUrl'],
            width: 42,
            height: 42,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => _buildDefaultIcon(data['type']),
          ),
        ),
      );
    }

    return _buildDefaultIcon(data['type']);
  }

  Widget _buildDefaultIcon(String? type) {
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
      case 'follow': 
      case 'new_follower':
        icon = Icons.person_add;
        color = Colors.green;
        break;
      case 'welcome':
        icon = Icons.waving_hand;
        color = Colors.amber;
        break;
      default:
        icon = Icons.notifications;
        color = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: _emptyStateKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Uzgun_bay mascot with asset fallback
          Image.asset(
            'assets/images/uzgun_bay.png',
            width: 120,
            height: 120,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]);
            },
          ),
          const SizedBox(height: 16),
          Text(
            "Hiç bildiriminiz yok 😢",
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Yeni bildirimler geldiğinde buraya çıkacak.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
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
