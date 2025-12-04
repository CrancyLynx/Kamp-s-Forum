import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/forum_rule_model.dart';

class ForumRuleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kural Yönetimi

  /// Yeni Forum Kuralı ekle (Admin)
  static Future<String?> addRule({
    required String baslik,
    required String aciklama,
    required int sirayaGore,
    required String kategori,
    required List<String> ornekler,
    required String ceza,
  }) async {
    try {
      final ruleRef = _firestore.collection('forum_rules').doc();
      final ruleId = ruleRef.id;

      await ruleRef.set({
        'baslik': baslik,
        'aciklama': aciklama,
        'sirayaGore': sirayaGore,
        'kategori': kategori,
        'ornekler': ornekler,
        'aktif': true,
        'ceza': ceza,
      });

      debugPrint('[RULE] Yeni kural eklendi: $ruleId');
      return ruleId;
    } catch (e) {
      debugPrint('[RULE] Kural ekleme hatasi: $e');
      return null;
    }
  }

  /// Tüm kuralları getir (sıraya göre)
  static Stream<List<ForumRule>> getAllRules() {
    return _firestore
        .collection('forum_rules')
        .where('aktif', isEqualTo: true)
        .orderBy('sirayaGore')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ForumRule.fromFirestore(doc))
            .toList());
  }

  /// Kategoriye gore kuralları getir
  static Future<List<ForumRule>> getRulesByCategory(String kategori) async {
    try {
      final snapshot = await _firestore
          .collection('forum_rules')
          .where('kategori', isEqualTo: kategori)
          .where('aktif', isEqualTo: true)
          .orderBy('sirayaGore')
          .get();

      return snapshot.docs.map((doc) => ForumRule.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[RULE] Kategori kuralları getirme hatasi: $e');
      return [];
    }
  }

  /// Kural detaylarını getir
  static Future<ForumRule?> getRule(String ruleId) async {
    try {
      final doc = await _firestore.collection('forum_rules').doc(ruleId).get();
      if (doc.exists) {
        return ForumRule.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('[RULE] Kural getirme hatasi: $e');
      return null;
    }
  }

  // İhlal Raporlama

  /// Gönderiyi kural ihlali için rapor et
  static Future<String?> reportViolation({
    required String gonderisId,
    required String ihlalEdenUserId,
    required String ihlalEdenUserName,
    required String kaidaId,
    required String kaidaBasligi,
    required String raporEdenUserId,
  }) async {
    try {
      final violationRef = _firestore.collection('rule_violations').doc();
      final violationId = violationRef.id;

      // Daha önce rapor edilmiş mi kontrol et
      final existing = await _firestore
          .collection('rule_violations')
          .where('gonderisId', isEqualTo: gonderisId)
          .where('durum', isNotEqualTo: 'reddedildi')
          .get();

      if (existing.docs.isNotEmpty) {
        // Zaten rapor var, report count'u artır
        await existing.docs.first.reference.update({
          'reportEdenCount': FieldValue.increment(1),
        });
        debugPrint('[RULE] Var olan ihlal raporuna vote eklendi');
        return existing.docs.first.id;
      }

      // Yeni ihlal raporu oluştur
      await violationRef.set({
        'gonderisId': gonderisId,
        'ihlalEdenUserId': ihlalEdenUserId,
        'ihlalEdenUserName': ihlalEdenUserName,
        'kaidaId': kaidaId,
        'kaidaBasligi': kaidaBasligi,
        'ihlalfZamani': Timestamp.now(),
        'durum': 'raporlandi',
        'reportEdenCount': 1,
        'moderatorNotlari': null,
        'ceza': null,
        'cekaZamanı': null,
        'shadowBanned': false,
      });

      // Report kaydı tut
      await _firestore.collection('rule_violations').doc(violationId).collection('reporters').add({
        'userId': raporEdenUserId,
        'reportedAt': Timestamp.now(),
      });

      debugPrint('[RULE] Yeni ihlal raporu oluşturuldu: $violationId');
      return violationId;
    } catch (e) {
      debugPrint('[RULE] İhlal raporlama hatasi: $e');
      return null;
    }
  }

  /// Tüm raporlanan ihlalleri getir (moderator paneli)
  static Stream<List<RuleViolation>> getPendingViolations() {
    return _firestore
        .collection('rule_violations')
        .where('durum', isEqualTo: 'raporlandi')
        .orderBy('reportEdenCount', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RuleViolation.fromFirestore(doc))
            .toList());
  }

  /// İhlal raporunu onayla (uygunsuz içerik)
  static Future<bool> approveViolation(
    String violationId,
    String moderatorId,
    String ceza,
  ) async {
    try {
      final violationDoc = await _firestore.collection('rule_violations').doc(violationId).get();
      final violation = RuleViolation.fromFirestore(violationDoc);

      // Gönderiyi shadow ban et
      await _firestore
          .collection('gonderiler')
          .doc(violation.gonderisId)
          .update({
        'shadowBanned': true,
        'bannedAt': Timestamp.now(),
        'bannedReason': violation.kaidaBasligi,
      });

      // İhlali onayla ve ceza ver
      await _firestore.collection('rule_violations').doc(violationId).update({
        'durum': 'onaylandi',
        'moderatorNotlari': 'Kural ihlali dogrulandı',
        'ceza': ceza,
        'cekaZamanı': Timestamp.now(),
        'shadowBanned': true,
      });

      // Ceza kaydı oluştur
      await _createUserPenalty(
        userId: violation.ihlalEdenUserId,
        userName: violation.ihlalEdenUserName,
        tip: ceza,
        nedeni: 'Forum Kuralı İhlali: ${violation.kaidaBasligi}',
        verilenModerId: moderatorId,
      );

      debugPrint('[RULE] İhlal onaylandi: $violationId');
      return true;
    } catch (e) {
      debugPrint('[RULE] İhlal onaylama hatasi: $e');
      return false;
    }
  }

  /// İhlal raporunu reddet
  static Future<bool> rejectViolation(String violationId, String moderatorId, String neden) async {
    try {
      await _firestore.collection('rule_violations').doc(violationId).update({
        'durum': 'reddedildi',
        'moderatorNotlari': neden,
        'cekaZamanı': Timestamp.now(),
      });

      debugPrint('[RULE] İhlal reddedildi: $violationId');
      return true;
    } catch (e) {
      debugPrint('[RULE] İhlal reddetme hatasi: $e');
      return false;
    }
  }

  // Ceza Yönetimi

  /// Kullanıcıya ceza ver
  static Future<bool> _createUserPenalty({
    required String userId,
    required String userName,
    required String tip,
    required String nedeni,
    required String verilenModerId,
  }) async {
    try {
      final penaltyRef = _firestore.collection('user_penalties').doc();
      final gecerliligi = _calculatePenaltyExpiration(tip);

      await penaltyRef.set({
        'userId': userId,
        'userName': userName,
        'tip': tip,
        'nedeni': nedeni,
        'gecerliligi': Timestamp.fromDate(gecerliligi),
        'verilenModerId': verilenModerId,
        'verilmeTarihi': Timestamp.now(),
        'aktif': true,
      });

      debugPrint('[RULE] Ceza oluşturuldu: $tip -> $userId');
      return true;
    } catch (e) {
      debugPrint('[RULE] Ceza oluşturma hatasi: $e');
      return false;
    }
  }

  /// Kullanıcı cezasını kaldır
  static Future<bool> removePenalty(String penaltyId) async {
    try {
      await _firestore.collection('user_penalties').doc(penaltyId).update({
        'aktif': false,
      });

      debugPrint('[RULE] Ceza kaldırıldı: $penaltyId');
      return true;
    } catch (e) {
      debugPrint('[RULE] Ceza kaldırma hatasi: $e');
      return false;
    }
  }

  /// Kullanıcının aktif cezalarını getir
  static Future<List<UserPenalty>> getUserActivePenalties(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_penalties')
          .where('userId', isEqualTo: userId)
          .where('aktif', isEqualTo: true)
          .get();

      final penalties = snapshot.docs
          .map((doc) => UserPenalty.fromFirestore(doc))
          .toList();

      // Süresi bitmişleri filtrele
      return penalties.where((p) => !p.isExpired()).toList();
    } catch (e) {
      debugPrint('[RULE] Kullanıcı cezaları getirme hatasi: $e');
      return [];
    }
  }

  /// Ceza süresi hesapla
  static DateTime _calculatePenaltyExpiration(String tip) {
    final now = DateTime.now();
    switch (tip) {
      case '7gun_ban':
        return now.add(const Duration(days: 7));
      case '30gun_ban':
        return now.add(const Duration(days: 30));
      case 'kalici_ban':
        return now.add(const Duration(days: 365 * 100)); // 100 yıl
      default:
        return now.add(const Duration(days: 1)); // 1 gün uyarı
    }
  }

  // İstatistikler

  /// Forum kurallarının uygulanma istatistikleri
  static Future<Map<String, dynamic>> getEnforcementStats() async {
    try {
      final violations = await _firestore.collection('rule_violations').get();
      final penalties = await _firestore.collection('user_penalties').get();

      return {
        'totalViolations': violations.size,
        'approvedViolations': violations.docs
            .where((doc) => doc['durum'] == 'onaylandi')
            .length,
        'pendingViolations': violations.docs
            .where((doc) => doc['durum'] == 'raporlandi')
            .length,
        'totalPenalties': penalties.size,
        'activePenalties': penalties.docs
            .where((doc) => doc['aktif'] == true)
            .length,
      };
    } catch (e) {
      debugPrint('[RULE] İstatistik getirme hatasi: $e');
      return {};
    }
  }
}
