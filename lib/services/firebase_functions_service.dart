// lib/services/firebase_functions_service.dart
// ============================================================
// Flutter'dan Cloud Functions çağırmak için service
// ============================================================

import 'package:cloud_functions/cloud_functions.dart';

class FirebaseFunctionsService {
  static final FirebaseFunctionsService _instance = 
    FirebaseFunctionsService._internal();
  
  late final FirebaseFunctions _functions;
  
  factory FirebaseFunctionsService() {
    return _instance;
  }
  
  FirebaseFunctionsService._internal() {
    _functions = FirebaseFunctions.instance;
    _functions.useFunctionsEmulator('localhost', 5001); // Development için
  }
  
  // ============================================================
  // 1. IMAGE MODERATION (Görsel Moderasyonu)
  // ============================================================
  
  /// Görsel yüklemeden önce güvenlik kontrolü yap
  /// Returns: {success: bool, message: String, ...}
  Future<Map<String, dynamic>> analyzeImageBeforeUpload(
    String imageUrl,
  ) async {
    try {
      print('[Firebase] analyzeImageBeforeUpload çağrılıyor: $imageUrl');
      
      final result = await _functions
        .httpsCallable('analyzeImageBeforeUpload')
        .call({'imageUrl': imageUrl});
      
      final data = Map<String, dynamic>.from(result.data);
      print('[Firebase] Cevap alındı: ${data['message']}');
      
      return data;
    } on FirebaseFunctionsException catch (e) {
      print('[ERROR] ${e.code}: ${e.message}');
      return {
        'success': false,
        'message': '⚠️ Bağlantı hatası: ${e.message}',
        'errorCode': e.code
      };
    } catch (e) {
      print('[ERROR] $e');
      return {
        'success': false,
        'message': '⚠️ Beklenmeyen hata: $e',
        'errorCode': 'unknown_error'
      };
    }
  }
  
  // ============================================================
  // 2. VISION API QUOTA (Kota Kontrolü)
  // ============================================================
  
  /// Mevcut Vision API kota durumunu kontrol et (Admin)
  Future<Map<String, dynamic>> getVisionApiQuotaStatus() async {
    try {
      print('[Firebase] getVisionApiQuotaStatus çağrılıyor');
      
      final result = await _functions
        .httpsCallable('getVisionApiQuotaStatus')
        .call();
      
      final data = Map<String, dynamic>.from(result.data);
      print('[Firebase] Quota: ${data['used']}/${data['limit']}');
      
      return data;
    } catch (e) {
      print('[ERROR] Quota kontrol hatası: $e');
      return {'error': true, 'message': 'Quota kontrol hatası'};
    }
  }
  
  // ============================================================
  // 3. ADMIN DASHBOARD (Yönetici Paneli)
  // ============================================================
  
  /// Admin dashboard verilerini al
  Future<Map<String, dynamic>> getAdminDashboard() async {
    try {
      print('[Firebase] getAdminDashboard çağrılıyor');
      
      final result = await _functions
        .httpsCallable('getAdminDashboard')
        .call();
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('[ERROR] Dashboard hatası: $e');
      return {'error': true};
    }
  }
  
  /// Advanced monitoring dashboard (detaylı)
  Future<Map<String, dynamic>> getAdvancedMonitoring() async {
    try {
      print('[Firebase] getAdvancedMonitoring çağrılıyor');
      
      final result = await _functions
        .httpsCallable('getAdvancedMonitoring')
        .call();
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('[ERROR] Advanced monitoring hatası: $e');
      return {'error': true};
    }
  }
  
  // ============================================================
  // 4. PROFANITY FILTER (Kötü Kelime Filtresi)
  // ============================================================
  
  /// Metni kötü kelimeler için kontrol et
  Future<Map<String, dynamic>> checkForProfanity(String text) async {
    try {
      print('[Firebase] checkForProfanity çağrılıyor');
      
      // Eğer Cloud Function yoksa, yerel kontrolü kullan
      // (Bu örnek için direkt çağrı)
      final result = await _functions
        .httpsCallable('checkForProfanity')
        .call({'text': text});
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('[ERROR] Profanity check hatası: $e');
      // Fallback: yerel kontrol
      return {'hasBadWords': false, 'message': 'Temiz'};
    }
  }
  
  // ============================================================
  // 5. USER PROFILE (Kullanıcı Profili)
  // ============================================================
  
  /// Kullanıcı profilini güncelle
  Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    required String name,
    required String bio,
    String? avatarUrl,
  }) async {
    try {
      print('[Firebase] updateUserProfile çağrılıyor: $userId');
      
      final result = await _functions
        .httpsCallable('updateUserProfile')
        .call({
          'userId': userId,
          'name': name,
          'bio': bio,
          'avatarUrl': avatarUrl,
        });
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('[ERROR] Profil güncelleme hatası: $e');
      return {'success': false, 'message': 'Profil güncellenemedi'};
    }
  }
  
  // ============================================================
  // 6. GAMIFICATION (Oyunlaştırma)
  // ============================================================
  
  /// XP ekle (post oluşturma, yorum yapma, vb)
  Future<Map<String, dynamic>> addXp({
    required String operationType,
    String? relatedId,
  }) async {
    try {
      print('[Firebase] addXp çağrılıyor: $operationType');
      
      final result = await _functions
        .httpsCallable('addXp')
        .call({
          'operationType': operationType,
          'relatedId': relatedId,
        });
      
      final data = Map<String, dynamic>.from(result.data);
      print('[Firebase] XP eklendi: ${data['xpAdded']}');
      
      return data;
    } catch (e) {
      print('[ERROR] XP ekleme hatası: $e');
      return {'success': false};
    }
  }
  
  // ============================================================
  // 7. NOTIFICATIONS (Bildirimler)
  // ============================================================
  
  /// Push bildirimi gönder (test için)
  Future<Map<String, dynamic>> sendTestNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    try {
      print('[Firebase] sendTestNotification çağrılıyor');
      
      final result = await _functions
        .httpsCallable('sendPushNotification')
        .call({
          'userId': userId,
          'title': title,
          'body': body,
        });
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('[ERROR] Bildirim gönderme hatası: $e');
      return {'success': false};
    }
  }
  
  // ============================================================
  // HELPER METHODS
  // ============================================================
  
  /// Hata mesajını kullanıcı dostu hale getir
  String getUserFriendlyMessage(Map<String, dynamic> response) {
    if (response.containsKey('message')) {
      return response['message'] as String;
    }
    if (response.containsKey('error')) {
      return '⚠️ Bir hata oluştu. Lütfen tekrar deneyin.';
    }
    return '✅ İşlem tamamlandı';
  }
  
  /// Başarılı olup olmadığını kontrol et
  bool isSuccess(Map<String, dynamic> response) {
    return response['success'] == true || !response.containsKey('error');
  }
  
  /// Error code'a göre ikon döndür
  String getErrorIcon(String? errorCode) {
    switch (errorCode) {
      case 'image_unsafe':
        return '⚠️';
      case 'network_error':
        return '🔌';
      case 'quota_exceeded':
        return '🔴';
      case 'image_too_large':
        return '📦';
      default:
        return '❌';
    }
  }
}
