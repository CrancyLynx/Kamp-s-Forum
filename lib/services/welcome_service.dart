import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class WelcomeService {
  static const String _systemUserId = 'sistem_maskot_hosgeldim';
  static const String _systemUserName = 'Kampüs Yardım Asistanı';
  static const String _systemUserAvatar = 'assets/images/duyuru_bay.png';

  /// Sistem maskotu hesabını başlat
  static Future<void> initializeSystemUser() async {
    try {
      final docRef = FirebaseFirestore.instance.collection('sistem_kullanicilar').doc(_systemUserId);
      final doc = await docRef.get();

      if (!doc.exists) {
        // Sistem kullanıcısını oluştur
        await docRef.set({
          'userId': _systemUserId,
          'takmaAd': _systemUserName,
          'ad': 'Sistem',
          'avatarUrl': _systemUserAvatar,
          'email': 'sistem@kampus-yardim.local',
          'rol': 'sistem',
          'aciklama': 'Kampüs Yardım uygulamasında hoşgeldin 👋',
          'createdAt': FieldValue.serverTimestamp(),
          'isSystem': true,
        });
        debugPrint('[SYSTEM] Sistem maskotu kullanıcısı oluşturuldu');
      }
    } catch (e) {
      debugPrint('[SYSTEM] Sistem kullanıcısı başlatılırken hata: $e');
    }
  }

  /// Yeni kullanıcıya hoşgeldin mesajı gönder
  static Future<bool> sendWelcomeMessage(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).get();
      if (!userDoc.exists) return false;

      final userName = userDoc.data()?['takmaAd'] ?? userDoc.data()?['ad'] ?? 'Kullanıcı';

      // Sohbet ID oluştur (sistem + kullanıcı kombinasyonu)
      final chatId = _generateChatId(_systemUserId, userId);

      // Sohbet dokümanını kontrol et, yoksa oluştur
      final chatRef = FirebaseFirestore.instance.collection('sohbetler').doc(chatId);
      final chatDoc = await chatRef.get();

      if (!chatDoc.exists) {
        // Yeni sohbet oluştur
        await chatRef.set({
          'participants': [_systemUserId, userId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageText': 'Hoşgeldin!',
          'user1Id': _systemUserId,
          'user1Name': _systemUserName,
          'user1Avatar': _systemUserAvatar,
          'user2Id': userId,
          'user2Name': userName,
          'user2Avatar': userDoc.data()?['avatarUrl'],
          'unreadCount_$userId': 1,
          'unreadCount_$_systemUserId': 0,
        });

        // Hoşgeldin mesajlarını gönder
        final messages = [
          'Hoşgeldin! 👋',
          'Kampüs Yardım uygulamasında seni görmekten mutluyuz!',
          'Forumda soru sorabilir, diğer öğrencilerle sohbet edebilir ve puan kazanabilirsin.',
          'Herhangi bir sorunun varsa burada benimle iletişime geçebilirsin. 💬',
        ];

        for (int i = 0; i < messages.length; i++) {
          await Future.delayed(Duration(milliseconds: 500 * (i + 1))); // Mesajlar arasında gecikme

          await chatRef.collection('mesajlar').add({
            'senderId': _systemUserId,
            'senderName': _systemUserName,
            'senderAvatar': _systemUserAvatar,
            'message': messages[i],
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'text',
            'replyTo': null,
          });
        }

        // Son mesajı güncelle
        await chatRef.update({
          'lastMessageText': messages.last,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount_$userId': messages.length,
        });

        debugPrint('[WELCOME] Hoşgeldin mesajları gönderildi - userId: $userId');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[WELCOME] Hoşgeldin mesajı gönderilirken hata: $e');
      return false;
    }
  }

  /// Bildirim gönder
  static Future<void> sendWelcomeNotification(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).get();
      if (!userDoc.exists) return;

      // Bildirim oluştur
      await FirebaseFirestore.instance.collection('bildirimler').add({
        'userId': userId,
        'senderId': _systemUserId,
        'senderName': _systemUserName,
        'senderAvatar': _systemUserAvatar,
        'type': 'welcome', // Yeni bildirim türü
        'message': 'Hoşgeldin! Seni görmekten mutluyuz. Chat\'te bir mesaj bekliyorum. 👋',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isSpam': false,
        'title': 'Hoşgeldiniz!',
      });

      debugPrint('[WELCOME] Hoşgeldin bildirimi gönderildi - userId: $userId');
    } catch (e) {
      debugPrint('[WELCOME] Hoşgeldin bildirimi gönderilirken hata: $e');
    }
  }

  /// Sohbet ID'si oluştur (tutarlı, sıra fark etmiyor)
  static String _generateChatId(String userId1, String userId2) {
    final ids = [userId1, userId2];
    ids.sort(); // Tutarlılık için sırala
    return '${ids[0]}_${ids[1]}';
  }

  /// Kullanıcının hoşgeldin mesajını almış olup olmadığını kontrol et
  static Future<bool> hasReceivedWelcome(String userId) async {
    try {
      final chatId = _generateChatId(_systemUserId, userId);
      final chatDoc = await FirebaseFirestore.instance.collection('sohbetler').doc(chatId).get();
      return chatDoc.exists;
    } catch (e) {
      debugPrint('[WELCOME] Hoşgeldin kontrol hatası: $e');
      return false;
    }
  }
}
