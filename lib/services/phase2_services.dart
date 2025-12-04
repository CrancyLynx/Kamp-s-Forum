import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/phase2_models.dart';
import '../models/emoji_sticker_model.dart' as emoji_model;

/// NEWS SERVICE
class NewsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Haber yayınla
  static Future<String> publishNews(News news) async {
    try {
      final docRef = await _firestore.collection('haberler').add(news.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Haber yayınlama hatası: $e');
    }
  }

  /// Haberi güncelle
  static Future<void> updateNews(String newsId, News news) async {
    try {
      await _firestore.collection('haberler').doc(newsId).update(news.toFirestore());
    } catch (e) {
      throw Exception('Haber güncelleme hatası: $e');
    }
  }

  /// Haberi sil
  static Future<void> deleteNews(String newsId) async {
    try {
      await _firestore.collection('haberler').doc(newsId).delete();
    } catch (e) {
      throw Exception('Haber silme hatası: $e');
    }
  }

  /// Tüm haberler (aktif)
  static Stream<List<News>> getActiveNews() {
    return _firestore
        .collection('haberler')
        .where('isPublished', isEqualTo: true)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => News.fromFirestore(doc))
            .toList());
  }

  /// Kategoriye göre haberler
  static Stream<List<News>> getNewsByCategory(String category) {
    return _firestore
        .collection('haberler')
        .where('category', isEqualTo: category)
        .where('isPublished', isEqualTo: true)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => News.fromFirestore(doc))
            .toList());
  }

  /// Sabitlenmiş haberler
  static Stream<List<News>> getPinnedNews() {
    return _firestore
        .collection('haberler')
        .where('isPinned', isEqualTo: true)
        .where('isPublished', isEqualTo: true)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => News.fromFirestore(doc))
            .toList());
  }

  /// Haber sabitleme
  static Future<void> pinNews(String newsId, bool isPinned) async {
    try {
      await _firestore.collection('haberler').doc(newsId).update({
        'isPinned': isPinned,
      });
    } catch (e) {
      throw Exception('Haber sabitleme hatası: $e');
    }
  }
}

/// EMOJI & STICKER SERVICE
class EmojiStickerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Emoji paketi getir
  static Stream<List<EmojiPack>> getEmojiPacks() {
    return _firestore
        .collection('emoji_packs')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmojiPack.fromFirestore(doc))
            .toList());
  }

  /// Paket emoji'leri getir
  static Stream<List<dynamic>> getEmojisByPack(String packId) {
    return _firestore
        .collection('emoji_packs')
        .doc(packId)
        .collection('emojis')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => emoji_model.Emoji.fromMap(doc.data()))
            .toList());
  }

  /// Emoji reaction ekle
  static Future<String> addEmojiReaction({
    required String messageId,
    required String emoji,
    required String userId,
  }) async {
    try {
      final docRef = await _firestore
          .collection('messages')
          .doc(messageId)
          .collection('reactions')
          .add({
            'emoji': emoji,
            'userId': userId,
            'addedAt': Timestamp.now(),
          });
      return docRef.id;
    } catch (e) {
      throw Exception('Emoji reaction ekleme hatası: $e');
    }
  }

  /// Mesaj reactions
  static Stream<List<emoji_model.EmojiReaction>> getMessageReactions(String messageId) {
    return _firestore
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => emoji_model.EmojiReaction.fromFirestore(doc))
            .toList());
  }

  /// Reaction kaldır
  static Future<void> removeEmojiReaction(String messageId, String reactionId) async {
    try {
      await _firestore
          .collection('messages')
          .doc(messageId)
          .collection('reactions')
          .doc(reactionId)
          .delete();
    } catch (e) {
      throw Exception('Reaction kaldırma hatası: $e');
    }
  }
}

