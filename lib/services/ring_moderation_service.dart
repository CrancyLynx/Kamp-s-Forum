import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class RingModerationService {
  static const String _pendingPhotosCollection = 'pending_ring_photos';
  static const String _approvedPhotosCollection = 'ulasim_bilgileri';
  static const String _moderationLogCollection = 'ring_photo_moderation';

  /// Ring sefer fotoğrafını pending status'unda yükle (admin onayı bekleniyor)
  static Future<bool> uploadRingPhotoForApproval({
    required String universityName,
    required String photoStoragePath, // Storage'da kaydedilen dosya yolu
    required String uploadedByUserId,
    required String uploaderName,
  }) async {
    try {
      final photoId = FirebaseFirestore.instance.collection(_pendingPhotosCollection).doc().id;

      // Storage'da dosyayı kontrol et ve URL'sini al
      final ref = FirebaseStorage.instance.ref(photoStoragePath);
      final metadata = await ref.getMetadata();

      if (metadata.size == null || metadata.size! > 10 * 1024 * 1024) {
        debugPrint('[RING_MOD] Dosya boyutu limiti aşıldı');
        return false;
      }

      final downloadUrl = await ref.getDownloadURL();

      // Pending collection'a kaydet
      await FirebaseFirestore.instance.collection(_pendingPhotosCollection).doc(photoId).set({
        'id': photoId,
        'universityName': universityName,
        'photoUrl': downloadUrl,
        'storagePath': photoStoragePath,
        'uploadedBy': uploadedByUserId,
        'uploaderName': uploaderName,
        'uploadedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, approved, rejected
        'approvedBy': null,
        'approvedAt': null,
        'rejectionReason': null,
      });

      debugPrint('[RING_MOD] Fotoğraf pending koleksiyonuna kaydedildi: $photoId');
      return true;
    } catch (e) {
      debugPrint('[RING_MOD] Fotoğraf upload hatası: $e');
      return false;
    }
  }

  /// Admin tarafından Ring fotoğrafını onayla ve herkese açık yap
  static Future<bool> approvePendingPhoto({
    required String photoId,
    required String adminUserId,
    required String adminName,
  }) async {
    try {
      final photoDoc = await FirebaseFirestore.instance
          .collection(_pendingPhotosCollection)
          .doc(photoId)
          .get();

      if (!photoDoc.exists) {
        debugPrint('[RING_MOD] Fotoğraf bulunamadı: $photoId');
        return false;
      }

      final photoData = photoDoc.data() as Map<String, dynamic>;
      final universityName = photoData['universityName'] as String;
      final photoUrl = photoData['photoUrl'] as String;
      final uploaderName = photoData['uploaderName'] as String;
      final uploadedBy = photoData['uploadedBy'] as String;

      // Onaylı fotoğrafı public koleksiyonuna taşı
      await FirebaseFirestore.instance
          .collection(_approvedPhotosCollection)
          .doc(universityName)
          .set({
        'university': universityName,
        'imageUrl': photoUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': uploadedBy,
        'updaterName': uploaderName,
        'approvedBy': adminUserId,
        'approvedByName': adminName,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Pending dokumentu güncelle
      await FirebaseFirestore.instance.collection(_pendingPhotosCollection).doc(photoId).update({
        'status': 'approved',
        'approvedBy': adminUserId,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Moderasyon log'a kaydet
      await _logModerationAction(
        action: 'approved',
        photoId: photoId,
        adminUserId: adminUserId,
        adminName: adminName,
        universityName: universityName,
      );

      debugPrint('[RING_MOD] Fotoğraf onaylandı: $photoId');
      return true;
    } catch (e) {
      debugPrint('[RING_MOD] Onay hatası: $e');
      return false;
    }
  }

  /// Admin tarafından Ring fotoğrafını reddet
  static Future<bool> rejectPendingPhoto({
    required String photoId,
    required String adminUserId,
    required String adminName,
    required String rejectionReason,
  }) async {
    try {
      final photoDoc = await FirebaseFirestore.instance
          .collection(_pendingPhotosCollection)
          .doc(photoId)
          .get();

      if (!photoDoc.exists) {
        debugPrint('[RING_MOD] Fotoğraf bulunamadı: $photoId');
        return false;
      }

      final photoData = photoDoc.data() as Map<String, dynamic>;
      final universityName = photoData['universityName'] as String;
      final storagePath = photoData['storagePath'] as String;

      // Storage'dan dosyayı sil
      try {
        await FirebaseStorage.instance.ref(storagePath).delete();
      } catch (e) {
        debugPrint('[RING_MOD] Storage dosya silme hatası: $e');
      }

      // Pending dokumentu güncelle
      await FirebaseFirestore.instance.collection(_pendingPhotosCollection).doc(photoId).update({
        'status': 'rejected',
        'approvedBy': adminUserId,
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectionReason': rejectionReason,
      });

      // Moderasyon log'a kaydet
      await _logModerationAction(
        action: 'rejected',
        photoId: photoId,
        adminUserId: adminUserId,
        adminName: adminName,
        universityName: universityName,
        reason: rejectionReason,
      );

      debugPrint('[RING_MOD] Fotoğraf reddedildi: $photoId, Sebep: $rejectionReason');
      return true;
    } catch (e) {
      debugPrint('[RING_MOD] Ret hatası: $e');
      return false;
    }
  }

  /// Moderasyon işlemini log'a kaydet
  static Future<void> _logModerationAction({
    required String action,
    required String photoId,
    required String adminUserId,
    required String adminName,
    required String universityName,
    String? reason,
  }) async {
    try {
      await FirebaseFirestore.instance.collection(_moderationLogCollection).add({
        'action': action, // approved, rejected, deleted
        'photoId': photoId,
        'universityName': universityName,
        'adminUserId': adminUserId,
        'adminName': adminName,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[RING_MOD] Log kaydı hatası: $e');
    }
  }

  /// Pending fotoğrafları getir (admin paneli için)
  static Stream<List<Map<String, dynamic>>> getPendingPhotos() {
    return FirebaseFirestore.instance
        .collection(_pendingPhotosCollection)
        .where('status', isEqualTo: 'pending')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Onaylanmış fotoğrafları getir
  static Stream<List<Map<String, dynamic>>> getApprovedPhotos() {
    return FirebaseFirestore.instance
        .collection(_approvedPhotosCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Moderasyon geçmişini getir
  static Stream<List<Map<String, dynamic>>> getModerationLog() {
    return FirebaseFirestore.instance
        .collection(_moderationLogCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Belirli bir üniversiteye ait pending fotoğrafları getir
  static Future<List<Map<String, dynamic>>> getPendingPhotosForUniversity(String universityName) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_pendingPhotosCollection)
          .where('universityName', isEqualTo: universityName)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[RING_MOD] Üniversite pending fotoğrafları getirme hatası: $e');
      return [];
    }
  }
}
