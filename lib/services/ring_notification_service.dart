import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RingNotificationService {
  static const String _notificationsCollection = 'bildirimler';

  /// Bir üniversitenin tüm öğrencilerine Ring sefer bilgisi eklendi bildirimi gönder
  static Future<bool> notifyUniversityUsersAboutNewRingInfo({
    required String universityName,
    required String uploaderName,
  }) async {
    try {
      // Üniversiteye ait tüm kullanıcıları bul
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('kullanicilar')
          .where('university', isEqualTo: universityName)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        debugPrint('[RING_NOTIF] ${universityName} için hiçbir kullanıcı bulunamadı');
        return false;
      }

      final batch = FirebaseFirestore.instance.batch();
      final notificationTitle = '🚌 Yeni Ring Sefer Bilgisi';
      final notificationBody = '$universityName için ring/servis tarifesi güncellendi (Üyeler: $uploaderName)';
      final notificationTimestamp = FieldValue.serverTimestamp();

      int notificationCount = 0;

      // Her kullanıcıya bildirim gönder
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;

        // Bildirim belgesini oluştur
        final notificationRef = FirebaseFirestore.instance
            .collection(_notificationsCollection)
            .doc();

        batch.set(notificationRef, {
          'userId': userId,
          'title': notificationTitle,
          'body': notificationBody,
          'type': 'ring_info_update',
          'universiteName': universityName,
          'uploaderName': uploaderName,
          'createdAt': notificationTimestamp,
          'isRead': false,
          'actionUrl': 'map://ring/$universityName',
        });

        notificationCount++;
      }

      // Batch commit
      await batch.commit();
      debugPrint('[RING_NOTIF] $notificationCount kullanıcıya bildirim gönderildi');
      return true;
    } catch (e) {
      debugPrint('[RING_NOTIF] Bildirim gönderme hatası: $e');
      return false;
    }
  }

  /// Fotoğraf onaylandığında uploader'a bildirim gönder
  static Future<bool> notifyUploaderPhotoApproved({
    required String uploaderUserId,
    required String uploaderName,
    required String universityName,
    required String approverName,
  }) async {
    try {
      final notificationRef = FirebaseFirestore.instance.collection(_notificationsCollection).doc();

      await notificationRef.set({
        'userId': uploaderUserId,
        'title': '✅ Fotoğraf Onaylandı',
        'body': 'Yüklediğin $universityName ring/servis fotoğrafı onaylandı! Harika iş çıkardın! 🎉',
        'type': 'ring_photo_approved',
        'universiteName': universityName,
        'approverName': approverName,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'actionUrl': 'map://ring/$universityName',
      });

      debugPrint('[RING_NOTIF] Onay bildirimi gönderildi: $uploaderUserId');
      return true;
    } catch (e) {
      debugPrint('[RING_NOTIF] Onay bildirimi gönderme hatası: $e');
      return false;
    }
  }

  /// Fotoğraf reddedildiğinde uploader'a bildirim gönder
  static Future<bool> notifyUploaderPhotoRejected({
    required String uploaderUserId,
    required String uploaderName,
    required String universityName,
    required String rejectionReason,
    required String approverName,
  }) async {
    try {
      final notificationRef = FirebaseFirestore.instance.collection(_notificationsCollection).doc();

      await notificationRef.set({
        'userId': uploaderUserId,
        'title': '⚠️ Fotoğraf Reddedildi',
        'body': '$universityName için yüklediğin fotoğraf reddedildi. Sebep: $rejectionReason. Lütfen başka bir fotoğraf dene.',
        'type': 'ring_photo_rejected',
        'universiteName': universityName,
        'rejectionReason': rejectionReason,
        'approverName': approverName,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'actionUrl': 'map://ring/$universityName',
      });

      debugPrint('[RING_NOTIF] Red bildirimi gönderildi: $uploaderUserId');
      return true;
    } catch (e) {
      debugPrint('[RING_NOTIF] Red bildirimi gönderme hatası: $e');
      return false;
    }
  }

  /// Sistem yöneticisine pending fotoğraf var bildirimi gönder
  static Future<bool> notifyAdminPendingPhoto({
    required String universityName,
    required String uploaderName,
  }) async {
    try {
      // Admin kullanıcılarını bul
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('kullanicilar')
          .where('role', isEqualTo: 'admin')
          .get();

      if (adminsSnapshot.docs.isEmpty) {
        debugPrint('[RING_NOTIF] Admin bulunamadı');
        return false;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (final adminDoc in adminsSnapshot.docs) {
        final adminId = adminDoc.id;
        final notificationRef = FirebaseFirestore.instance.collection(_notificationsCollection).doc();

        batch.set(notificationRef, {
          'userId': adminId,
          'title': '📋 Yeni Ring Fotoğrafı İncelemesi Bekleniyor',
          'body': '$universityName için $uploaderName tarafından yeni bir ring/servis fotoğrafı yüklendi. Admin panelden inceleyebilirsin.',
          'type': 'pending_ring_photo_admin',
          'universiteName': universityName,
          'uploaderName': uploaderName,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'actionUrl': 'admin://moderation/ring_photos',
        });
      }

      await batch.commit();
      debugPrint('[RING_NOTIF] Tüm adminlere pending fotoğraf bildirimi gönderildi');
      return true;
    } catch (e) {
      debugPrint('[RING_NOTIF] Admin bildirimi gönderme hatası: $e');
      return false;
    }
  }

  /// Bildirimi okundu olarak işaretle
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection(_notificationsCollection)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('[RING_NOTIF] Bildirim okundu işlemesi hatası: $e');
    }
  }

  /// Kullanıcının Ring-ile ilgili bildirimlerini getir
  static Stream<List<Map<String, dynamic>>> getRingNotifications(String userId) {
    return FirebaseFirestore.instance
        .collection(_notificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('type', whereIn: ['ring_info_update', 'ring_photo_approved', 'ring_photo_rejected', 'pending_ring_photo_admin'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
