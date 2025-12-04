import 'package:cloud_functions/cloud_functions.dart';

/// İçerik moderasyon servisi
/// Gönderi, yorum, anket ve forum mesajlarının uygunsuz kelime içeriği kontrolünü yapar
class ContentModerationService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// İçerik türleri
  static const String TYPE_POST = 'post';
  static const String TYPE_COMMENT = 'comment';
  static const String TYPE_POLL = 'poll';
  static const String TYPE_FORUM_MESSAGE = 'forum_message';

  /// Gönderi oluştur/düzenle - Moderasyon kontrolü ile
  static Future<Map<String, dynamic>> submitPost({
    required String title,
    required String content,
  }) async {
    try {
      final callable = _functions.httpsCallable('checkAndFixContent');
      final result = await callable.call({
        'contentType': TYPE_POST,
        'title': title,
        'content': content,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return {
          'success': true,
          'message': 'Gönderi başarıyla yayınlandı! ✅',
          'canPublish': true,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'İçeriğiniz uygunsuz kelimeler içeriyor.',
          'foundWords': List<String>.from(data['foundWords'] ?? []),
          'canPublish': false,
          'requiresModeration': true,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Kontrol sırasında hata oluştu: ${e.toString()}',
        'canPublish': false,
      };
    }
  }

  /// Yorum oluştur - Moderasyon kontrolü ile
  static Future<Map<String, dynamic>> submitComment({
    required String text,
    required String postId,
  }) async {
    try {
      final callable = _functions.httpsCallable('checkAndFixContent');
      final result = await callable.call({
        'contentType': TYPE_COMMENT,
        'text': text,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return {
          'success': true,
          'message': 'Yorumunuz başarıyla yayınlandı! ✅',
          'canPublish': true,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Yorumunuz uygunsuz kelimeler içeriyor.',
          'foundWords': List<String>.from(data['foundWords'] ?? []),
          'canPublish': false,
          'requiresModeration': true,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Kontrol sırasında hata oluştu: ${e.toString()}',
        'canPublish': false,
      };
    }
  }

  /// Anket oluştur - Moderasyon kontrolü ile
  static Future<Map<String, dynamic>> submitPoll({
    required String title,
    required String question,
    required List<String> options,
  }) async {
    try {
      final callable = _functions.httpsCallable('checkAndFixContent');
      final result = await callable.call({
        'contentType': TYPE_POLL,
        'title': title,
        'question': question,
        'options': options,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return {
          'success': true,
          'message': 'Anketiniz başarıyla yayınlandı! ✅',
          'canPublish': true,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Anketiniz uygunsuz kelimeler içeriyor.',
          'foundWords': List<String>.from(data['foundWords'] ?? []),
          'canPublish': false,
          'requiresModeration': true,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Kontrol sırasında hata oluştu: ${e.toString()}',
        'canPublish': false,
      };
    }
  }

  /// Forum mesajı gönder - Moderasyon kontrolü ile
  static Future<Map<String, dynamic>> submitForumMessage({
    required String message,
    required String forumId,
  }) async {
    try {
      final callable = _functions.httpsCallable('checkAndFixContent');
      final result = await callable.call({
        'contentType': TYPE_FORUM_MESSAGE,
        'message': message,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return {
          'success': true,
          'message': 'Mesajınız başarıyla gönderildi! ✅',
          'canPublish': true,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Mesajınız uygunsuz kelimeler içeriyor.',
          'foundWords': List<String>.from(data['foundWords'] ?? []),
          'canPublish': false,
          'requiresModeration': true,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Kontrol sırasında hata oluştu: ${e.toString()}',
        'canPublish': false,
      };
    }
  }

  /// Bayraklanmış içeriği düzeltilmiş hali ile yeniden gönder
  static Future<Map<String, dynamic>> resubmitModeratedContent({
    required String contentType,
    required String contentId,
    required String updatedText,
  }) async {
    try {
      final callable = _functions.httpsCallable('resubmitModeratedContent');
      final result = await callable.call({
        'contentType': contentType,
        'contentId': contentId,
        'updatedText': updatedText,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'İçeriğiniz başarıyla yayınlandı! ✅',
          'canPublish': true,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'İçeriğiniz hâlâ uygunsuz kelimeler içeriyor.',
          'foundWords': List<String>.from(data['foundWords'] ?? []),
          'canPublish': false,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Kontrol sırasında hata oluştu: ${e.toString()}',
        'canPublish': false,
      };
    }
  }

  /// Hızlı profanity kontrolü (offline - sunucu kontrolü yapılmadan)
  static Map<String, dynamic> quickLocalCheck(String text) {
    // Basit offline kontrol - gerçek kontrol sunucuda yapılacak
    final turkishBadWords = [
      "orospu", "yıkık", "aptal", "idiot", "sersem", "budala",
      "piç", "bok", "sikeyim", "şerefsiz", "namussuz", "hain"
    ];

    final lowerText = text.toLowerCase();
    final foundWords = <String>[];

    for (final word in turkishBadWords) {
      if (lowerText.contains(word)) {
        foundWords.add(word);
      }
    }

    return {
      'hasProfanity': foundWords.isNotEmpty,
      'foundWords': foundWords,
      'message': foundWords.isNotEmpty
          ? 'İçerinizde uygunsuz kelimeler var: ${foundWords.join(", ")}'
          : 'Kontrol geçti ✅'
    };
  }
}
