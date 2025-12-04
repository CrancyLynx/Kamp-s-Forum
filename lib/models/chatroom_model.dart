import 'package:cloud_firestore/cloud_firestore.dart';

/// Canlı Sohbet Odası Modeli
class ChatRoom {
  final String id;
  final String adi;
  final String aciklama;
  final String createdByUserId;
  final String createdByName;
  final DateTime olusturmaTarihi;
  final List<String> uyeIds;
  final List<String> moderatorIds;
  final bool isPublic;
  final String kategori; // "genel", "bolum", "etkinlik", "ozel"
  final int uyeSayisi;
  final DateTime sonMesajZamani;
  final String? sonMesaj; // Preview
  final bool ismuted; // Global mute?
  final bool aranan; // Aranabilir mi?

  ChatRoom({
    required this.id,
    required this.adi,
    required this.aciklama,
    required this.createdByUserId,
    required this.createdByName,
    required this.olusturmaTarihi,
    required this.uyeIds,
    required this.moderatorIds,
    required this.isPublic,
    required this.kategori,
    required this.uyeSayisi,
    required this.sonMesajZamani,
    this.sonMesaj,
    required this.ismuted,
    required this.aranan,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      adi: data['adi'] ?? 'Sohbet Odası',
      aciklama: data['aciklama'] ?? '',
      createdByUserId: data['createdByUserId'] ?? '',
      createdByName: data['createdByName'] ?? 'Sistem',
      olusturmaTarihi: (data['olusturmaTarihi'] as Timestamp?)?.toDate() ?? DateTime.now(),
      uyeIds: List<String>.from(data['uyeIds'] ?? []),
      moderatorIds: List<String>.from(data['moderatorIds'] ?? []),
      isPublic: data['isPublic'] ?? true,
      kategori: data['kategori'] ?? 'genel',
      uyeSayisi: (data['uyeSayisi'] as num?)?.toInt() ?? 0,
      sonMesajZamani: (data['sonMesajZamani'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sonMesaj: data['sonMesaj'],
      ismuted: data['ismuted'] ?? false,
      aranan: data['aranan'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'adi': adi,
      'aciklama': aciklama,
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'olusturmaTarihi': Timestamp.fromDate(olusturmaTarihi),
      'uyeIds': uyeIds,
      'moderatorIds': moderatorIds,
      'isPublic': isPublic,
      'kategori': kategori,
      'uyeSayisi': uyeSayisi,
      'sonMesajZamani': Timestamp.fromDate(sonMesajZamani),
      'sonMesaj': sonMesaj,
      'ismuted': ismuted,
      'aranan': aranan,
    };
  }
}

/// Sohbet Mesajı Modeli
class ChatRoomMessage {
  final String id;
  final String roomId;
  final String userId;
  final String userName;
  final String userProfilePhotoUrl;
  final String mesaj;
  final List<String> reactions; // ['👍', '❤️', '😂']
  final DateTime gondermeZamani;
  final bool silindi;
  final String? silindiyenId; // Kim sildi
  final String? editlendi; // Ne zaman edit edildi
  final bool isPinned;

  ChatRoomMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.userProfilePhotoUrl,
    required this.mesaj,
    required this.reactions,
    required this.gondermeZamani,
    required this.silindi,
    this.silindiyenId,
    this.editlendi,
    required this.isPinned,
  });

  factory ChatRoomMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoomMessage(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Kullanıcı',
      userProfilePhotoUrl: data['userProfilePhotoUrl'] ?? '',
      mesaj: data['mesaj'] ?? '',
      reactions: List<String>.from(data['reactions'] ?? []),
      gondermeZamani: (data['gondermeZamani'] as Timestamp?)?.toDate() ?? DateTime.now(),
      silindi: data['silindi'] ?? false,
      silindiyenId: data['silindiyenId'],
      editlendi: data['editlendi'],
      isPinned: data['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'roomId': roomId,
      'userId': userId,
      'userName': userName,
      'userProfilePhotoUrl': userProfilePhotoUrl,
      'mesaj': mesaj,
      'reactions': reactions,
      'gondermeZamani': Timestamp.fromDate(gondermeZamani),
      'silindi': silindi,
      'silindiyenId': silindiyenId,
      'editlendi': editlendi,
      'isPinned': isPinned,
    };
  }
}

/// Sohbet Odası Üyesi
class ChatRoomMember {
  final String userId;
  final String userName;
  final String userProfilePhotoUrl;
  final DateTime katılımZamani;
  final bool aktif;
  final bool susturuldu; // Mute
  
  ChatRoomMember({
    required this.userId,
    required this.userName,
    required this.userProfilePhotoUrl,
    required this.katılımZamani,
    required this.aktif,
    required this.susturuldu,
  });

  factory ChatRoomMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoomMember(
      userId: doc.id,
      userName: data['userName'] ?? 'Kullanıcı',
      userProfilePhotoUrl: data['userProfilePhotoUrl'] ?? '',
      katılımZamani: (data['katılımZamani'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aktif: data['aktif'] ?? false,
      susturuldu: data['susturuldu'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userName': userName,
      'userProfilePhotoUrl': userProfilePhotoUrl,
      'katılımZamani': Timestamp.fromDate(katılımZamani),
      'aktif': aktif,
      'susturuldu': susturuldu,
    };
  }
}
