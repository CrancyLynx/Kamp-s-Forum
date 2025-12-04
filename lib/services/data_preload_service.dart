import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Uygulama başlangıcında verileri arka planda önceden yükler ve cache'ler
class DataPreloadService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Tüm kritik verileri paralel olarak preload et
  static Future<Map<String, dynamic>> preloadAllData() async {
    debugPrint('🚀 Data preload başlatıldı...');

    final results = {
      'forum_posts': false,
      'market_products': false,
      'user_profile': false,
      'notifications': false,
      'user_balance': false,
      'leaderboard': false,
      'exam_dates': false,
    };

    try {
      final currentUser = _auth.currentUser;
      
      // Guest kullanıcıysa sadece haber ve kamuya açık verileri yükle
      if (currentUser == null) {
        try {
          await Future.wait([
            _preloadPublicForum(),
            _preloadMarketProducts(),
            _preloadExamDates(),
          ]);
          results['forum_posts'] = true;
          results['market_products'] = true;
          results['exam_dates'] = true;
        } catch (e) {
          debugPrint('❌ Public data preload hatası: $e');
        }
        
        debugPrint('✅ Guest data preload tamamlandı: $results');
        return results;
      }

      // Authenticated kullanıcı - tüm verileri yükle
      final futures = [
        _preloadForumPosts(),
        _preloadMarketProducts(),
        _preloadUserProfile(currentUser.uid),
        _preloadNotifications(currentUser.uid),
        _preloadUserBalance(currentUser.uid),
        _preloadLeaderboard(),
        _preloadExamDates(),
      ];

      final settledResults = await Future.wait(
        futures,
        eagerError: false,
      ).then((_) {
        results['forum_posts'] = true;
        results['market_products'] = true;
        results['user_profile'] = true;
        results['notifications'] = true;
        results['user_balance'] = true;
        results['leaderboard'] = true;
        results['exam_dates'] = true;
        return results;
      }).catchError((e) {
        debugPrint('❌ Bazı veri preload hataları: $e');
        return results;
      });

      debugPrint('✅ Data preload tamamlandı: $settledResults');
      return settledResults;
    } catch (e) {
      debugPrint('❌ Data preload genel hatası: $e');
      return results;
    }
  }

  /// Forum gönderilerini yükle (ilk 30)
  static Future<void> _preloadForumPosts() async {
    try {
      final snapshot = await _firestore
          .collection('gonderiler')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      final data = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      await cacheToDisk('forum_posts', data);
      debugPrint('✅ Forum posts cache (${data.length} posts)');
    } catch (e) {
      debugPrint('❌ Forum posts preload hatası: $e');
      rethrow;
    }
  }

  /// Market ürünlerini yükle (ilk 50)
  static Future<void> _preloadMarketProducts() async {
    try {
      final snapshot = await _firestore
          .collection('urunler')
          .where('kategori', isNotEqualTo: null)
          .limit(50)
          .get();

      final data = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      await cacheToDisk('market_products', data);
      debugPrint('✅ Market products cache (${data.length} products)');
    } catch (e) {
      debugPrint('❌ Market products preload hatası: $e');
      rethrow;
    }
  }

  /// Kullanıcı profilini yükle
  static Future<void> _preloadUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('kullanicilar').doc(userId).get();

      if (doc.exists) {
        final data = {'id': doc.id, ...doc.data() ?? {}};
        await cacheToDisk('user_profile', data);
        debugPrint('✅ User profile cache');
      }
    } catch (e) {
      debugPrint('❌ User profile preload hatası: $e');
      rethrow;
    }
  }

  /// Kullanıcı bildirimlerini yükle (ilk 20)
  static Future<void> _preloadNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('bildirimler')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final data = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      await cacheToDisk('notifications', data);
      debugPrint('✅ Notifications cache (${data.length} notifications)');
    } catch (e) {
      debugPrint('❌ Notifications preload hatası: $e');
      rethrow;
    }
  }

  /// Kullanıcı bakiyesini yükle
  static Future<void> _preloadUserBalance(String userId) async {
    try {
      final doc = await _firestore.collection('kullanicilar').doc(userId).get();

      if (doc.exists) {
        final balance = {
          'coins': doc.data()?['coins'] ?? 0,
          'level': doc.data()?['level'] ?? 1,
          'xp': doc.data()?['xp'] ?? 0,
          'totalUnreadMessages': doc.data()?['totalUnreadMessages'] ?? 0,
          'unreadNotifications': doc.data()?['unreadNotifications'] ?? 0,
        };
        await cacheToDisk('user_balance', balance);
        debugPrint('✅ User balance cache');
      }
    } catch (e) {
      debugPrint('❌ User balance preload hatası: $e');
      rethrow;
    }
  }

  /// Leaderboard'u yükle (ilk 100)
  static Future<void> _preloadLeaderboard() async {
    try {
      final snapshot = await _firestore
          .collection('kullanicilar')
          .orderBy('xp', descending: true)
          .limit(100)
          .get();

      final data = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'username': doc.data()['username'] ?? 'Unknown',
                'xp': doc.data()['xp'] ?? 0,
                'level': doc.data()['level'] ?? 1,
                'profilePhotoUrl': doc.data()['profilePhotoUrl'] ?? '',
              })
          .toList();

      await cacheToDisk('leaderboard', data);
      debugPrint('✅ Leaderboard cache (${data.length} users)');
    } catch (e) {
      debugPrint('❌ Leaderboard preload hatası: $e');
      rethrow;
    }
  }

  /// Sınav tarihlerini yükle
  static Future<void> _preloadExamDates() async {
    try {
      final snapshot = await _firestore
          .collection('sinavlar')
          .orderBy('date', descending: false)
          .limit(100)
          .get();

      final data = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      await cacheToDisk('exam_dates', data);
      debugPrint('✅ Exam dates cache (${data.length} exams)');
    } catch (e) {
      debugPrint('❌ Exam dates preload hatası: $e');
      rethrow;
    }
  }

  /// Public forum gönderilerini yükle (guest için)
  static Future<void> _preloadPublicForum() async {
    try {
      final snapshot = await _firestore
          .collection('gonderiler')
          .where('isPrivate', isNotEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final data = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      await cacheToDisk('forum_posts', data);
      debugPrint('✅ Public forum posts cache (${data.length} posts)');
    } catch (e) {
      debugPrint('❌ Public forum preload hatası: $e');
      rethrow;
    }
  }

  /// Shared Preferences'a veri kaydet
  static Future<void> cacheToDisk(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(data);
      await prefs.setString('cache_$key', jsonData);
      await prefs.setString('cache_${key}_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Cache save error ($key): $e');
    }
  }

  /// Cached veriyi oku
  static Future<dynamic> getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString('cache_$key');
      if (jsonData != null) {
        return jsonDecode(jsonData);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Cache read error ($key): $e');
      return null;
    }
  }

  /// Cache'in geçerli olup olmadığını kontrol et (1 saat)
  static Future<bool> isCacheValid(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString('cache_${key}_timestamp');
      if (timestamp == null) return false;

      final cacheTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diffInMinutes = now.difference(cacheTime).inMinutes;

      return diffInMinutes < 60; // 1 saatlik geçerlilik
    } catch (e) {
      debugPrint('❌ Cache validity check error ($key): $e');
      return false;
    }
  }

  /// Cache'i temizle
  static Future<void> clearCache({String? key}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key != null) {
        await prefs.remove('cache_$key');
        await prefs.remove('cache_${key}_timestamp');
        debugPrint('✅ Cache cleared: $key');
      } else {
        final keys = prefs.getKeys();
        for (final k in keys) {
          if (k.startsWith('cache_')) {
            await prefs.remove(k);
          }
        }
        debugPrint('✅ All cache cleared');
      }
    } catch (e) {
      debugPrint('❌ Cache clear error: $e');
    }
  }
}
