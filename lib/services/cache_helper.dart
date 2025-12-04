import 'package:flutter/material.dart';
import 'data_preload_service.dart';

/// Firestore sorguları için ön-yüklenmiş cache kullanımını yapan utility
class CacheHelper {
  /// Eğer cache varsa onu kullan, yoksa sorgu yap
  static Future<dynamic> getWithCache(
    String cacheKey,
    Future<dynamic> Function() firebaseQuery,
  ) async {
    try {
      // Önce cache kontrol et
      final cached = await DataPreloadService.getCachedData(cacheKey);
      if (cached != null) {
        debugPrint('📦 Cache kullanıldı: $cacheKey');
        // Arka planda yeni veriyi getir ve cache'i güncelle
        firebaseQuery().then((fresh) {
          if (fresh != null) {
            DataPreloadService.cacheToDisk(cacheKey, fresh).catchError((e) {
              debugPrint('Cache update hatasi: $e');
            });
          }
        }).catchError((e) {
          debugPrint('Background cache update hatası: $e');
        });
        return cached;
      }

      // Cache yoksa Firestore'dan al
      debugPrint('🔄 Firestore sorgusu yapılıyor: $cacheKey');
      final fresh = await firebaseQuery();
      
      // Sonucu cache'le
      if (fresh != null) {
        await DataPreloadService.cacheToDisk(cacheKey, fresh);
      }
      
      return fresh;
    } catch (e) {
      debugPrint('Cache helper hatası ($cacheKey): $e');
      return null;
    }
  }

  /// Cache'i test etmek için basit fonksiyon
  static Future<bool> isCacheValid(String key) async {
    return await DataPreloadService.isCacheValid(key);
  }

  /// Cache'i temizle
  static Future<void> clearCache({String? key}) async {
    await DataPreloadService.clearCache(key: key);
  }
}