/// LOCATION MARKER SERVICE
class LocationMarkerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Konum işareti ekle
  static Future<String> addLocationMarker(LocationMarker marker) async {
    try {
      final docRef = await _firestore.collection('location_markers').add(marker.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Konum işareti ekleme hatası: $e');
    }
  }

  /// Konum işaretini güncelle
  static Future<void> updateLocationMarker(String markerId, LocationMarker marker) async {
    try {
      await _firestore.collection('location_markers').doc(markerId).update(marker.toFirestore());
    } catch (e) {
      throw Exception('Konum işareti güncelleme hatası: $e');
    }
  }

  /// Konum işaretini sil
  static Future<void> deleteLocationMarker(String markerId) async {
    try {
      await _firestore.collection('location_markers').doc(markerId).delete();
    } catch (e) {
      throw Exception('Konum işareti silme hatası: $e');
    }
  }

  /// Tüm işaretler
  static Stream<List<LocationMarker>> getAllMarkers() {
    return _firestore
        .collection('location_markers')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationMarker.fromFirestore(doc))
            .toList());
  }

  /// Kategoriye göre işaretler
  static Stream<List<LocationMarker>> getMarkersByCategory(String category) {
    return _firestore
        .collection('location_markers')
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationMarker.fromFirestore(doc))
            .toList());
  }

  /// İkon tipine göre işaretler (getMarkersByType alias)
  static Stream<List<LocationMarker>> getMarkersByType(String iconType) {
    return _firestore
        .collection('location_markers')
        .where('iconType', isEqualTo: iconType)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationMarker.fromFirestore(doc))
            .toList());
  }

  /// Üniversiteye göre işaretler
  static Stream<List<LocationMarker>> getMarkersByUniversity(String university) {
    return _firestore
        .collection('location_markers')
        .where('university', isEqualTo: university)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationMarker.fromFirestore(doc))
            .toList());
  }

  /// Belirli bir alandaki işaretler (jeospatial query)
  static Future<List<LocationMarker>> getMarkersNearby(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) async {
    try {
      // Basit dikdörtgen query (tam jeospatial yerine)
      final radiusDegrees = radiusKm / 111.0;
      final snapshot = await _firestore
          .collection('location_markers')
          .where('latitude', isGreaterThan: centerLat - radiusDegrees)
          .where('latitude', isLessThan: centerLat + radiusDegrees)
          .get();

      final results = <LocationMarker>[];
      for (final doc in snapshot.docs) {
        final marker = LocationMarker.fromFirestore(doc);
        // Havacos mesafesi hesapla (Haversine formula)
        final distance = _calculateDistance(centerLat, centerLng, marker.latitude, marker.longitude);
        if (distance <= radiusKm) {
          results.add(marker);
        }
      }
      return results;
    } catch (e) {
      throw Exception('Yakın işaretler alma hatası: $e');
    }
  }

  /// Haversine formula ile mesafe hesapla (km cinsinden)
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371; // Dünya yarıçapı km
    final dLat = (lat2 - lat1) * (3.14159265359 / 180);
    final dLon = (lon2 - lon1) * (3.14159265359 / 180);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(lat1 * (3.14159265359 / 180)) * cos(lat2 * (3.14159265359 / 180)) * sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

// dart:math import eklememeliyiz, basit formula kullanıyoruz

  /// Popüler işaretler (rating'e göre)
  static Future<List<LocationMarker>> getPopularMarkers(int limit) async {
    try {
      final snapshot = await _firestore
          .collection('location_markers')
          .orderBy('averageRating', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => LocationMarker.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Popüler işaretler alma hatası: $e');
    }
  }
}

class EmojiPackService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Emoji paketi ekle
  static Future<String> addEmojiPack(EmojiPack pack) async {
    try {
      final docRef = await _firestore.collection('emoji_packs').add(pack.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Emoji paketi ekleme hatası: $e');
    }
  }

  /// Tüm emoji paketleri
  static Stream<List<EmojiPack>> getAllEmojiPacks() {
    return _firestore
        .collection('emoji_packs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmojiPack.fromFirestore(doc))
            .toList());
  }

  /// Kategoriye göre emoji paketleri
  static Stream<List<EmojiPack>> getEmojiPacksByCategory(String category) {
    return _firestore
        .collection('emoji_packs')
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmojiPack.fromFirestore(doc))
            .toList());
  }

  /// Önerilen emoji paketleri
  static Stream<List<EmojiPack>> getFeaturedEmojiPacks() {
    return _firestore
        .collection('emoji_packs')
        .where('isFeatured', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmojiPack.fromFirestore(doc))
            .toList());
  }

  /// Yeni emoji paketleri
  static Future<List<EmojiPack>> getNewEmojiPacks() async {
    try {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      final snapshot = await _firestore
          .collection('emoji_packs')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneWeekAgo))
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => EmojiPack.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Yeni emoji paketleri alma hatası: $e');
    }
  }
}

class ChatModerationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Moderasyon kuralı ekle
  static Future<String> addModerationRule(ChatModeration rule) async {
    try {
      final docRef = await _firestore.collection('chat_moderation_rules').add(rule.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Moderasyon kuralı ekleme hatası: $e');
    }
  }

  /// Tüm kurallar
  static Stream<List<ChatModeration>> getAllModeratingRules() {
    return _firestore
        .collection('chat_moderation_rules')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatModeration.fromFirestore(doc))
            .toList());
  }

  /// Odaya göre kurallar
  static Stream<List<ChatModeration>> getRulesByRoom(String roomId) {
    return _firestore
        .collection('chat_moderation_rules')
        .where('roomId', isEqualTo: roomId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatModeration.fromFirestore(doc))
            .toList());
  }

  /// Kuralı devre dışı bırak
  static Future<void> deactivateRule(String ruleId) async {
    try {
      await _firestore.collection('chat_moderation_rules').doc(ruleId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Kuralı devre dışı bırakma hatası: $e');
    }
  }
}

class NotificationPreferenceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Bildirim tercihleri kaydet
  static Future<void> saveNotificationPreferences(
    String userId,
    NotificationPreference prefs,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('notifications')
          .set(prefs.toFirestore());
    } catch (e) {
      throw Exception('Bildirim tercihleri kaydetme hatası: $e');
    }
  }

  /// Bildirim tercihlerini al
  static Future<NotificationPreference?> getNotificationPreferences(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('notifications')
          .get();
      
      if (doc.exists) {
        return NotificationPreference.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Bildirim tercihleri alma hatası: $e');
    }
  }

  /// Belirli bir bildirimi tipini etkinleştir/devre dışı bırak
  static Future<void> toggleNotificationType(String userId, String notificationType, bool enabled) async {
    try {
      final prefs = await getNotificationPreferences(userId);
      if (prefs != null) {
        final updatedChannels = <String>[...prefs.enabledChannels];
        if (enabled) {
          if (!updatedChannels.contains(notificationType)) {
            updatedChannels.add(notificationType);
          }
        } else {
          updatedChannels.remove(notificationType);
        }
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('preferences')
            .doc('notifications')
            .update({
              'enabledChannels': updatedChannels,
            });
      }
    } catch (e) {
      throw Exception('Bildirim tipi açma/kapatma hatası: $e');
    }
  }

  /// Saati aralığında bildirim gönder
  static Future<void> setQuietHours(String userId, String startTime, String endTime) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('notifications')
          .update({
            'quietHoursStart': startTime,
            'quietHoursEnd': endTime,
          });
    } catch (e) {
      throw Exception('Sakin saat ayarlama hatası: $e');
    }
  }
}

