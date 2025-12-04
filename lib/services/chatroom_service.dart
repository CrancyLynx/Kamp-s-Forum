import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chatroom_model.dart';

class ChatRoomService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ChatRoom CRUD Operations

  /// Yeni ChatRoom olustur
  static Future<String?> createChatRoom({
    required String adi,
    required String aciklama,
    required String createdByUserId,
    required String createdByName,
    required bool isPublic,
    required String kategori,
  }) async {
    try {
      final roomRef = _firestore.collection('chat_rooms').doc();
      final roomId = roomRef.id;

      await roomRef.set({
        'adi': adi,
        'aciklama': aciklama,
        'createdByUserId': createdByUserId,
        'createdByName': createdByName,
        'olusturmaTarihi': Timestamp.now(),
        'uyeIds': [createdByUserId],
        'moderatorIds': [createdByUserId],
        'isPublic': isPublic,
        'kategori': kategori,
        'uyeSayisi': 1,
        'sonMesajZamani': Timestamp.now(),
        'sonMesaj': null,
        'ismuted': false,
        'aranan': true,
      });

      // Uyeler subcollection'ine oluşturucuyu ekle
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('uyeler')
          .doc(createdByUserId)
          .set({
        'userName': createdByName,
        'userProfilePhotoUrl': '',
        'katılımZamani': Timestamp.now(),
        'aktif': true,
        'susturuldu': false,
      });

      debugPrint('[CHATROOM] Yeni ChatRoom olusturuldu: $roomId');
      return roomId;
    } catch (e) {
      debugPrint('[CHATROOM] ChatRoom olusturma hatasi: $e');
      return null;
    }
  }

  /// ChatRoom detaylarini getir
  static Future<ChatRoom?> getChatRoom(String roomId) async {
    try {
      final doc = await _firestore.collection('chat_rooms').doc(roomId).get();
      if (doc.exists) {
        return ChatRoom.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('[CHATROOM] ChatRoom getirme hatasi: $e');
      return null;
    }
  }

  /// ChatRoom stream'i (real-time)
  static Stream<ChatRoom?> getChatRoomStream(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return ChatRoom.fromFirestore(doc);
      }
      return null;
    });
  }

  // Message Operations

  /// Mesaj gönder
  static Future<String?> sendMessage({
    required String roomId,
    required String userId,
    required String userName,
    required String userProfilePhotoUrl,
    required String mesaj,
  }) async {
    try {
      final messageRef =
          _firestore.collection('chat_rooms').doc(roomId).collection('mesajlar').doc();
      final messageId = messageRef.id;

      await messageRef.set({
        'roomId': roomId,
        'userId': userId,
        'userName': userName,
        'userProfilePhotoUrl': userProfilePhotoUrl,
        'mesaj': mesaj,
        'reactions': [],
        'gondermeZamani': Timestamp.now(),
        'silindi': false,
        'silindiyenId': null,
        'editlendi': null,
        'isPinned': false,
      });

      // ChatRoom'u güncelle (son mesaj)
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'sonMesajZamani': Timestamp.now(),
        'sonMesaj': mesaj.length > 50 ? '${mesaj.substring(0, 50)}...' : mesaj,
      });

      debugPrint('[CHATROOM] Mesaj gönderildi: $messageId -> Room $roomId');
      return messageId;
    } catch (e) {
      debugPrint('[CHATROOM] Mesaj gönderme hatasi: $e');
      return null;
    }
  }

  /// Mesaj sil
  static Future<bool> deleteMessage(String roomId, String messageId, String deletedByUserId) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('mesajlar')
          .doc(messageId)
          .update({
        'silindi': true,
        'silindiyenId': deletedByUserId,
        'mesaj': '[Silinmiş mesaj]',
      });

      debugPrint('[CHATROOM] Mesaj silindi: $messageId');
      return true;
    } catch (e) {
      debugPrint('[CHATROOM] Mesaj silme hatasi: $e');
      return false;
    }
  }

  /// Mesajlari getir (stream)
  static Stream<List<ChatRoomMessage>> getMessages(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('mesajlar')
        .orderBy('gondermeZamani', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatRoomMessage.fromFirestore(doc))
            .toList());
  }

  /// Emoji reaction ekle
  static Future<bool> addReaction(
    String roomId,
    String messageId,
    String emoji,
  ) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('mesajlar')
          .doc(messageId)
          .update({
        'reactions': FieldValue.arrayUnion([emoji]),
      });

      return true;
    } catch (e) {
      debugPrint('[CHATROOM] Reaction ekleme hatasi: $e');
      return false;
    }
  }

  // Member Operations

  /// ChatRoom'a üye ekle
  static Future<bool> addMember(
    String roomId,
    String userId,
    String userName,
    String userProfilePhotoUrl,
  ) async {
    try {
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'uyeIds': FieldValue.arrayUnion([userId]),
        'uyeSayisi': FieldValue.increment(1),
      });

      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('uyeler')
          .doc(userId)
          .set({
        'userName': userName,
        'userProfilePhotoUrl': userProfilePhotoUrl,
        'katılımZamani': Timestamp.now(),
        'aktif': true,
        'susturuldu': false,
      });

      debugPrint('[CHATROOM] Üye eklendi: $userId -> Room $roomId');
      return true;
    } catch (e) {
      debugPrint('[CHATROOM] Üye ekleme hatasi: $e');
      return false;
    }
  }

  /// ChatRoom'dan üyeyi çıkar
  static Future<bool> removeMember(String roomId, String userId) async {
    try {
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'uyeIds': FieldValue.arrayRemove([userId]),
        'uyeSayisi': FieldValue.increment(-1),
      });

      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('uyeler')
          .doc(userId)
          .delete();

      debugPrint('[CHATROOM] Üye çıkartıldı: $userId -> Room $roomId');
      return true;
    } catch (e) {
      debugPrint('[CHATROOM] Üye çıkartma hatasi: $e');
      return false;
    }
  }

  /// Üyeleri getir (stream)
  static Stream<List<ChatRoomMember>> getMembers(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('uyeler')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatRoomMember.fromFirestore(doc))
            .toList());
  }

  /// Üyeyi sustur
  static Future<bool> muteMember(String roomId, String userId) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('uyeler')
          .doc(userId)
          .update({'susturuldu': true});

      return true;
    } catch (e) {
      debugPrint('[CHATROOM] Üye susturma hatasi: $e');
      return false;
    }
  }

  /// Üyeyi susturmayı kaldır
  static Future<bool> unmuteMember(String roomId, String userId) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('uyeler')
          .doc(userId)
          .update({'susturuldu': false});

      return true;
    } catch (e) {
      debugPrint('[CHATROOM] Üye susturma kaldırma hatasi: $e');
      return false;
    }
  }

  // Discovery & Search

  /// Tüm public ChatRooms'ları getir
  static Stream<List<ChatRoom>> getPublicRooms() {
    return _firestore
        .collection('chat_rooms')
        .where('isPublic', isEqualTo: true)
        .where('aranan', isEqualTo: true)
        .orderBy('uyeSayisi', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatRoom.fromFirestore(doc))
            .toList());
  }

  /// Kategoriye gore ChatRooms'ları getir
  static Stream<List<ChatRoom>> getRoomsByCategory(String kategori) {
    return _firestore
        .collection('chat_rooms')
        .where('kategori', isEqualTo: kategori)
        .where('isPublic', isEqualTo: true)
        .orderBy('uyeSayisi', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatRoom.fromFirestore(doc))
            .toList());
  }

  /// Kullanicinin katilmasi ChatRooms'ları getir
  static Stream<List<ChatRoom>> getUserRooms(String userId) {
    return _firestore
        .collection('chat_rooms')
        .where('uyeIds', arrayContains: userId)
        .orderBy('sonMesajZamani', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatRoom.fromFirestore(doc))
            .toList());
  }

  /// ChatRoom'u sil
  static Future<bool> deleteRoom(String roomId) async {
    try {
      // Mesajlari sil
      final messages = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('mesajlar')
          .get();

      for (var msg in messages.docs) {
        await msg.reference.delete();
      }

      // Üyeleri sil
      final members = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('uyeler')
          .get();

      for (var member in members.docs) {
        await member.reference.delete();
      }

      // ChatRoom'u sil
      await _firestore.collection('chat_rooms').doc(roomId).delete();

      debugPrint('[CHATROOM] ChatRoom silindi: $roomId');
      return true;
    } catch (e) {
      debugPrint('[CHATROOM] ChatRoom silme hatasi: $e');
      return false;
    }
  }

  // Typing Indicator Operations

  /// Kullanıcının yazma durumunu güncelle
  static Future<bool> setUserTypingStatus({
    required String roomId,
    required String userId,
    required String userName,
    required bool isTyping,
  }) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('typing_indicators')
          .doc(userId)
          .set({
        'userId': userId,
        'userName': userName,
        'typingStartedAt': Timestamp.now(),
        'isTyping': isTyping,
      });
      return true;
    } catch (e) {
      debugPrint('[CHATROOM] Typing status hatasi: $e');
      return false;
    }
  }

  /// Yazma durumunu temizle
  static Future<bool> clearUserTypingStatus(String roomId, String userId) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('typing_indicators')
          .doc(userId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('[CHATROOM] Typing status silme hatasi: $e');
      return false;
    }
  }

  /// Yazma durumlarını stream olarak getir
  static Stream<List<Map<String, dynamic>>> getTypingIndicators(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('typing_indicators')
        .where('isTyping', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data())
          .where((data) {
        final typingStartedAt = data['typingStartedAt'] as Timestamp?;
        if (typingStartedAt == null) return false;
        // 30 saniye timeout
        return DateTime.now().difference(typingStartedAt.toDate()).inSeconds <= 30;
      }).toList();
    });
  }

  // User Presence Operations

  /// Kullanıcının çevrimiçi durumunu güncelle
  static Future<bool> updateUserPresence({
    required String userId,
    required String userName,
    required String userProfilePhotoUrl,
    required bool isOnline,
    required String? currentRoomId,
    required String deviceType,
  }) async {
    try {
      await _firestore
          .collection('user_presence')
          .doc(userId)
          .set({
        'userName': userName,
        'userProfilePhotoUrl': userProfilePhotoUrl,
        'isOnline': isOnline,
        'lastSeenAt': Timestamp.now(),
        'currentRoomId': currentRoomId,
        'deviceType': deviceType,
      });
      return true;
    } catch (e) {
      debugPrint('[CHATROOM] Presence update hatasi: $e');
      return false;
    }
  }

  /// Kullanıcının çevrimiçi durumunu getir
  static Future<Map<String, dynamic>?> getUserPresence(String userId) async {
    try {
      final doc =
          await _firestore.collection('user_presence').doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[CHATROOM] Presence getirme hatasi: $e');
      return null;
    }
  }

  /// Belirtilen odadaki aktif kullanıcıları getir
  static Stream<List<Map<String, dynamic>>> getActiveUsersInRoom(
      String roomId) {
    return _firestore
        .collection('user_presence')
        .where('currentRoomId', isEqualTo: roomId)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {
                'userId': doc.id,
                ...doc.data(),
              })
          .toList();
    });
  }

  /// Odadan çık (presence güncelle)
  static Future<bool> leaveRoom(String userId) async {
    try {
      await _firestore.collection('user_presence').doc(userId).update({
        'currentRoomId': null,
        'lastSeenAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      debugPrint('[CHATROOM] Oda çıkış hatasi: $e');
      return false;
    }
  }

  // Message Reaction Operations

  /// Mesaja reaksiyon ekle
  static Future<bool> addMessageReaction({
    required String roomId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final reactionsRef = _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('mesajlar')
          .doc(messageId)
          .collection('reactions')
          .doc(emoji);

      final existingReaction = await reactionsRef.get();

      if (existingReaction.exists) {
        // Emoji zaten varsa, user ekle
        final userIds = List<String>.from(
            existingReaction.data()?['userIds'] ?? []);
        if (!userIds.contains(userId)) {
          userIds.add(userId);
          await reactionsRef.update({
            'userIds': userIds,
            'count': userIds.length,
          });
        }
      } else {
        // Yeni emoji reaction
        await reactionsRef.set({
          'emoji': emoji,
          'userIds': [userId],
          'count': 1,
          'createdAt': Timestamp.now(),
        });
      }

      debugPrint('[CHATROOM] Reaksiyon eklendi: $emoji');
      return true;
    } catch (e) {
      debugPrint('[CHATROOM] Reaksiyon ekleme hatasi: $e');
      return false;
    }
  }

  /// Mesajdan reaksiyon kaldır
  static Future<bool> removeMessageReaction({
    required String roomId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final reactionsRef = _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('mesajlar')
          .doc(messageId)
          .collection('reactions')
          .doc(emoji);

      final reaction = await reactionsRef.get();

      if (reaction.exists) {
        List<String> userIds =
            List<String>.from(reaction.data()?['userIds'] ?? []);
        userIds.remove(userId);

        if (userIds.isEmpty) {
          // Son reaction silinirse, emoji'yi sil
          await reactionsRef.delete();
        } else {
          await reactionsRef.update({
            'userIds': userIds,
            'count': userIds.length,
          });
        }
      }

      debugPrint('[CHATROOM] Reaksiyon kaldirıldı: $emoji');
      return true;
    } catch (e) {
      debugPrint('[CHATROOM] Reaksiyon kaldırma hatasi: $e');
      return false;
    }
  }

  /// Mesajın reaksiyonlarını getir
  static Stream<List<Map<String, dynamic>>> getMessageReactions(
      String roomId, String messageId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('mesajlar')
        .doc(messageId)
        .collection('reactions')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {
                'emoji': doc.id,
                ...doc.data(),
              })
          .toList();
    });
  }

  /// Reaction sayılarını getir (sadece count)
  static Future<Map<String, int>> getReactionCounts(
      String roomId, String messageId) async {
    try {
      final reactions = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('mesajlar')
          .doc(messageId)
          .collection('reactions')
          .get();

      final counts = <String, int>{};
      for (var doc in reactions.docs) {
        counts[doc.id] = (doc.data()['count'] ?? 0).toInt();
      }

      return counts;
    } catch (e) {
      debugPrint('[CHATROOM] Reaction count hatasi: $e');
      return {};
    }
  }
}
