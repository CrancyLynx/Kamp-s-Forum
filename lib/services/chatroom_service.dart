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
}