class MessageArchiveService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mesajı arşivle
  static Future<void> archiveMessage(String messageId) async {
    try {
      await _firestore.collection('archived_messages').doc(messageId).set({
        'archivedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Mesaj arşivleme hatası: $e');
    }
  }

  /// Arşivlenmiş mesajları al
  static Stream<List<Map<String, dynamic>>> getArchivedMessages(String userId) {
    return _firestore
        .collection('archived_messages')
        .orderBy('archivedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Mesajı arşivden çıkar
  static Future<void> unarchiveMessage(String messageId) async {
    try {
      await _firestore.collection('archived_messages').doc(messageId).delete();
    } catch (e) {
      throw Exception('Mesaj arşivden çıkarma hatası: $e');
    }
  }

  /// Tüm mesajları arşivle
  static Future<void> archiveAllMessagesInRoom(String roomId) async {
    try {
      final snapshot = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .get();

      for (final doc in snapshot.docs) {
        await archiveMessage(doc.id);
      }
    } catch (e) {
      throw Exception('Odanın tüm mesajlarını arşivleme hatası: $e');
    }
  }
}

class PlaceReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// İnceleme ekle
  static Future<String> addPlaceReview(PlaceReview review) async {
    try {
      final docRef = await _firestore.collection('place_reviews').add(review.toFirestore());
      // Ortalama rating'i güncelle
      _updatePlaceAverageRating(review.placeId);
      return docRef.id;
    } catch (e) {
      throw Exception('İnceleme ekleme hatası: $e');
    }
  }

  /// İncelemeyi güncelle
  static Future<void> updatePlaceReview(String reviewId, PlaceReview review) async {
    try {
      await _firestore.collection('place_reviews').doc(reviewId).update(review.toFirestore());
    } catch (e) {
      throw Exception('İnceleme güncelleme hatası: $e');
    }
  }

  /// İncelemeyi sil
  static Future<void> deletePlaceReview(String reviewId) async {
    try {
      await _firestore.collection('place_reviews').doc(reviewId).delete();
    } catch (e) {
      throw Exception('İnceleme silme hatası: $e');
    }
  }

  /// Mekan incelemelerini al
  static Stream<List<PlaceReview>> getPlaceReviews(String placeId) {
    return _firestore
        .collection('place_reviews')
        .where('placeId', isEqualTo: placeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PlaceReview.fromFirestore(doc))
            .toList());
  }

  /// Yüksek rated incelemeler
  static Future<List<PlaceReview>> getTopRatedReviews(String placeId) async {
    try {
      final snapshot = await _firestore
          .collection('place_reviews')
          .where('placeId', isEqualTo: placeId)
          .orderBy('rating', descending: true)
          .limit(5)
          .get();
      return snapshot.docs.map((doc) => PlaceReview.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Yüksek rated incelemeler alma hatası: $e');
    }
  }

  /// Ortalama rating'i güncelle
  static Future<void> _updatePlaceAverageRating(String placeId) async {
    try {
      final snapshot = await _firestore
          .collection('place_reviews')
          .where('placeId', isEqualTo: placeId)
          .get();

      double totalRating = 0;
      for (final doc in snapshot.docs) {
        totalRating += (doc['rating'] as num).toDouble();
      }

      final averageRating = snapshot.docs.isEmpty ? 0.0 : totalRating / snapshot.docs.length;

      await _firestore.collection('location_markers').doc(placeId).update({
        'averageRating': averageRating,
        'reviewCount': snapshot.docs.length,
      });
    } catch (e) {
      throw Exception('Ortalama rating güncelleme hatası: $e');
    }
  }
}

class UserStatisticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Kullanıcı istatistiklerini al
  static Future<UserStatistics?> getUserStatistics(String userId) async {
    try {
      final doc = await _firestore.collection('user_statistics').doc(userId).get();
      if (doc.exists) {
        return UserStatistics.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Kullanıcı istatistikleri alma hatası: $e');
    }
  }

  /// Post sayısını arttır
  static Future<void> incrementPostCount(String userId) async {
    try {
      await _firestore.collection('user_statistics').doc(userId).update({
        'postsCount': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Post sayısı artırma hatası: $e');
    }
  }

  /// Poll oluşturma sayısını arttır
  static Future<void> incrementPollsCreated(String userId) async {
    try {
      await _firestore.collection('user_statistics').doc(userId).update({
        'pollsCreated': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Poll sayısı artırma hatası: $e');
    }
  }

  /// Son aktiflik zamanını güncelle
  static Future<void> updateLastActiveTime(String userId) async {
    try {
      await _firestore.collection('user_statistics').doc(userId).update({
        'lastActiveAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Son aktiflik güncelleme hatası: $e');
    }
  }

  /// Top istatistikler
  static Future<List<UserStatistics>> getTopUsers(String sortBy, int limit) async {
    try {
      final snapshot = await _firestore
          .collection('user_statistics')
          .orderBy(sortBy, descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => UserStatistics.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Top kullanıcılar alma hatası: $e');
    }
  }
}

class NotificationTemplateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Şablon ekle
  static Future<String> addNotificationTemplate(NotificationTemplate template) async {
    try {
      final docRef = await _firestore.collection('notification_templates').add(template.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Şablon ekleme hatası: $e');
    }
  }

  /// Şablonu güncelle
  static Future<void> updateTemplate(String templateId, NotificationTemplate template) async {
    try {
      await _firestore.collection('notification_templates').doc(templateId).update(template.toFirestore());
    } catch (e) {
      throw Exception('Şablon güncelleme hatası: $e');
    }
  }

  /// Tüm şablonlar
  static Stream<List<NotificationTemplate>> getAllTemplates() {
    return _firestore
        .collection('notification_templates')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationTemplate.fromFirestore(doc))
            .toList());
  }

  /// Bildirim tipine göre şablon
  static Future<NotificationTemplate?> getTemplateByType(String notificationType) async {
    try {
      final snapshot = await _firestore
          .collection('notification_templates')
          .where('notificationType', isEqualTo: notificationType)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return NotificationTemplate.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Şablon alma hatası: $e');
    }
  }
}

class ActivityTimelineService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Aktivite ekle
  static Future<String> addActivity(ActivityTimeline activity) async {
    try {
      final docRef = await _firestore.collection('activity_timeline').add(activity.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Aktivite ekleme hatası: $e');
    }
  }

  /// Kullanıcının aktivite geçmişi
  static Stream<List<ActivityTimeline>> getUserActivityTimeline(String userId) {
    return _firestore
        .collection('activity_timeline')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityTimeline.fromFirestore(doc))
            .toList());
  }

  /// Aktivite tipine göre
  static Stream<List<ActivityTimeline>> getActivityByType(String userId, String activityType) {
    return _firestore
        .collection('activity_timeline')
        .where('userId', isEqualTo: userId)
        .where('activityType', isEqualTo: activityType)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityTimeline.fromFirestore(doc))
            .toList());
  }

  /// Son aktiviteleri al
  static Future<List<ActivityTimeline>> getRecentActivities(int limit) async {
    try {
      final snapshot = await _firestore
          .collection('activity_timeline')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => ActivityTimeline.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Son aktiviteler alma hatası: $e');
    }
  }
}
