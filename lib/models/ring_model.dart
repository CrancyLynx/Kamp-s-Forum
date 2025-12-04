import 'package:cloud_firestore/cloud_firestore.dart';

/// Ring (Ulaşım) Modeli - Kampüs içi yer paylaşımı
class Ring {
  final String id;
  final String createdByUserId;
  final String createdByName;
  final String universitesi;
  final String basKalkisNoktasi; // "Science Park" vs
  final String basVarisNoktasi; // "East Campus" vs
  final String aciklama; // "Bileşke gezinti için yer var"
  final DateTime olusturmaTarihi;
  final bool aktif; // Sefer sürüyor mu?
  final List<String> uyeIds; // Üye user ID'leri
  final Map<String, dynamic> saatProgram; // {"09:00": true, "14:00": false} - düzenli seferler
  
  Ring({
    required this.id,
    required this.createdByUserId,
    required this.createdByName,
    required this.universitesi,
    required this.basKalkisNoktasi,
    required this.basVarisNoktasi,
    required this.aciklama,
    required this.olusturmaTarihi,
    required this.aktif,
    required this.uyeIds,
    required this.saatProgram,
  });

  factory Ring.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Ring(
      id: doc.id,
      createdByUserId: data['createdByUserId'] ?? '',
      createdByName: data['createdByName'] ?? 'Bilinmeyen',
      universitesi: data['universitesi'] ?? '',
      basKalkisNoktasi: data['basKalkisNoktasi'] ?? '',
      basVarisNoktasi: data['basVarisNoktasi'] ?? '',
      aciklama: data['aciklama'] ?? '',
      olusturmaTarihi: (data['olusturmaTarihi'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aktif: data['aktif'] ?? true,
      uyeIds: List<String>.from(data['uyeIds'] ?? []),
      saatProgram: Map<String, dynamic>.from(data['saatProgram'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'universitesi': universitesi,
      'basKalkisNoktasi': basKalkisNoktasi,
      'basVarisNoktasi': basVarisNoktasi,
      'aciklama': aciklama,
      'olusturmaTarihi': Timestamp.fromDate(olusturmaTarihi),
      'aktif': aktif,
      'uyeIds': uyeIds,
      'saatProgram': saatProgram,
    };
  }
}

/// Tek bir Sefer (Trip) - tarih, saat, rota ile
class Sefer {
  final String id;
  final String ringId; // Hangi Ring'e ait
  final String driverId; // Şoför User ID
  final String driverName;
  final DateTime baslangicTarihi;
  final DateTime tahminiVarisTarihi;
  final String suAnkiKonum; // Başlangıç noktası veya arası
  final List<String> yolcuIds; // Sefers için onaylı yolcular
  final String durum; // "yakinda_baslamali", "devam_ediyor", "tamamlandi", "iptal_edildi"
  final double? guncelKoordinatLat;
  final double? guncelKoordinatLng;
  final bool ilkSefer; // İlk sefer mi yoksa tekrar eden seferin bir örneği mi
  
  Sefer({
    required this.id,
    required this.ringId,
    required this.driverId,
    required this.driverName,
    required this.baslangicTarihi,
    required this.tahminiVarisTarihi,
    required this.suAnkiKonum,
    required this.yolcuIds,
    required this.durum,
    this.guncelKoordinatLat,
    this.guncelKoordinatLng,
    required this.ilkSefer,
  });

  factory Sefer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sefer(
      id: doc.id,
      ringId: data['ringId'] ?? '',
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? 'Bilinmeyen',
      baslangicTarihi: (data['baslangicTarihi'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tahminiVarisTarihi: (data['tahminiVarisTarihi'] as Timestamp?)?.toDate() ?? DateTime.now(),
      suAnkiKonum: data['suAnkiKonum'] ?? '',
      yolcuIds: List<String>.from(data['yolcuIds'] ?? []),
      durum: data['durum'] ?? 'yakinda_baslamali',
      guncelKoordinatLat: (data['guncelKoordinatLat'] as num?)?.toDouble(),
      guncelKoordinatLng: (data['guncelKoordinatLng'] as num?)?.toDouble(),
      ilkSefer: data['ilkSefer'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ringId': ringId,
      'driverId': driverId,
      'driverName': driverName,
      'baslangicTarihi': Timestamp.fromDate(baslangicTarihi),
      'tahminiVarisTarihi': Timestamp.fromDate(tahminiVarisTarihi),
      'suAnkiKonum': suAnkiKonum,
      'yolcuIds': yolcuIds,
      'durum': durum,
      'guncelKoordinatLat': guncelKoordinatLat,
      'guncelKoordinatLng': guncelKoordinatLng,
      'ilkSefer': ilkSefer,
    };
  }
}

/// Ring üyeleri - sadece user ID + joined date
class RingUye {
  final String userId;
  final String userName;
  final String userProfilePhotoUrl;
  final DateTime katilimTarihi;
  final bool aktivDir; // Hala Ring'de aktif mi
  final int ratingAveragesi; // Ortalama puan (1-5)
  
  RingUye({
    required this.userId,
    required this.userName,
    required this.userProfilePhotoUrl,
    required this.katilimTarihi,
    required this.aktivDir,
    required this.ratingAveragesi,
  });

  factory RingUye.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RingUye(
      userId: doc.id,
      userName: data['ad_soyad'] ?? 'Bilinmeyen',
      userProfilePhotoUrl: data['profil_fotografi_url'] ?? '',
      katilimTarihi: (data['katilimTarihi'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aktivDir: data['aktivDir'] ?? true,
      ratingAveragesi: (data['ratingAveragesi'] as num?)?.toInt() ?? 5,
    );
  }
}
