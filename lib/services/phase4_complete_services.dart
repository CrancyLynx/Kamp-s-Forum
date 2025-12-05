// lib/services/phase4_complete_services.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/phase4_complete_models.dart';

// ============================================================
// PHASE 4 SERVICES - Advanced Features
// ============================================================

class CacheService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'cache_entries';
  final Map<String, CacheEntry> _localCache = {};

  Future<CacheEntry?> getCacheEntry(String id) async {
    try {
      // Check local cache first
      if (_localCache.containsKey(id)) {
        final entry = _localCache[id]!;
        if (!entry.isExpired) {
          return entry;
        } else {
          _localCache.remove(id);
        }
      }

      // Fetch from Firestore
      final DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        final entry = CacheEntry.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id});
        if (!entry.isExpired) {
          _localCache[id] = entry;
          return entry;
        } else {
          await deleteCacheEntry(id);
        }
      }
      return null;
    } catch (e) {
      print('Error getting cache entry: $e');
      return null;
    }
  }

  Future<void> setCacheEntry(CacheEntry entry) async {
    try {
      _localCache[entry.id] = entry;
      await _firestore.collection(_collection).doc(entry.id).set(entry.toJson());
    } catch (e) {
      print('Error setting cache entry: $e');
    }
  }

  Future<void> deleteCacheEntry(String id) async {
    try {
      _localCache.remove(id);
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      print('Error deleting cache entry: $e');
    }
  }

  Future<void> clearExpiredEntries() async {
    try {
      final now = DateTime.now();
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('expiresAt', isLessThan: now)
          .get();

      for (var doc in snapshot.docs) {
        await _firestore.collection(_collection).doc(doc.id).delete();
        _localCache.remove(doc.id);
      }
    } catch (e) {
      print('Error clearing expired entries: $e');
    }
  }

  void clearLocalCache() {
    _localCache.clear();
  }
}

// ============================================================
// AI RECOMMENDATION SERVICE
// ============================================================
class AIRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'ai_recommendations';

  Future<void> saveRecommendation(AIRecommendation recommendation) async {
    try {
      await _firestore.collection(_collection).doc(recommendation.id).set(recommendation.toJson());
    } catch (e) {
      print('Error saving recommendation: $e');
    }
  }

  Future<List<AIRecommendation>> getUserRecommendations(String userId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('userAccepted', isEqualTo: false)
          .orderBy('confidenceScore', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AIRecommendation.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching recommendations: $e');
      return [];
    }
  }

  Future<void> acceptRecommendation(String recommendationId) async {
    try {
      await _firestore.collection(_collection).doc(recommendationId).update({'userAccepted': true});
    } catch (e) {
      print('Error accepting recommendation: $e');
    }
  }

  Future<List<AIRecommendation>> getHighConfidenceRecommendations(String userId, double minConfidence) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('confidenceScore', isGreaterThanOrEqualTo: minConfidence)
          .orderBy('confidenceScore', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AIRecommendation.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching high confidence recommendations: $e');
      return [];
    }
  }
}

// ============================================================
// ANALYTICS SERVICE
// ============================================================
class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'analytics_events';

  Future<void> logEvent(AnalyticsEvent event) async {
    try {
      await _firestore.collection(_collection).doc(event.id).set(event.toJson());
    } catch (e) {
      print('Error logging analytics event: $e');
    }
  }

  Future<List<AnalyticsEvent>> getUserEvents(String userId, {int limit = 100}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AnalyticsEvent.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching user events: $e');
      return [];
    }
  }

  Future<List<AnalyticsEvent>> getScreenEvents(String screenName, {int limit = 100}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('screenName', isEqualTo: screenName)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AnalyticsEvent.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching screen events: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getAnalyticsSummary(DateTime startDate, DateTime endDate) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .get();

      int totalEvents = snapshot.docs.length;
      Set<String> uniqueUsers = {};
      Set<String> screens = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        uniqueUsers.add(data['userId'] ?? '');
        screens.add(data['screenName'] ?? '');
      }

      return {
        'totalEvents': totalEvents,
        'uniqueUsers': uniqueUsers.length,
        'screens': screens.length,
        'dateRange': {'start': startDate, 'end': endDate},
      };
    } catch (e) {
      print('Error getting analytics summary: $e');
      return {};
    }
  }
}

// ============================================================
// USER ENGAGEMENT SERVICE
// ============================================================
class UserEngagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'user_engagement_metrics';

  Future<UserEngagementMetric?> getUserMetrics(String userId) async {
    try {
      final DocumentSnapshot doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        return UserEngagementMetric.fromJson({...doc.data() as Map<String, dynamic>, 'userId': doc.id});
      }
      return null;
    } catch (e) {
      print('Error fetching user metrics: $e');
      return null;
    }
  }

  Future<void> updateEngagementMetrics(String userId, {
    int? postCount,
    int? commentCount,
    int? likeCount,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (postCount != null) updates['postCount'] = FieldValue.increment(postCount);
      if (commentCount != null) updates['commentCount'] = FieldValue.increment(commentCount);
      if (likeCount != null) updates['likeCount'] = FieldValue.increment(likeCount);
      updates['lastActiveAt'] = DateTime.now().toIso8601String();

      await _firestore.collection(_collection).doc(userId).update(updates);
    } catch (e) {
      print('Error updating engagement metrics: $e');
    }
  }

  Future<List<UserEngagementMetric>> getTopEngagedUsers({int limit = 50}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .orderBy('engagementScore', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => UserEngagementMetric.fromJson({...doc.data() as Map<String, dynamic>, 'userId': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching top engaged users: $e');
      return [];
    }
  }

  Future<void> updateUserSegment(String userId, String segment) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({'userSegment': segment});
    } catch (e) {
      print('Error updating user segment: $e');
    }
  }
}

