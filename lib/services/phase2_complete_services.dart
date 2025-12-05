// lib/services/phase2_complete_services.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/phase2_complete_models.dart';

// ============================================================
// PHASE 2 SERVICES - News, Locations, Emoji, Chat Moderation
// ============================================================

class NewsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'news_articles';

  Future<List<NewsArticle>> getAllNews() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .orderBy('publishedAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => NewsArticle.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching news: $e');
      return [];
    }
  }

  Future<List<NewsArticle>> getNewsByCategory(String category) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category)
          .orderBy('publishedAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => NewsArticle.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching news by category: $e');
      return [];
    }
  }

  Future<void> addNews(NewsArticle article) async {
    try {
      await _firestore.collection(_collection).doc(article.id).set(article.toJson());
    } catch (e) {
      print('Error adding news: $e');
    }
  }

  Future<void> toggleBookmark(String articleId, bool isBookmarked) async {
    try {
      await _firestore.collection(_collection).doc(articleId).update({'isBookmarked': isBookmarked});
    } catch (e) {
      print('Error toggling bookmark: $e');
    }
  }

  Future<void> updateViews(String articleId) async {
    try {
      final docRef = _firestore.collection(_collection).doc(articleId);
      await docRef.update({'views': FieldValue.increment(1)});
    } catch (e) {
      print('Error updating views: $e');
    }
  }
}

// ============================================================
// LOCATION SERVICE
// ============================================================
class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'location_markers';

  Future<List<LocationMarker>> getAllLocations() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => LocationMarker.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching locations: $e');
      return [];
    }
  }

  Future<List<LocationMarker>> getLocationsByCategory(String category) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category)
          .get();
      
      return snapshot.docs
          .map((doc) => LocationMarker.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching locations by category: $e');
      return [];
    }
  }

  Future<void> addLocation(LocationMarker location) async {
    try {
      await _firestore.collection(_collection).doc(location.id).set(location.toJson());
    } catch (e) {
      print('Error adding location: $e');
    }
  }

  Future<void> updateLocation(LocationMarker location) async {
    try {
      await _firestore.collection(_collection).doc(location.id).update(location.toJson());
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  Future<void> rateLocation(String locationId, double rating) async {
    try {
      await _firestore.collection(_collection).doc(locationId).update({'rating': rating});
    } catch (e) {
      print('Error rating location: $e');
    }
  }
}

// ============================================================
// EMOJI/STICKER PACK SERVICE
// ============================================================
class EmojiStickerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'emoji_sticker_packs';

  Future<List<EmojiStickerPack>> getAllPacks() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .orderBy('downloads', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => EmojiStickerPack.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching emoji packs: $e');
      return [];
    }
  }

  Future<List<EmojiStickerPack>> getPacksByCategory(String category) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category)
          .get();
      
      return snapshot.docs
          .map((doc) => EmojiStickerPack.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching packs by category: $e');
      return [];
    }
  }

  Future<void> addPack(EmojiStickerPack pack) async {
    try {
      await _firestore.collection(_collection).doc(pack.id).set(pack.toJson());
    } catch (e) {
      print('Error adding emoji pack: $e');
    }
  }

  Future<void> incrementDownloads(String packId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(packId)
          .update({'downloads': FieldValue.increment(1)});
    } catch (e) {
      print('Error incrementing downloads: $e');
    }
  }
}

// ============================================================
// CHAT MODERATION SERVICE
// ============================================================
class ChatModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _logsCollection = 'chat_moderation_logs';

  Future<void> logModeratedMessage(ChatModerationLog log) async {
    try {
      await _firestore.collection(_logsCollection).doc(log.messageId).set(log.toJson());
    } catch (e) {
      print('Error logging moderation: $e');
    }
  }

  Future<List<ChatModerationLog>> getModerationLogs(String moderatorId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_logsCollection)
          .where('moderatorId', isEqualTo: moderatorId)
          .orderBy('actionDate', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => ChatModerationLog.fromJson({...doc.data() as Map<String, dynamic>, 'messageId': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching moderation logs: $e');
      return [];
    }
  }

  Future<void> updateModerationStatus(String messageId, String status) async {
    try {
      await _firestore
          .collection(_logsCollection)
          .doc(messageId)
          .update({'status': status});
    } catch (e) {
      print('Error updating moderation status: $e');
    }
  }
}

// ============================================================
// MESSAGE ARCHIVE SERVICE
// ============================================================
class MessageArchiveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'message_archives';

  Future<void> archiveMessage(MessageArchive archive) async {
    try {
      await _firestore.collection(_collection).doc(archive.chatId).set(archive.toJson());
    } catch (e) {
      print('Error archiving message: $e');
    }
  }

  Future<List<MessageArchive>> getArchivedMessages(String chatId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('chatId', isEqualTo: chatId)
          .orderBy('archivedAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => MessageArchive.fromJson({...doc.data() as Map<String, dynamic>, 'chatId': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching archived messages: $e');
      return [];
    }
  }

  Future<void> deleteArchive(String chatId) async {
    try {
      await _firestore.collection(_collection).doc(chatId).delete();
    } catch (e) {
      print('Error deleting archive: $e');
    }
  }
}

// ============================================================
// NOTIFICATION PREFERENCE SERVICE
// ============================================================
class NotificationPreferenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'notification_preferences';

  Future<NotificationPreference?> getUserPreferences(String userId) async {
    try {
      final DocumentSnapshot doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        return NotificationPreference.fromJson({...doc.data() as Map<String, dynamic>, 'userId': doc.id});
      }
      return null;
    } catch (e) {
      print('Error fetching notification preferences: $e');
      return null;
    }
  }

  Future<void> updatePreferences(String userId, NotificationPreference prefs) async {
    try {
      await _firestore.collection(_collection).doc(userId).update(prefs.toJson());
    } catch (e) {
      print('Error updating notification preferences: $e');
    }
  }

  Future<void> enableCategory(String userId, String category) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        final prefs = NotificationPreference.fromJson({...doc.data() as Map<String, dynamic>, 'userId': doc.id});
        final updatedCategories = [...prefs.enabledCategories, category];
        await _firestore.collection(_collection).doc(userId).update({
          'enabledCategories': updatedCategories,
        });
      }
    } catch (e) {
      print('Error enabling notification category: $e');
    }
  }

  Future<void> disableCategory(String userId, String category) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        final prefs = NotificationPreference.fromJson({...doc.data() as Map<String, dynamic>, 'userId': doc.id});
        final updatedCategories = prefs.enabledCategories.where((c) => c != category).toList();
        await _firestore.collection(_collection).doc(userId).update({
          'enabledCategories': updatedCategories,
        });
      }
    } catch (e) {
      print('Error disabling notification category: $e');
    }
  }

  Future<void> setQuietHours(String userId, String startTime, String endTime) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'quietHours': {'start': startTime, 'end': endTime},
      });
    } catch (e) {
      print('Error setting quiet hours: $e');
    }
  }
}
