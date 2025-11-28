import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_colors.dart';
import 'package:timeago/timeago.dart' as timeago;

class AnketKarti extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isGuest;
  final bool isAdmin;
  final String? realUsername;
  final VoidCallback onShowLoginRequired;

  const AnketKarti({
    super.key,
    required this.docId,
    required this.data,
    required this.isGuest,
    this.isAdmin = false,
    this.realUsername,
    required this.onShowLoginRequired,
  });

  @override
  State<AnketKarti> createState() => _AnketKartiState();
}

class _AnketKartiState extends State<AnketKarti> {
  // Yerel durum değişkeni: Kullanıcının o anki seçimi
  int? _localVotedIndex;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  @override
  void didUpdateWidget(covariant AnketKarti oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Eğer işlem yapmıyorsak ve dışarıdan yeni veri geldiyse senkronize et
    if (!_isProcessing) {
      _initializeState();
    }
  }

  void _initializeState() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final voters = Map<String, dynamic>.from(widget.data['voters'] ?? {});
    if (userId != null && voters.containsKey(userId)) {
      _localVotedIndex = voters[userId];
    } else {
      _localVotedIndex = null;
    }
  }

  Future<void> _handleVote(int index) async {
    if (widget.isGuest) {
      widget.onShowLoginRequired();
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Zaten bu şık seçiliyse işlem yapma
    if (_localVotedIndex == index) return;

    // 1. OPTIMISTIC UPDATE (Anında Arayüz Güncelleme)
    setState(() {
      _isProcessing = true;
      _localVotedIndex = index;
    });

    try {
      // 2. Arka Planda Veritabanı İşlemi
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = FirebaseFirestore.instance.collection('gonderiler').doc(widget.docId);
        final snapshot = await transaction.get(docRef);
        
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final voters = Map<String, dynamic>.from(data['voters'] ?? {});
        final options = List<dynamic>.from(data['options']);
        
        // Sunucudaki eski oy durumu
        int? serverOldVoteIndex;
        if (voters.containsKey(userId)) {
          serverOldVoteIndex = voters[userId];
        }

        // Eski oyu düş
        if (serverOldVoteIndex != null) {
          final int currentCount = options[serverOldVoteIndex]['voteCount'] ?? 1;
          options[serverOldVoteIndex]['voteCount'] = currentCount > 0 ? currentCount - 1 : 0;
        }

        // Yeni oyu artır
        options[index]['voteCount'] = (options[index]['voteCount'] ?? 0) + 1;
        
        // Kullanıcıyı kaydet
        voters[userId] = index;

        // Toplam oyu güncelle
        int newTotal = (data['totalVotes'] ?? 0);
        if (serverOldVoteIndex == null) {
          newTotal += 1; // İlk defa oy veriyorsa toplamı artır
        }

        transaction.update(docRef, {
          'options': options,
          'voters': voters,
          'totalVotes': newTotal,
        });
      });
    } catch (e) {
      debugPrint("Oy verme hatası: $e");
      // Hata olursa state'i eski haline döndürebiliriz (isteğe bağlı)
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final serverVoters = Map<String, dynamic>.from(widget.data['voters'] ?? {});
    final rawOptions = List<dynamic>.from(widget.data['options'] ?? []);
    
    // --- GECİKMEYİ ÖNLEYEN HESAPLAMA (Sihirli Kısım) ---
    // Sunucudan gelen veriyi alıp, yerel seçime (_localVotedIndex) göre
    // anlık olarak sayıları manipüle ediyoruz. Böylece kullanıcı sunucuyu beklemeden
    // doğru yüzdeleri görür.

    // 1. Seçenekleri kopyala (üzerinde değişiklik yapacağız)
    List<Map<String, dynamic>> displayOptions = rawOptions.map((o) => Map<String, dynamic>.from(o)).toList();
    
    // 2. Sunucudaki toplam oyu al
    int displayTotalVotes = widget.data['totalVotes'] ?? 0;

    // 3. Sunucuda kullanıcının kayıtlı eski oyu var mı?
    int? serverVotedIndex;
    if (userId != null && serverVoters.containsKey(userId)) {
      serverVotedIndex = serverVoters[userId];
    }

    // 4. Hesaplama Mantığı:
    // Eğer şu anki yerel seçim, sunucudakinden farklıysa sayıları düzelt.
    if (userId != null && _localVotedIndex != serverVotedIndex) {
      // a) Eğer sunucuda zaten bir oyu varsa, o oyu sanal olarak düş
      if (serverVotedIndex != null) {
        final int current = displayOptions[serverVotedIndex]['voteCount'] ?? 1;
        displayOptions[serverVotedIndex]['voteCount'] = current > 0 ? current - 1 : 0;
        // Toplam değişmez çünkü sadece oy yer değiştirdi
      } else {
        // b) Sunucuda oyu yoksa (ilk defa oy veriyor), toplamı 1 artır
        displayTotalVotes += 1;
      }

      // c) Yeni seçilen şıkkın oyunu sanal olarak artır
      if (_localVotedIndex != null) {
        final int current = displayOptions[_localVotedIndex!]['voteCount'] ?? 0;
        displayOptions[_localVotedIndex!]['voteCount'] = current + 1;
      }
    }
    
    // --- ARAYÜZ ---
    final displayName = widget.data['ad'] ?? 'Anonim';
    String timeStr = '';
    if (widget.data['zaman'] is Timestamp) {
      timeStr = timeago.format((widget.data['zaman'] as Timestamp).toDate(), locale: 'tr');
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık Bölümü
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: (widget.data['avatarUrl'] != null) 
                    ? NetworkImage(widget.data['avatarUrl']) 
                    : null,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: widget.data['avatarUrl'] == null 
                    ? Text(displayName.isNotEmpty ? displayName[0] : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(text: displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (widget.isAdmin && widget.realUsername != null && displayName == 'Anonim')
                          TextSpan(text: ' (${widget.realUsername})', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text("$timeStr • Anket", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(widget.data['baslik'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Seçenekler Listesi
          ...List.generate(displayOptions.length, (index) {
            final option = displayOptions[index];
            final int voteCount = option['voteCount'] ?? 0;
            final String text = option['text'] ?? '';
            final String? imgUrl = option['imageUrl'];

            // Yüzde Hesaplama
            double percent = 0.0;
            if (displayTotalVotes > 0) {
              percent = voteCount / displayTotalVotes;
            }
            
            final bool isSelected = _localVotedIndex == index;
            final bool anyVote = _localVotedIndex != null;

            return GestureDetector(
              onTap: () => _handleVote(index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12), // Boşluk arttırıldı
                // Resim varsa yükseklik daha fazla, yoksa standart
                height: imgUrl != null ? 55 : 45,
                child: Stack(
                  children: [
                    // 1. Doluluk Çubuğu (Animasyonlu)
                    if (anyVote)
                      AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutQuad,
                        widthFactor: percent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),

                    // 2. Çerçeve ve İçerik
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: anyVote ? Colors.transparent : Theme.of(context).cardColor,
                      ),
                      child: Row(
                        children: [
                          // Resim (YouTube Tarzı Sol Kare)
                          if (imgUrl != null && imgUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: imgUrl,
                                  width: 45, // Kare boyut
                                  height: 45,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                                  errorWidget: (context, url, error) => const Icon(Icons.image, color: Colors.grey),
                                ),
                              ),
                            ),
                          
                          // Metin
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text(
                                text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? AppColors.primary : Theme.of(context).textTheme.bodyLarge?.color,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),

                          // Yüzde Göstergesi
                          if (anyVote)
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Text(
                                "${(percent * 100).toStringAsFixed(0)}%",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppColors.primary : Colors.grey[600],
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
          }),

          const SizedBox(height: 8),
          // Toplam Oy Sayısı
          Text(
            "$displayTotalVotes oy", 
            style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)
          ),
        ],
      ),
    );
  }
}