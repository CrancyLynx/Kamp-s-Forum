import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/phase4_models.dart';

class BlockedUserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Kullanıcıyı engelle
  static Future<String> blockUser(String blockerUserId, String blockedUserId, {String? reason}) async {
    try {
      final docRef = await _firestore.collection('blocked_users').add({
        'blockedUserId': blockedUserId,
        'blockerUserId': blockerUserId,
        'blockedAt': Timestamp.now(),
        'reason': reason,
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Kullanıcı engelleme hatası: $e');
    }
  }

  /// Engellemeyi kaldır
  static Future<void> unblockUser(String blockerUserId, String blockedUserId) async {
    try {
      final snapshot = await _firestore
          .collection('blocked_users')
          .where('blockerUserId', isEqualTo: blockerUserId)
          .where('blockedUserId', isEqualTo: blockedUserId)
          .get();
      
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Engelleme kaldırma hatası: $e');
    }
  }

  /// Kullanıcının engelleme listesi
  static Stream<List<BlockedUser>> getBlockedUsers(String userId) {
    return _firestore
        .collection('blocked_users')
        .where('blockerUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BlockedUser.fromFirestore(doc))
            .toList());
  }

  /// Engellendi mi kontrol et
  static Future<bool> isUserBlocked(String blockerUserId, String blockedUserId) async {
    try {
      final snapshot = await _firestore
          .collection('blocked_users')
          .where('blockerUserId', isEqualTo: blockerUserId)
          .where('blockedUserId', isEqualTo: blockedUserId)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Engelleme kontrolü hatası: $e');
    }
  }
}

class SavedPostService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gönderiyi kaydet
  static Future<String> savePost(SavedPost savedPost) async {
    try {
      final docRef = await _firestore.collection('saved_posts').add(savedPost.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Gönderi kaydetme hatası: $e');
    }
  }

  /// Kaydı kaldır
  static Future<void> removeFromSaved(String userId, String postId) async {
    try {
      final snapshot = await _firestore
          .collection('saved_posts')
          .where('userId', isEqualTo: userId)
          .where('postId', isEqualTo: postId)
          .get();
      
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Kaydı kaldırma hatası: $e');
    }
  }

  /// Kullanıcının kaydedilen gönderileri
  static Stream<List<SavedPost>> getSavedPostsOfUser(String userId) {
    return _firestore
        .collection('saved_posts')
        .where('userId', isEqualTo: userId)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedPost.fromFirestore(doc))
            .toList());
  }

  /// Koleksiyona göre kaydedilen gönderiler
  static Stream<List<SavedPost>> getSavedPostsByCollection(String userId, String collectionName) {
    return _firestore
        .collection('saved_posts')
        .where('userId', isEqualTo: userId)
        .where('collectionName', isEqualTo: collectionName)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedPost.fromFirestore(doc))
            .toList());
  }

  /// Kaydedilmiş mi kontrol et
  static Future<bool> isPostSaved(String userId, String postId) async {
    try {
      final snapshot = await _firestore
          .collection('saved_posts')
          .where('userId', isEqualTo: userId)
          .where('postId', isEqualTo: postId)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Kaydetme kontrolü hatası: $e');
    }
  }

  /// Koleksiyon oluştur
  static Future<void> createCollection(String userId, String collectionName) async {
    try {
      await _firestore
          .collection('user_saved_collections')
          .add({
            'userId': userId,
            'collectionName': collectionName,
            'createdAt': Timestamp.now(),
          });
    } catch (e) {
      throw Exception('Koleksiyon oluşturma hatası: $e');
    }
  }
}

class ChangeRequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Değişiklik talebini oluştur
  static Future<String> createChangeRequest(ChangeRequest request) async {
    try {
      final docRef = await _firestore.collection('change_requests').add(request.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Değişiklik talebini oluşturma hatası: $e');
    }
  }

  /// Talebini onayla
  static Future<void> approveRequest(String requestId, String adminId) async {
    try {
      await _firestore.collection('change_requests').doc(requestId).update({
        'status': 'approved',
        'reviewedByAdminId': adminId,
      });
    } catch (e) {
      throw Exception('Talebini onaylama hatası: $e');
    }
  }

  /// Talebini reddet
  static Future<void> rejectRequest(String requestId, String adminId) async {
    try {
      await _firestore.collection('change_requests').doc(requestId).update({
        'status': 'rejected',
        'reviewedByAdminId': adminId,
      });
    } catch (e) {
      throw Exception('Talebini reddetme hatası: $e');
    }
  }

  /// Bekleyen istekler
  static Stream<List<ChangeRequest>> getPendingRequests() {
    return _firestore
        .collection('change_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChangeRequest.fromFirestore(doc))
            .toList());
  }

  /// Kullanıcının istekleri
  static Stream<List<ChangeRequest>> getUserRequests(String userId) {
    return _firestore
        .collection('change_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChangeRequest.fromFirestore(doc))
            .toList());
  }
}

