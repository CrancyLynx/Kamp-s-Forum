import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kampus_yardim_app/providers/blocked_users_provider.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/custom_cache_manager.dart'; // Cache Manager eklendi

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
    if (_localVotedIndex == index) return;

    setState(() {
      _isProcessing = true;
      _localVotedIndex = index;
    });

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = FirebaseFirestore.instance.collection('gonderiler').doc(widget.docId);
        final snapshot = await transaction.get(docRef);
        
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final voters = Map<String, dynamic>.from(data['voters'] ?? {});
        final options = List<dynamic>.from(data['options']);
        
        int? serverOldVoteIndex;
        if (voters.containsKey(userId)) {
          serverOldVoteIndex = voters[userId];
        }

        if (serverOldVoteIndex != null) {
          final int currentCount = options[serverOldVoteIndex]['voteCount'] ?? 1;
          options[serverOldVoteIndex]['voteCount'] = currentCount > 0 ? currentCount - 1 : 0;
        }

        options[index]['voteCount'] = (options[index]['voteCount'] ?? 0) + 1;
        voters[userId] = index;

        int newTotal = (data['totalVotes'] ?? 0);
        if (serverOldVoteIndex == null) {
          newTotal += 1;
        }

        transaction.update(docRef, {
          'options': options,
          'voters': voters,
          'totalVotes': newTotal,
        });
      });
    } catch (e) {
      debugPrint("Oy verme hatası: $e");
      if (mounted) {
        _showErrorDialog("Oyunuz kaydedilirken bir hata oluştu. Lütfen tekrar deneyin.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final blockedUsersProvider = Provider.of<BlockedUsersProvider>(context);
    final authorId = widget.data['userId'] as String?;
    if (blockedUsersProvider.isUserBlocked(authorId)) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).disabledColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.block_flipped, color: Colors.grey),
            SizedBox(width: 16),
            Expanded(child: Text("Engellenen bir kullanıcının anketi gizlendi.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
          ],
        ),
      );
    }
    
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final serverVoters = Map<String, dynamic>.from(widget.data['voters'] ?? {});
    final rawOptions = List<dynamic>.from(widget.data['options'] ?? []);
    
    List<Map<String, dynamic>> displayOptions = rawOptions.map((o) => Map<String, dynamic>.from(o)).toList();
    int displayTotalVotes = widget.data['totalVotes'] ?? 0;

    int? serverVotedIndex;
    if (userId != null && serverVoters.containsKey(userId)) {
      serverVotedIndex = serverVoters[userId];
    }

    if (userId != null && _localVotedIndex != serverVotedIndex) {
      if (serverVotedIndex != null) {
        final int current = displayOptions[serverVotedIndex]['voteCount'] ?? 1;
        displayOptions[serverVotedIndex]['voteCount'] = current > 0 ? current - 1 : 0;
      } else {
        displayTotalVotes += 1;
      }
      if (_localVotedIndex != null) {
        final int current = displayOptions[_localVotedIndex!]['voteCount'] ?? 0;
        displayOptions[_localVotedIndex!]['voteCount'] = current + 1;
      }
    }
    
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
          BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 4)),
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
                    ? CachedNetworkImageProvider(widget.data['avatarUrl'], cacheManager: CustomCacheManager.instance) 
                    : null,
                backgroundColor: AppColors.primary.withAlpha(26),
                child: widget.data['avatarUrl'] == null 
                    ? Text(displayName.isNotEmpty ? displayName[0] : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
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
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(widget.data['baslik'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // SEÇENEKLER LİSTESİ
          ...List.generate(displayOptions.length, (index) {
            final option = displayOptions[index];
            final int voteCount = option['voteCount'] ?? 0;
            final String text = option['text'] ?? '';
            final String? imgUrl = option['imageUrl'];

            double percent = 0.0;
            if (displayTotalVotes > 0) {
              percent = voteCount / displayTotalVotes;
            }
            
            final bool isSelected = _localVotedIndex == index;
            final bool anyVote = _localVotedIndex != null;

            // --- 1. RESİMLİ SEÇENEK TASARIMI (YENİ) ---
            if (imgUrl != null && imgUrl.isNotEmpty) {
               return GestureDetector(
                 onTap: () => _handleVote(index),
                 child: Container(
                   margin: const EdgeInsets.only(bottom: 16),
                   height: 180, // Daha büyük ve gösterişli alan
                   decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(16),
                     border: isSelected ? Border.all(color: AppColors.primary, width: 3) : null,
                     boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0,2))]
                   ),
                   child: ClipRRect(
                     borderRadius: BorderRadius.circular(isSelected ? 13 : 16), // Border payı
                     child: Stack(
                       fit: StackFit.expand,
                       children: [
                         // A. Arka Plan Resmi
                         CachedNetworkImage(
                           imageUrl: imgUrl,
                           cacheManager: CustomCacheManager.instance,
                           fit: BoxFit.cover,
                           placeholder: (_,__) => Container(color: Colors.grey[200]),
                           errorWidget: (_,__,_) => Container(color: Colors.grey[300], child: const Icon(Icons.error)),
                         ),

                         // B. Karartma Gradyanı (Yazı okunurluğu için)
                         Container(
                           decoration: BoxDecoration(
                             gradient: LinearGradient(
                               begin: Alignment.topCenter,
                               end: Alignment.bottomCenter,
                               colors: [Colors.transparent, Colors.black.withAlpha(217)],
                               stops: const [0.5, 1.0],
                             ),
                           ),
                         ),

                         // C. Oy Oranı Doluluk Animasyonu (Overlay)
                         if (anyVote)
                           AnimatedFractionallySizedBox(
                             duration: const Duration(milliseconds: 600),
                             curve: Curves.easeOutCubic,
                             widthFactor: percent,
                             alignment: Alignment.centerLeft,
                             child: Container(
                               color: isSelected
                                   ? AppColors.primary.withAlpha(153) // Seçiliyse morumsu
                                   : Colors.white.withAlpha(77), // Değilse beyazımsı
                             ),
                           ),

                         // D. Metin ve Yüzde
                         Padding(
                           padding: const EdgeInsets.all(12.0),
                           child: Column(
                             mainAxisAlignment: MainAxisAlignment.end,
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 children: [
                                   Expanded(
                                     child: Text(
                                       text,
                                       style: const TextStyle(
                                         color: Colors.white,
                                         fontWeight: FontWeight.bold,
                                         fontSize: 15,
                                         shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                         height: 1.2,
                                       ),
                                       maxLines: 2,
                                       overflow: TextOverflow.ellipsis,
                                     ),
                                   ),
                                   if (anyVote)
                                     Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                       decoration: BoxDecoration(
                                         color: Colors.black54,
                                         borderRadius: BorderRadius.circular(8)
                                       ),
                                       child: Text(
                                         "${(percent * 100).toStringAsFixed(0)}%",
                                         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                       ),
                                     ),
                                 ],
                               ),
                               if (isSelected)
                                 const Padding(
                                   padding: EdgeInsets.only(top: 4.0),
                                   child: Text("Senin Seçimin", style: TextStyle(color: AppColors.primaryAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                 )
                             ],
                           ),
                         ),
                       ],
                     ),
                   ),
                 ),
               );
            }

            // --- 2. STANDART METİN SEÇENEK TASARIMI (TAŞMA DÜZELTİLDİ) ---
            return GestureDetector(
              onTap: () => _handleVote(index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                // DÜZELTME: Sabit height kaldırıldı, minHeight eklendi.
                constraints: const BoxConstraints(minHeight: 50),
                child: Stack(
                  children: [
                    // A. Doluluk Çubuğu
                    if (anyVote)
                       Positioned.fill(
                         child: Align(
                           alignment: Alignment.centerLeft,
                           child: AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutQuad,
                            widthFactor: percent,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withAlpha(51) : Colors.grey.withAlpha(38),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                         ),
                       ),

                    // B. Çerçeve ve İçerik
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.withAlpha(77),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
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

                          if (anyVote)
                            Padding(
                              padding: const EdgeInsets.only(left: 12.0),
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
          Text(
            "$displayTotalVotes oy", 
            style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)
          ),
        ],
      ),
    );
  }
}