// ============================================================
// SYSTEM PERFORMANCE SERVICE
// ============================================================
class SystemPerformanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'system_performance_metrics';

  Future<void> recordMetric(SystemPerformanceMetric metric) async {
    try {
      await _firestore.collection(_collection).doc(metric.id).set(metric.toJson());
    } catch (e) {
      print('Error recording performance metric: $e');
    }
  }

  Future<List<SystemPerformanceMetric>> getRecentMetrics({int limit = 100}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SystemPerformanceMetric.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching performance metrics: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getPerformanceStats(DateTime startDate, DateTime endDate) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .get();

      if (snapshot.docs.isEmpty) return {};

      double avgCpu = 0, avgMemory = 0, avgStorage = 0, avgResponseTime = 0;
      int maxErrors = 0;

      for (var doc in snapshot.docs) {
        final metric = SystemPerformanceMetric.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id});
        avgCpu += metric.cpuUsage;
        avgMemory += metric.memoryUsage;
        avgStorage += metric.storageUsage;
        avgResponseTime += metric.apiResponseTime;
        maxErrors = metric.errorCount > maxErrors ? metric.errorCount : maxErrors;
      }

      int count = snapshot.docs.length;
      return {
        'avgCpuUsage': avgCpu / count,
        'avgMemoryUsage': avgMemory / count,
        'avgStorageUsage': avgStorage / count,
        'avgResponseTime': avgResponseTime / count,
        'maxErrors': maxErrors,
        'metricsCount': count,
      };
    } catch (e) {
      print('Error getting performance stats: $e');
      return {};
    }
  }
}

// ============================================================
// SECURITY ALERT SERVICE
// ============================================================
class SecurityAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'security_alerts';

  Future<void> createAlert(SecurityAlert alert) async {
    try {
      await _firestore.collection(_collection).doc(alert.id).set(alert.toJson());
    } catch (e) {
      print('Error creating security alert: $e');
    }
  }

  Future<List<SecurityAlert>> getUnresolvedAlerts() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isResolved', isEqualTo: false)
          .orderBy('detectedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SecurityAlert.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching unresolved alerts: $e');
      return [];
    }
  }

  Future<List<SecurityAlert>> getAlertsBySeverity(String severity) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('severity', isEqualTo: severity)
          .orderBy('detectedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SecurityAlert.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching alerts by severity: $e');
      return [];
    }
  }

  Future<void> resolveAlert(String alertId, String resolutionNotes) async {
    try {
      await _firestore.collection(_collection).doc(alertId).update({
        'isResolved': true,
        'resolutionNotes': resolutionNotes,
      });
    } catch (e) {
      print('Error resolving alert: $e');
    }
  }
}

// ============================================================
// CONTENT MODERATION QUEUE SERVICE
// ============================================================
class ModerationQueueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'moderation_queue';

  Future<void> addToQueue(ModerationQueueItem item) async {
    try {
      await _firestore.collection(_collection).doc(item.id).set(item.toJson());
    } catch (e) {
      print('Error adding to moderation queue: $e');
    }
  }

  Future<List<ModerationQueueItem>> getPendingItems({int limit = 50}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ModerationQueueItem.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching pending moderation items: $e');
      return [];
    }
  }

  Future<void> approveContent(String itemId, String moderatorNotes) async {
    try {
      await _firestore.collection(_collection).doc(itemId).update({
        'status': 'approved',
        'decision': 'approved',
        'moderatorNotes': moderatorNotes,
      });
    } catch (e) {
      print('Error approving content: $e');
    }
  }

  Future<void> rejectContent(String itemId, String reason, String moderatorNotes) async {
    try {
      await _firestore.collection(_collection).doc(itemId).update({
        'status': 'rejected',
        'decision': 'rejected',
        'reportReason': reason,
        'moderatorNotes': moderatorNotes,
      });
    } catch (e) {
      print('Error rejecting content: $e');
    }
  }

  Future<Map<String, dynamic>> getModerationStats() async {
    try {
      final pendingSnapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      final approvedSnapshot = await _firestore
          .collection(_collection)
          .where('decision', isEqualTo: 'approved')
          .count()
          .get();

      final rejectedSnapshot = await _firestore
          .collection(_collection)
          .where('decision', isEqualTo: 'rejected')
          .count()
          .get();

      return {
        'pending': pendingSnapshot.count,
        'approved': approvedSnapshot.count,
        'rejected': rejectedSnapshot.count,
      };
    } catch (e) {
      print('Error getting moderation stats: $e');
      return {};
    }
  }
}
