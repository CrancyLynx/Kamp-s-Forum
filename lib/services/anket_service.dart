import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/anket_model.dart';

class AnketService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Yeni Anket olustur
  static Future<String?> createPoll({
    required String createdByUserId,
    required String createdByName,
    required String title,
    required String description,
    required List<String> optionTexts,
    required List<String> optionEmojis,
    required DateTime expiresAt,
    required String category,
  }) async {
    try {
      final pollRef = _firestore.collection('anketler').doc();
      final pollId = pollRef.id;

      // Options olustur
      final options = <PollOption>[];
      for (int i = 0; i < optionTexts.length; i++) {
        options.add(PollOption(
          id: _firestore.collection('anketler').doc().id,
          text: optionTexts[i],
          voteCount: 0,
          voterIds: [],
          emoji: i < optionEmojis.length ? optionEmojis[i] : '',
        ));
      }

      await pollRef.set({
        'createdByUserId': createdByUserId,
        'createdByName': createdByName,
        'title': title,
        'description': description,
        'options': options.map((o) => o.toMap()).toList(),
        'createdAt': Timestamp.now(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isActive': true,
        'totalVotes': 0,
        'category': category,
        'voterIds': [],
      });

      debugPrint('[POLL] Yeni Anket olusturuldu: $pollId');
      return pollId;
    } catch (e) {
      debugPrint('[POLL] Anket olusturma hatasi: $e');
      return null;
    }
  }

  /// Anket'e oy ver
  static Future<bool> voteOnPoll({
    required String pollId,
    required String userId,
    required String optionId,
  }) async {
    try {
      final pollDoc = await _firestore.collection('anketler').doc(pollId).get();
      
      if (!pollDoc.exists) {
        debugPrint('[POLL] Anket bulunamadi: $pollId');
        return false;
      }

      final pollData = pollDoc.data() as Map<String, dynamic>;
      final options = (pollData['options'] as List).cast<Map<String, dynamic>>();
      
      // Zaten oy vermis mi kontrol et
      if ((pollData['voterIds'] as List).contains(userId)) {
        debugPrint('[POLL] Kullanici zaten oy vermis: $userId -> $pollId');
        return false;
      }

      // Secenegi bul ve guncelle
      for (var option in options) {
        if (option['id'] == optionId) {
          final voterIds = List<String>.from(option['voterIds'] ?? []);
          voterIds.add(userId);
          option['voterIds'] = voterIds;
          option['voteCount'] = (option['voteCount'] as num).toInt() + 1;
          break;
        }
      }

      // Poll'u guncelle
      final pollVoters = List<String>.from(pollData['voterIds'] ?? []);
      pollVoters.add(userId);
      final totalVotes = (pollData['totalVotes'] as num).toInt() + 1;

      await _firestore.collection('anketler').doc(pollId).update({
        'options': options,
        'voterIds': pollVoters,
        'totalVotes': totalVotes,
      });

      // Oylama gecmisini kaydet
      await _firestore.collection('anketler').doc(pollId).collection('oylamalar').add({
        'pollId': pollId,
        'userId': userId,
        'optionId': optionId,
        'votedAt': Timestamp.now(),
      });

      debugPrint('[POLL] Oy verildi: $userId -> Secenek $optionId -> Anket $pollId');
      return true;
    } catch (e) {
      debugPrint('[POLL] Oy verme hatasi: $e');
      return false;
    }
  }

  /// Anket detaylarini getir
  static Future<Anket?> getPoll(String pollId) async {
    try {
      final doc = await _firestore.collection('anketler').doc(pollId).get();
      if (doc.exists) {
        return Anket.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('[POLL] Anket getirme hatasi: $e');
      return null;
    }
  }

  /// Anket stream'i (real-time)
  static Stream<Anket?> getPollStream(String pollId) {
    return _firestore
        .collection('anketler')
        .doc(pollId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return Anket.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Tüm aktif anketleri getir
  static Stream<List<Anket>> getActivePolls() {
    return _firestore
        .collection('anketler')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Anket.fromFirestore(doc))
            .toList());
  }

  /// Kategoriye gore anketleri filtrele
  static Stream<List<Anket>> getPollsByCategory(String category) {
    return _firestore
        .collection('anketler')
        .where('category', isEqualTo: category)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Anket.fromFirestore(doc))
            .toList());
  }

  /// Kullanicinin oyladigi anketleri getir
  static Future<List<Anket>> getUserVotedPolls(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('anketler')
          .where('voterIds', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Anket.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[POLL] Kullanici oyladigi anketleri getirme hatasi: $e');
      return [];
    }
  }

  /// Kullanicinin oylama gecmisini getir
  static Future<List<PollVoteHistory>> getUserVoteHistory(String userId) async {
    try {
      final allPolls = await _firestore.collection('anketler').get();
      final history = <PollVoteHistory>[];

      for (var pollDoc in allPolls.docs) {
        final votesDocs = await pollDoc.reference
            .collection('oylamalar')
            .where('userId', isEqualTo: userId)
            .get();

        for (var voteDoc in votesDocs.docs) {
          history.add(PollVoteHistory.fromFirestore(voteDoc));
        }
      }

      return history;
    } catch (e) {
      debugPrint('[POLL] Oylama gecmisi getirme hatasi: $e');
      return [];
    }
  }

  /// Anket'i kapat
  static Future<bool> closePoll(String pollId) async {
    try {
      await _firestore.collection('anketler').doc(pollId).update({
        'isActive': false,
      });

      debugPrint('[POLL] Anket kapatildi: $pollId');
      return true;
    } catch (e) {
      debugPrint('[POLL] Anket kapama hatasi: $e');
      return false;
    }
  }

  /// Anket'i sil
  static Future<bool> deletePoll(String pollId) async {
    try {
      // Oylamalar subcollection'ini sil
      final oylamalar = await _firestore
          .collection('anketler')
          .doc(pollId)
          .collection('oylamalar')
          .get();

      for (var doc in oylamalar.docs) {
        await doc.reference.delete();
      }

      // Anketi sil
      await _firestore.collection('anketler').doc(pollId).delete();

      debugPrint('[POLL] Anket silindi: $pollId');
      return true;
    } catch (e) {
      debugPrint('[POLL] Anket silme hatasi: $e');
      return false;
    }
  }

  /// En populer anketleri getir (en çok oy alanlar)
  static Future<List<Anket>> getPopularPolls({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('anketler')
          .where('isActive', isEqualTo: true)
          .orderBy('totalVotes', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Anket.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[POLL] Populer anketler getirme hatasi: $e');
      return [];
    }
  }

  /// Oy sayisini kontrol et (cevap onerileri icin)
  static Future<Map<String, int>> getPollResults(String pollId) async {
    try {
      final doc = await _firestore.collection('anketler').doc(pollId).get();
      
      if (!doc.exists) {
        return {};
      }

      final poll = Anket.fromFirestore(doc);
      final results = <String, int>{};

      for (var option in poll.options) {
        results[option.text] = option.voteCount;
      }

      return results;
    } catch (e) {
      debugPrint('[POLL] Sonuclar getirme hatasi: $e');
      return {};
    }
  }

  // Analytics Operations

  /// Anket analitiklerini hesapla
  static Future<Map<String, dynamic>> calculatePollAnalytics(
      String pollId) async {
    try {
      final doc = await _firestore.collection('anketler').doc(pollId).get();
      if (!doc.exists) return {};

      final poll = Anket.fromFirestore(doc);
      final totalVotes = poll.totalVotes;

      final analytics = {
        'pollId': pollId,
        'totalVotes': totalVotes,
        'optionsCount': poll.options.length,
        'averageVotesPerOption': totalVotes > 0
            ? (totalVotes / poll.options.length).toStringAsFixed(2)
            : '0',
        'leadingOption': _getLeadingOption(poll),
        'closestMatch':
            totalVotes > 0 ? _getClosestMatch(poll) : null,
        'voteDistribution': _calculateVoteDistribution(poll),
        'analysisDate': Timestamp.now(),
      };

      return analytics;
    } catch (e) {
      debugPrint('[POLL] Analytics hesaplama hatasi: $e');
      return {};
    }
  }

  static String _getLeadingOption(Anket poll) {
    if (poll.options.isEmpty) return 'N/A';
    PollOption leading = poll.options[0];
    for (var option in poll.options) {
      if (option.voteCount > leading.voteCount) {
        leading = option;
      }
    }
    return '${leading.emoji} ${leading.text} (${leading.voteCount})';
  }

  static String _getClosestMatch(Anket poll) {
    if (poll.options.length < 2) return 'N/A';
    PollOption first = poll.options[0];
    PollOption second = poll.options[1];

    for (var option in poll.options) {
      if (option.voteCount > first.voteCount) {
        second = first;
        first = option;
      } else if (option.voteCount > second.voteCount) {
        second = option;
      }
    }

    final diff = (first.voteCount - second.voteCount).abs();
    return '${first.emoji} vs ${second.emoji} (Fark: $diff)';
  }

  static Map<String, int> _calculateVoteDistribution(Anket poll) {
    final distribution = <String, int>{};
    for (var option in poll.options) {
      distribution[option.emoji] = option.voteCount;
    }
    return distribution;
  }

  /// Trending anketleri getir
  static Future<List<Map<String, dynamic>>> getTrendingPolls() async {
    try {
      final snapshot = await _firestore
          .collection('anketler')
          .where('isActive', isEqualTo: true)
          .orderBy('totalVotes', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'pollId': doc.id,
          'title': data['title'],
          'votes': data['totalVotes'],
          'isTrending': (data['totalVotes'] as num).toInt() > 50,
          'category': data['category'],
        };
      }).toList();
    } catch (e) {
      debugPrint('[POLL] Trending polls hatasi: $e');
      return [];
    }
  }

  /// Anket raporla
  static Future<String?> reportPoll({
    required String pollId,
    required String reporterUserId,
    required String reason,
    required String description,
  }) async {
    try {
      final reportRef = _firestore.collection('poll_reports').doc();

      await reportRef.set({
        'pollId': pollId,
        'reporterUserId': reporterUserId,
        'reason': reason,
        'description': description,
        'createdAt': Timestamp.now(),
        'status': 'pending',
      });

      debugPrint('[POLL] Report gönderildi: ${reportRef.id}');
      return reportRef.id;
    } catch (e) {
      debugPrint('[POLL] Report hatasi: $e');
      return null;
    }
  }

  /// Yönetici - Bekleyen raporları getir
  static Future<List<Map<String, dynamic>>> getPendingReports() async {
    try {
      final snapshot = await _firestore
          .collection('poll_reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[POLL] Pending reports hatasi: $e');
      return [];
    }
  }

  /// Yönetici - Rapor işle
  static Future<bool> processReport({
    required String reportId,
    required String status,
    required String? action,
  }) async {
    try {
      await _firestore
          .collection('poll_reports')
          .doc(reportId)
          .update({
        'status': status,
        'action': action,
        'processedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      debugPrint('[POLL] Report process hatasi: $e');
      return false;
    }
  }

  /// Kategoriye göre anketleri getir (istatistik ile)
  static Future<List<Map<String, dynamic>>> getPollsByCategoryWithStats(
      String category) async {
    try {
      final snapshot = await _firestore
          .collection('anketler')
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'pollId': doc.id,
          'title': data['title'],
          'votes': data['totalVotes'],
          'category': data['category'],
        };
      }).toList();
    } catch (e) {
      debugPrint('[POLL] Category polls hatasi: $e');
      return [];
    }
  }

  /// Anket süresi sona ermiş mi kontrol et
  static Future<bool> checkAndClosePoll(String pollId) async {
    try {
      final doc = await _firestore.collection('anketler').doc(pollId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt) && data['isActive'] == true) {
        await _firestore
            .collection('anketler')
            .doc(pollId)
            .update({'isActive': false});
        debugPrint('[POLL] Poll kapatıldı: $pollId');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[POLL] Poll kapama hatasi: $e');
      return false;
    }
  }

  /// Anket paylaş istatistiği
  static Future<bool> recordPollShare(String pollId, String userId) async {
    try {
      await _firestore
          .collection('anketler')
          .doc(pollId)
          .collection('shares')
          .doc(userId)
          .set({
        'userId': userId,
        'sharedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      debugPrint('[POLL] Share record hatasi: $e');
      return false;
    }
  }

  /// Anket paylaşım sayısını getir
  static Future<int> getPollShareCount(String pollId) async {
    try {
      final snapshot = await _firestore
          .collection('anketler')
          .doc(pollId)
          .collection('shares')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('[POLL] Share count hatasi: $e');
      return 0;
    }
  }
}