class ReportComplaintService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Şikayeti raporla
  static Future<String> submitReport(ReportComplaint report) async {
    try {
      final docRef = await _firestore.collection('report_complaints').add(report.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Rapor gönderme hatası: $e');
    }
  }

  /// Raporu araştır
  static Future<void> startInvestigation(String reportId, String adminId) async {
    try {
      await _firestore.collection('report_complaints').doc(reportId).update({
        'status': 'investigating',
        'reviewedByAdminId': adminId,
      });
    } catch (e) {
      throw Exception('Araştırma başlatma hatası: $e');
    }
  }

  /// Raporu çöz
  static Future<void> resolveReport(String reportId, String resolution, String adminId) async {
    try {
      await _firestore.collection('report_complaints').doc(reportId).update({
        'status': 'resolved',
        'resolution': resolution,
        'reviewedByAdminId': adminId,
      });
    } catch (e) {
      throw Exception('Raporu çözme hatası: $e');
    }
  }

  /// Bekleyen raporlar
  static Stream<List<ReportComplaint>> getPendingReports() {
    return _firestore
        .collection('report_complaints')
        .where('status', isEqualTo: 'pending')
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReportComplaint.fromFirestore(doc))
            .toList());
  }

  /// Rapor tipine göre
  static Stream<List<ReportComplaint>> getReportsByType(String reportType) {
    return _firestore
        .collection('report_complaints')
        .where('reportType', isEqualTo: reportType)
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReportComplaint.fromFirestore(doc))
            .toList());
  }

  /// Kullanıcının raporları
  static Stream<List<ReportComplaint>> getUserReports(String userId) {
    return _firestore
        .collection('report_complaints')
        .where('reportedByUserId', isEqualTo: userId)
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReportComplaint.fromFirestore(doc))
            .toList());
  }
}

class AdvancedModerationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Moderasyon eylemi uygula
  static Future<String> applyModerationAction(AdvancedModeration moderation) async {
    try {
      final docRef = await _firestore.collection('advanced_moderation').add(moderation.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Moderasyon eylemi uygulama hatası: $e');
    }
  }

  /// Eylemi kaldır
  static Future<void> removeModerationAction(String moderationId) async {
    try {
      await _firestore.collection('advanced_moderation').doc(moderationId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Moderasyon eylemi kaldırma hatası: $e');
    }
  }

  /// Kullanıcının aktif moderasyon eylemleri
  static Stream<List<AdvancedModeration>> getActiveModerationsForUser(String userId) {
    return _firestore
        .collection('advanced_moderation')
        .where('targetUserId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdvancedModeration.fromFirestore(doc))
            .toList());
  }

  /// Süresi dolmuş eylemleri kontrol et
  static Future<void> cleanExpiredModerations() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('advanced_moderation')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({'isActive': false});
      }
    } catch (e) {
      throw Exception('Süresi dolan moderasyonlar temizleme hatası: $e');
    }
  }

  /// Tüm moderasyon geçmişi
  static Stream<List<AdvancedModeration>> getModerationHistory(String userId) {
    return _firestore
        .collection('advanced_moderation')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdvancedModeration.fromFirestore(doc))
            .toList());
  }
}

class RingComplaintService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ring şikayeti dosya
  static Future<String> fileRingComplaint(RingComplaint complaint) async {
    try {
      final docRef = await _firestore.collection('ring_complaints').add(complaint.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Ring şikayeti dosya hatası: $e');
    }
  }

  /// Şikayeti araştır
  static Future<void> investigateComplaint(String complaintId, String adminId) async {
    try {
      await _firestore.collection('ring_complaints').doc(complaintId).update({
        'status': 'investigating',
      });
    } catch (e) {
      throw Exception('Şikayet araştırma hatası: $e');
    }
  }

  /// Şikayeti çöz
  static Future<void> resolveComplaint(String complaintId, String resolution) async {
    try {
      await _firestore.collection('ring_complaints').doc(complaintId).update({
        'status': 'resolved',
        'resolution': resolution,
      });
    } catch (e) {
      throw Exception('Şikayet çözme hatası: $e');
    }
  }

  /// Ring'e ait şikayetler
  static Stream<List<RingComplaint>> getComplaintsForRing(String ringId) {
    return _firestore
        .collection('ring_complaints')
        .where('ringId', isEqualTo: ringId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RingComplaint.fromFirestore(doc))
            .toList());
  }

  /// Bekleyen şikayetler
  static Stream<List<RingComplaint>> getPendingComplaints() {
    return _firestore
        .collection('ring_complaints')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RingComplaint.fromFirestore(doc))
            .toList());
  }

  /// Kullanıcının şikayetleri
  static Stream<List<RingComplaint>> getComplaintsFromUser(String userId) {
    return _firestore
        .collection('ring_complaints')
        .where('complainantUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RingComplaint.fromFirestore(doc))
            .toList());
  }

  /// Şikayet tipine göre
  static Stream<List<RingComplaint>> getComplaintsByType(String complaintType) {
    return _firestore
        .collection('ring_complaints')
        .where('complaintType', isEqualTo: complaintType)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RingComplaint.fromFirestore(doc))
            .toList());
  }
}

class LocationIconService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// İkon ekle
  static Future<String> addLocationIcon(LocationIcon icon) async {
    try {
      final docRef = await _firestore.collection('location_icons').add(icon.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('İkon ekleme hatası: $e');
    }
  }

  /// Kategoriye göre ikonlar
  static Stream<List<LocationIcon>> getIconsByCategory(String category) {
    return _firestore
        .collection('location_icons')
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationIcon.fromFirestore(doc))
            .toList());
  }

  /// Varsayılan ikonlar
  static Stream<List<LocationIcon>> getDefaultIcons() {
    return _firestore
        .collection('location_icons')
        .where('isDefault', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationIcon.fromFirestore(doc))
            .toList());
  }

  /// Tüm ikonlar
  static Stream<List<LocationIcon>> getAllIcons() {
    return _firestore
        .collection('location_icons')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationIcon.fromFirestore(doc))
            .toList());
  }
}

