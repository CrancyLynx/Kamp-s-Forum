import 'package:cloud_functions/cloud_functions.dart';

/// Firebase Cloud Functions'ları çağıran service layer
class CloudFunctionsService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// 👥 Kullanıcıyı takip et
  static Future<bool> followUser(String targetUserId) async {
    try {
      final result = await _functions.httpsCallable('followUser').call({'targetUserId': targetUserId});
      return result.data['success'] ?? false;
    } catch (e) {
      print('❌ Follow hatası: $e');
      rethrow;
    }
  }

  /// ❌ Takipten çıkar
  static Future<bool> unfollowUser(String targetUserId) async {
    try {
      final result = await _functions.httpsCallable('unfollowUser').call({'targetUserId': targetUserId});
      return result.data['success'] ?? false;
    } catch (e) {
      print('❌ Unfollow hatası: $e');
      rethrow;
    }
  }

  /// 👍 Gönderiyi beğen
  static Future<Map<String, dynamic>> likePost(String postId) async {
    try {
      final result = await _functions.httpsCallable('likePost').call({'postId': postId});
      return {
        'success': result.data['success'] ?? false,
        'likeCount': result.data['likeCount'] ?? 0,
        'message': result.data['message'] ?? ''
      };
    } catch (e) {
      print('❌ Like hatası: $e');
      rethrow;
    }
  }

  /// 👎 Beğeniyi kaldır
  static Future<Map<String, dynamic>> unlikePost(String postId) async {
    try {
      final result = await _functions.httpsCallable('unlikePost').call({'postId': postId});
      return {
        'success': result.data['success'] ?? false,
        'likeCount': result.data['likeCount'] ?? 0,
        'message': result.data['message'] ?? ''
      };
    } catch (e) {
      print('❌ Unlike hatası: $e');
      rethrow;
    }
  }

  /// 🚫 Kullanıcıyı engelle
  static Future<bool> blockUser(String targetUserId) async {
    try {
      final result = await _functions.httpsCallable('blockUser').call({'targetUserId': targetUserId});
      return result.data['success'] ?? false;
    } catch (e) {
      print('❌ Block hatası: $e');
      rethrow;
    }
  }

  /// ✅ Engeli kaldır
  static Future<bool> unblockUser(String targetUserId) async {
    try {
      final result = await _functions.httpsCallable('unblockUser').call({'targetUserId': targetUserId});
      return result.data['success'] ?? false;
    } catch (e) {
      print('❌ Unblock hatası: $e');
      rethrow;
    }
  }

  /// 📝 Aktiviteyi kaydet
  static Future<bool> logActivity(String activityType, {String? targetId, String? userAgent}) async {
    try {
      final result = await _functions.httpsCallable('logUserActivity').call({
        'activityType': activityType,
        'targetId': targetId,
        'userAgent': userAgent
      });
      return result.data['success'] ?? false;
    } catch (e) {
      print('⚠️ Aktivite kayıt hatası: $e');
      return false; // Silently fail
    }
  }

  /// 📊 Sayaçları yenile
  static Future<Map<String, dynamic>> recalculateCounters() async {
    try {
      final result = await _functions.httpsCallable('recalculateUserCounters').call();
      return {
        'success': result.data['success'] ?? false,
        'message': result.data['message'] ?? ''
      };
    } catch (e) {
      print('❌ Sayaç yenileme hatası: $e');
      rethrow;
    }
  }

  /// 🎓 Badge kontrol et ve ver
  static Future<List<String>> checkAndAwardBadges() async {
    try {
      final result = await _functions.httpsCallable('checkAndAwardBadges').call();
      final newBadges = (result.data['newBadges'] as List?)?.cast<String>() ?? [];
      return newBadges;
    } catch (e) {
      print('⚠️ Badge kontrol hatası: $e');
      return [];
    }
  }

  /// 📧 Batch email gönder (Admin only)
  static Future<Map<String, dynamic>> sendBatchEmails({
    required String subject,
    required String body,
    Map<String, dynamic>? recipientFilter,
  }) async {
    try {
      final result = await _functions.httpsCallable('sendBatchEmails').call({
        'subject': subject,
        'body': body,
        'recipientFilter': recipientFilter ?? {}
      });
      return {
        'success': result.data['success'] ?? false,
        'count': result.data['count'] ?? 0,
        'message': result.data['message'] ?? ''
      };
    } catch (e) {
      print('❌ Email gönderme hatası: $e');
      rethrow;
    }
  }

  /// 💡 Kişiselleştirilmiş öneriler al
  static Future<List<Map<String, dynamic>>> getPersonalizedSuggestions() async {
    try {
      final result = await _functions.httpsCallable('generatePersonalizedSuggestions').call();
      final suggestions = (result.data['suggestions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      return suggestions;
    } catch (e) {
      print('⚠️ Öneriler yükleme hatası: $e');
      return [];
    }
  }

  /// 🗃️ Veri migrasyonu çalıştır (Admin only)
  static Future<Map<String, dynamic>> migrateUserData() async {
    try {
      final result = await _functions.httpsCallable('migrateUserData').call();
      return {
        'success': result.data['success'] ?? false,
        'count': result.data['count'] ?? 0,
        'message': result.data['message'] ?? ''
      };
    } catch (e) {
      print('❌ Veri migrasyonu hatası: $e');
      rethrow;
    }
  }

  /// 🗑️ Gönderiyi sil
  static Future<bool> deletePost(String postId) async {
    try {
      final result = await _functions.httpsCallable('deletePost').call({'postId': postId});
      return result.data['success'] ?? false;
    } catch (e) {
      print('❌ Gönderi silme hatası: $e');
      rethrow;
    }
  }

  /// 🗑️ Hesabı sil
  static Future<bool> deleteUserAccount() async {
    try {
      final result = await _functions.httpsCallable('deleteUserAccount').call();
      return result.data['success'] ?? false;
    } catch (e) {
      print('❌ Hesap silme hatası: $e');
      rethrow;
    }
  }
}
