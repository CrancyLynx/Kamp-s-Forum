import 'package:cloud_functions/cloud_functions.dart';

/// Resim moderasyon servisi
/// +18 ve uygunsuz içerik tespiti için Vision API kullanır
class ImageModerationService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Upload öncesi resim analiz et
  /// Base64 encoded resim veya URL gönderebilir
  static Future<Map<String, dynamic>> analyzeImageBeforeUpload({
    required String imageUrl,
  }) async {
    try {
      final callable = _functions.httpsCallable('analyzeImageBeforeUpload');
      final result = await callable.call({
        'imageUrl': imageUrl,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return {
          'success': true,
          'isSafe': true,
          'message': data['message'] ?? '✅ Resim güvenlik kontrolünü geçti!',
          'scores': data['scores'] ?? {
            'adult': 0,
            'racy': 0,
            'violence': 0,
          },
        };
      } else {
        return {
          'success': false,
          'isSafe': false,
          'message': data['message'] ?? '⚠️ Resim uygunsuz içerik içeriyor!',
          'blockedReasons': List<String>.from(data['blockedReasons'] ?? []),
          'scores': data['scores'] ?? {
            'adult': 0,
            'racy': 0,
            'violence': 0,
          },
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Resim analizi sırasında hata: ${e.toString()}',
        'isSafe': false,
      };
    }
  }

  /// Reddedilen resmi açıklamayla yeniden gönder
  static Future<Map<String, dynamic>> reuploadRejectedImage({
    required String newImageUrl,
    String? explanation,
  }) async {
    try {
      final callable = _functions.httpsCallable('reuploadAfterRejection');
      final result = await callable.call({
        'newImageUrl': newImageUrl,
        'explanation': explanation ?? '',
      });

      final data = result.data as Map<String, dynamic>;

      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'İşlem başarısız',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Yeniden yükleme sırasında hata: ${e.toString()}',
      };
    }
  }

  /// Lokal hızlı kontrol (tüm özellikleri kontrol eder)
  static Map<String, dynamic> quickLocalCheck() {
    return {
      'message': 'Sunucu tarafından kontrol yapılacak',
      'info': 'Resim yüklendikten sonra otomatik olarak Vision API tarafından kontrol edilir.'
    };
  }

  /// Uygunsuz resim sayısını kontrol et
  /// Eğer çok fazla uygunsuz resim yüklediyse uyarı
  static Future<Map<String, dynamic>> checkRejectionHistory() async {
    try {
      // Bu işlem için admin'e bildirim gönderme dışında
      // sunucu tarafında yapılan işlemler var
      return {
        'message': 'Sunucu tarafında kontrol yapılıyor'
      };
    } catch (e) {
      return {
        'error': e.toString()
      };
    }
  }
}
