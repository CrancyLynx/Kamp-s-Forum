import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';
import '../../widgets/badge_widget.dart';
import '../../models/badge_model.dart';
import '../chat/sohbet_detay_ekrani.dart';
import 'profil_duzenleme_ekrani.dart'; // Düzenleme ekranı için
import 'rozetler_sayfasi.dart'; // Rozetler sayfası için

class KullaniciProfilDetayEkrani extends StatefulWidget {
  final String? userId; // Eğer null ise kendi profilim
  final String? userName;

  const KullaniciProfilDetayEkrani({
    super.key,
    required this.userId,
    this.userName,
  });

  @override
  State<KullaniciProfilDetayEkrani> createState() => _KullaniciProfilDetayEkraniState();
}

class _KullaniciProfilDetayEkraniState extends State<KullaniciProfilDetayEkrani> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isFollowing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    if (widget.userId == null || widget.userId == _currentUserId) return;
    
    final doc = await FirebaseFirestore.instance
        .collection('kullanicilar')
        .doc(widget.userId)
        .get();
        
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final followers = List<String>.from(data['followers'] ?? []);
      if (mounted) {
        setState(() {
          _isFollowing = followers.contains(_currentUserId);
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.userId == null) return;
    
    setState(() => _isLoading = true);
    final targetRef = FirebaseFirestore.instance.collection('kullanicilar').doc(widget.userId);
    final myRef = FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId);

    try {
      if (_isFollowing) {
        // Takipten Çık
        await targetRef.update({'followers': FieldValue.arrayRemove([_currentUserId]), 'followerCount': FieldValue.increment(-1)});
        await myRef.update({'following': FieldValue.arrayRemove([widget.userId]), 'followingCount': FieldValue.increment(-1)});
        setState(() => _isFollowing = false);
      } else {
        // Takip Et
        await targetRef.update({'followers': FieldValue.arrayUnion([_currentUserId]), 'followerCount': FieldValue.increment(1)});
        await myRef.update({'following': FieldValue.arrayUnion([widget.userId]), 'followingCount': FieldValue.increment(1)});
        
        // Bildirim Gönder
        await FirebaseFirestore.instance.collection('bildirimler').add({
          'userId': widget.userId,
          'type': 'follow',
          'senderId': _currentUserId,
          'message': 'Seni takip etmeye başladı.',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        setState(() => _isFollowing = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchURL(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link açılamadı.")));
    }
  }

  // --- YENİ: Admin Yetkisi Verme/Alma Fonksiyonu ---
  Future<void> _toggleAdminRole(String targetUserId, bool isCurrentlyAdmin) async {
     try {
       final newRole = isCurrentlyAdmin ? 'user' : 'admin';
       await FirebaseFirestore.instance.collection('kullanicilar').doc(targetUserId).update({
         'role': newRole
       });
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isCurrentlyAdmin ? "Admin yetkisi alındı." : "Admin yetkisi verildi.")));
       setState(() {}); // Ekranı yenile
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
     }
  }

  @override
  Widget build(BuildContext context) {
    final targetId = widget.userId ?? _currentUserId;

    // 1. SİLİNMİŞ KULLANICI KONTROLÜ (Bu kısım eksikti)
    if (targetId == 'deleted_user') {
       return Scaffold(
         appBar: AppBar(title: const Text("Profil Bulunamadı")),
         body: const Center(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(Icons.person_off, size: 80, color: Colors.grey),
               SizedBox(height: 16),
               Text("Bu kullanıcı hesabını silmiş.", style: TextStyle(fontSize: 18, color: Colors.grey)),
             ],
           ),
         ),
       );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName ?? "Profil"),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('kullanicilar').doc(targetId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.data!.exists) {
            return const Center(child: Text("Kullanıcı bulunamadı."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final badges = List<String>.from(data['earnedBadges'] ?? []);
          
          // 2. YENİ ROL KONTROLÜ (Eski kAdminUids yerine burası çalışacak)
          final String role = data['role'] ?? 'user';
          final bool isAdmin = (role == 'admin');

          // Benim rolüm ne? (Admin işlemleri panelini göstermek için)
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId).get(),
            builder: (context, mySnapshot) {
               final myData = mySnapshot.data?.data() as Map<String, dynamic>?;
               final bool amIAdmin = (myData?['role'] == 'admin');

               return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: (data['avatarUrl'] != null && data['avatarUrl'].isNotEmpty)
                          ? CachedNetworkImageProvider(data['avatarUrl'])
                          : null,
                      child: (data['avatarUrl'] == null || data['avatarUrl'].isEmpty)
                          ? Text(data['takmaAd']?[0].toUpperCase() ?? '?', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary))
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          data['takmaAd'] ?? 'Anonim',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        if (isAdmin) 
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(Icons.verified, color: AppColors.primary),
                          ),
                      ],
                    ),
                    if (data['biyografi'] != null && data['biyografi'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(data['biyografi'], textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                      ),
                    
                    const SizedBox(height: 16),
                    // Sosyal Linkler
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (data['github'] != null && data['github'].isNotEmpty)
                          IconButton(icon: const FaIcon(FontAwesomeIcons.github), onPressed: () => _launchURL("https://github.com/${data['github']}")),
                        if (data['linkedin'] != null && data['linkedin'].isNotEmpty)
                          IconButton(icon: const FaIcon(FontAwesomeIcons.linkedin), onPressed: () => _launchURL("https://linkedin.com/in/${data['linkedin']}")),
                        if (data['instagram'] != null && data['instagram'].isNotEmpty)
                          IconButton(icon: const FaIcon(FontAwesomeIcons.instagram), onPressed: () => _launchURL("https://instagram.com/${data['instagram']}")),
                        if (data['x_platform'] != null && data['x_platform'].isNotEmpty)
                          IconButton(icon: const FaIcon(FontAwesomeIcons.xTwitter), onPressed: () => _launchURL("https://x.com/${data['x_platform']}")),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem("Takipçi", data['followerCount'] ?? 0),
                        _buildStatItem("Takip", data['followingCount'] ?? 0),
                        _buildStatItem("Gönderi", data['postCount'] ?? 0),
                      ],
                    ),

                    const SizedBox(height: 24),
                    
                    // BUTONLAR
                    if (widget.userId == null || widget.userId == _currentUserId)
                      // Kendi Profilimse: Düzenle ve Rozetler butonu
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilDuzenlemeEkrani()));
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text("Düzenle"),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => RozetlerSayfasi(earnedBadgeIds: Set<String>.from(badges), userData: data, isAdmin: isAdmin)));
                              },
                              icon: const Icon(Icons.emoji_events, size: 16),
                              label: const Text("Rozetler"),
                            ),
                          ),
                        ],
                      )
                    else
                      // Başkasının Profili ise: Takip Et ve Mesaj Butonu
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing ? Colors.grey[300] : AppColors.primary,
                                foregroundColor: _isFollowing ? Colors.black : Colors.white,
                              ),
                              child: Text(_isFollowing ? "Takibi Bırak" : "Takip Et"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => SohbetDetayEkrani(receiverId: widget.userId!, receiverName: data['takmaAd'] ?? 'Kullanıcı', receiverAvatar: data['avatarUrl'])));
                              },
                              child: const Text("Mesaj Gönder"),
                            ),
                          ),
                        ],
                      ),
                      
                    // 3. YÖNETİCİ PANELİ (Eksik Olan Kısım)
                    // Sadece BEN Adminsem ve profiline baktığım kişi başkasıysa bu paneli göster
                    if (amIAdmin && widget.userId != null && widget.userId != _currentUserId)
                       Container(
                         margin: const EdgeInsets.only(top: 24),
                         padding: const EdgeInsets.all(16),
                         decoration: BoxDecoration(
                           color: Colors.red.withOpacity(0.05),
                           borderRadius: BorderRadius.circular(12),
                           border: Border.all(color: Colors.red.withOpacity(0.2))
                         ),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             const Text("Yönetici İşlemleri", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                             const SizedBox(height: 10),
                             SwitchListTile(
                               title: const Text("Yönetici Yetkisi"),
                               subtitle: const Text("Bu kullanıcıya admin yetkisi ver."),
                               value: isAdmin,
                               onChanged: (val) => _toggleAdminRole(widget.userId!, isAdmin),
                             ),
                           ],
                         ),
                       ),

                    const SizedBox(height: 24),
                    // ROZETLER VİTRİNİ (Eksik Olan Kısım)
                    if (badges.isNotEmpty) ...[
                      const Align(alignment: Alignment.centerLeft, child: Text("Kazanılan Rozetler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: badges.map((id) {
                          // Rozeti bul, yoksa varsayılanı göster
                          final badge = allBadges.firstWhere((b) => b.id == id, orElse: () => allBadges[0]);
                          return BadgeWidget(badge: badge);
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(count.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}