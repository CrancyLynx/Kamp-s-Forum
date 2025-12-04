import 'package:cloud_firestore/cloud_firestore.dart';

/// Forum Kuralı Modeli
class ForumRule {
  final String id;
  final String baslik;
  final String aciklama; // Detaylı açıklama
  final int sirayaGore; // 1 = en önemli
  final String kategori; // "spam", "uygunsuz", "telif", "teknik", "diger"
  final List<String> ornekler; // Örnek ihlaller
  final bool aktif;
  final String ceza; // "uyari", "aysus_ban", "kalici_ban"
  
  ForumRule({
    required this.id,
    required this.baslik,
    required this.aciklama,
    required this.sirayaGore,
    required this.kategori,
    required this.ornekler,
    required this.aktif,
    required this.ceza,
  });

  factory ForumRule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ForumRule(
      id: doc.id,
      baslik: data['baslik'] ?? '',
      aciklama: data['aciklama'] ?? '',
      sirayaGore: (data['sirayaGore'] as num?)?.toInt() ?? 999,
      kategori: data['kategori'] ?? 'diger',
      ornekler: List<String>.from(data['ornekler'] ?? []),
      aktif: data['aktif'] ?? true,
      ceza: data['ceza'] ?? 'uyari',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'baslik': baslik,
      'aciklama': aciklama,
      'sirayaGore': sirayaGore,
      'kategori': kategori,
      'ornekler': ornekler,
      'aktif': aktif,
      'ceza': ceza,
    };
  }
}

/// Kural İhlali Kaydı
class RuleViolation {
  final String id;
  final String gonderisId;
  final String ihlalEdenUserId;
  final String ihlalEdenUserName;
  final String kaidaId;
  final String kaidaBasligi;
  final DateTime ihlalfZamani;
  final String durum; // "raporlandi", "inceleniyor", "onaylandi", "reddedildi"
  final int reportEdenCount; // Kaç kişi rapor etti
  final String? moderatorNotlari; // Moderator notları
  final String? ceza; // Uygulanacak ceza
  final DateTime? cekaZamani;
  final bool shadowBanned; // Gönderi gizlenmiş mi?

  RuleViolation({
    required this.id,
    required this.gonderisId,
    required this.ihlalEdenUserId,
    required this.ihlalEdenUserName,
    required this.kaidaId,
    required this.kaidaBasligi,
    required this.ihlalfZamani,
    required this.durum,
    required this.reportEdenCount,
    this.moderatorNotlari,
    this.ceza,
    this.cekaZamani,
    required this.shadowBanned,
  });

  factory RuleViolation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RuleViolation(
      id: doc.id,
      gonderisId: data['gonderisId'] ?? '',
      ihlalEdenUserId: data['ihlalEdenUserId'] ?? '',
      ihlalEdenUserName: data['ihlalEdenUserName'] ?? 'Kullanıcı',
      kaidaId: data['kaidaId'] ?? '',
      kaidaBasligi: data['kaidaBasligi'] ?? '',
      ihlalfZamani: (data['ihlalfZamani'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durum: data['durum'] ?? 'raporlandi',
      reportEdenCount: (data['reportEdenCount'] as num?)?.toInt() ?? 1,
      moderatorNotlari: data['moderatorNotlari'],
      ceza: data['ceza'],
      cekaZamani: (data['cekaZamani'] as Timestamp?)?.toDate(),
      shadowBanned: data['shadowBanned'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'gonderisId': gonderisId,
      'ihlalEdenUserId': ihlalEdenUserId,
      'ihlalEdenUserName': ihlalEdenUserName,
      'kaidaId': kaidaId,
      'kaidaBasligi': kaidaBasligi,
      'ihlalfZamani': Timestamp.fromDate(ihlalfZamani),
      'durum': durum,
      'reportEdenCount': reportEdenCount,
      'moderatorNotlari': moderatorNotlari,
      'ceza': ceza,
      'cekaZamani': cekaZamani != null ? Timestamp.fromDate(cekaZamani!) : null,
      'shadowBanned': shadowBanned,
    };
  }
}

/// Kullanıcı Ceza Geçmişi
class UserPenalty {
  final String id;
  final String userId;
  final String userName;
  final String tip; // "uyari", "7gun_ban", "30gun_ban", "kalici_ban"
  final String nedeni; // Neden yazıldı
  final DateTime gecerliligi; // Ne kadar geçerli
  final String verilenModerId; // Hangi moderatör verdi
  final DateTime verilmeTarihi;
  final bool aktif;
  
  UserPenalty({
    required this.id,
    required this.userId,
    required this.userName,
    required this.tip,
    required this.nedeni,
    required this.gecerliligi,
    required this.verilenModerId,
    required this.verilmeTarihi,
    required this.aktif,
  });

  factory UserPenalty.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserPenalty(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Kullanıcı',
      tip: data['tip'] ?? 'uyari',
      nedeni: data['nedeni'] ?? '',
      gecerliligi: (data['gecerliligi'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verilenModerId: data['verilenModerId'] ?? '',
      verilmeTarihi: (data['verilmeTarihi'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aktif: data['aktif'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'tip': tip,
      'nedeni': nedeni,
      'gecerliligi': Timestamp.fromDate(gecerliligi),
      'verilenModerId': verilenModerId,
      'verilmeTarihi': Timestamp.fromDate(verilmeTarihi),
      'aktif': aktif,
    };
  }

  bool isExpired() {
    return DateTime.now().isAfter(gecerliligi);
  }
}
