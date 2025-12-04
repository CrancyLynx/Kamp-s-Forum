import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/ring_model.dart';

class RingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Ring CRUD Operations

  /// Yeni Ring oluştur
  static Future<String?> createRing({
    required String createdByUserId,
    required String createdByName,
    required String universitesi,
    required String basKalkisNoktasi,
    required String basVarisNoktasi,
    required String aciklama,
  }) async {
    try {
      final ringRef = _firestore.collection('ringlar').doc();
      final ringId = ringRef.id;

      await ringRef.set({
        'createdByUserId': createdByUserId,
        'createdByName': createdByName,
        'universitesi': universitesi,
        'basKalkisNoktasi': basKalkisNoktasi,
        'basVarisNoktasi': basVarisNoktasi,
        'aciklama': aciklama,
        'olusturmaTarihi': Timestamp.now(),
        'aktif': true,
        'uyeIds': [createdByUserId], // Oluşturucu otomatik üye
        'saatProgram': {},
      });

      debugPrint('[RING] Yeni Ring oluşturuldu: $ringId');
      return ringId;
    } catch (e) {
      debugPrint('[RING] Ring oluşturma hatası: $e');
      return null;
    }
  }

  /// Ring detaylarını getir
  static Future<Ring?> getRing(String ringId) async {
    try {
      final doc = await _firestore.collection('ringlar').doc(ringId).get();
      if (doc.exists) {
        return Ring.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('[RING] Ring getirme hatası: $e');
      return null;
    }
  }

  /// Ring'i güncelle
  static Future<bool> updateRing(String ringId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('ringlar').doc(ringId).update(updates);
      debugPrint('[RING] Ring güncellendi: $ringId');
      return true;
    } catch (e) {
      debugPrint('[RING] Ring güncelleme hatası: $e');
      return false;
    }
  }

  /// Ring'i sil
  static Future<bool> deleteRing(String ringId) async {
    try {
      await _firestore.collection('ringlar').doc(ringId).delete();
      
      // İlişkili seferleri de sil
      final seferler = await _firestore
          .collection('ringlar')
          .doc(ringId)
          .collection('seferler')
          .get();
      
      for (var sefer in seferler.docs) {
        await sefer.reference.delete();
      }
      
      debugPrint('[RING] Ring silindi: $ringId');
      return true;
    } catch (e) {
      debugPrint('[RING] Ring silme hatası: $e');
      return false;
    }
  }

  // Üyelik İşlemleri

  /// Ring'e üye ekle
  static Future<bool> addMemberToRing(String ringId, String userId, String userName) async {
    try {
      await _firestore.collection('ringlar').doc(ringId).update({
        'uyeIds': FieldValue.arrayUnion([userId]),
      });

      // Üye koleksiyonuna ekle
      await _firestore
          .collection('ringlar')
          .doc(ringId)
          .collection('uyeler')
          .doc(userId)
          .set({
        'userId': userId,
        'userName': userName,
        'katılımTarihi': Timestamp.now(),
        'aktivDir': true,
        'ratingAveragesi': 5,
      });

      debugPrint('[RING] Üye eklendi: $userId -> $ringId');
      return true;
    } catch (e) {
      debugPrint('[RING] Üye ekleme hatası: $e');
      return false;
    }
  }

  /// Ring'ten üyeyi çıkar
  static Future<bool> removeMemberFromRing(String ringId, String userId) async {
    try {
      await _firestore.collection('ringlar').doc(ringId).update({
        'uyeIds': FieldValue.arrayRemove([userId]),
      });

      await _firestore
          .collection('ringlar')
          .doc(ringId)
          .collection('uyeler')
          .doc(userId)
          .delete();

      debugPrint('[RING] Üye çıkartıldı: $userId -> $ringId');
      return true;
    } catch (e) {
      debugPrint('[RING] Üye çıkartma hatası: $e');
      return false;
    }
  }

  /// Ring üyelerini getir (stream)
  static Stream<List<RingUye>> getRingMembers(String ringId) {
    return _firestore
        .collection('ringlar')
        .doc(ringId)
        .collection('uyeler')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RingUye.fromFirestore(doc))
            .toList());
  }

  // Sefer İşlemleri

  /// Yeni Sefer oluştur
  static Future<String?> createSefer({
    required String ringId,
    required String driverId,
    required String driverName,
    required DateTime baslangicTarihi,
    required DateTime tahminiVarisTarihi,
    required String suAnkiKonum,
    required bool ilkSefer,
  }) async {
    try {
      final seferRef = _firestore
          .collection('ringlar')
          .doc(ringId)
          .collection('seferler')
          .doc();
      final seferId = seferRef.id;

      await seferRef.set({
        'ringId': ringId,
        'driverId': driverId,
        'driverName': driverName,
        'baslangicTarihi': Timestamp.fromDate(baslangicTarihi),
        'tahminiVarisTarihi': Timestamp.fromDate(tahminiVarisTarihi),
        'suAnkiKonum': suAnkiKonum,
        'yolcuIds': [driverId], // Şoför otomatik yolcu
        'durum': 'yakinda_baslamali',
        'guncelKoordinatLat': null,
        'guncelKoordinatLng': null,
        'ilkSefer': ilkSefer,
      });

      debugPrint('[RING] Yeni Sefer oluşturuldu: $seferId');
      return seferId;
    } catch (e) {
      debugPrint('[RING] Sefer oluşturma hatası: $e');
      return null;
    }
  }

  /// Sefer durumunu güncelle
  static Future<bool> updateSeferStatus(
    String ringId,
    String seferId,
    String yeniDurum,
  ) async {
    try {
      await _firestore
          .collection('ringlar')
          .doc(ringId)
          .collection('seferler')
          .doc(seferId)
          .update({'durum': yeniDurum});

      debugPrint('[RING] Sefer durumu güncellendi: $seferId -> $yeniDurum');
      return true;
    } catch (e) {
      debugPrint('[RING] Sefer durumu güncelleme hatası: $e');
      return false;
    }
  }

  /// Sefer konumunu güncelle (real-time tracking)
  static Future<bool> updateSeferLocation(
    String ringId,
    String seferId,
    double latitude,
    double longitude,
  ) async {
    try {
      await _firestore
          .collection('ringlar')
          .doc(ringId)
          .collection('seferler')
          .doc(seferId)
          .update({
        'guncelKoordinatLat': latitude,
        'guncelKoordinatLng': longitude,
      });

      return true;
    } catch (e) {
      debugPrint('[RING] Konum güncelleme hatası: $e');
      return false;
    }
  }

  /// Sefer yolcularını getir
  static Future<List<String>> getSeferPassengers(String ringId, String seferId) async {
    try {
      final doc = await _firestore
          .collection('ringlar')
          .doc(ringId)
          .collection('seferler')
          .doc(seferId)
          .get();

      if (doc.exists) {
        return List<String>.from(doc['yolcuIds'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('[RING] Yolcu getirme hatası: $e');
      return [];
    }
  }

  /// Sefer stream'ini al (real-time updates)
  static Stream<Sefer?> getSeferStream(String ringId, String seferId) {
    return _firestore
        .collection('ringlar')
        .doc(ringId)
        .collection('seferler')
        .doc(seferId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return Sefer.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Ring'in tüm seferlerini getir
  static Stream<List<Sefer>> getRingSeferler(String ringId) {
    return _firestore
        .collection('ringlar')
        .doc(ringId)
        .collection('seferler')
        .orderBy('baslangicTarihi', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Sefer.fromFirestore(doc))
            .toList());
  }

  /// Yolcu ekle (Sefer'e katıl)
  static Future<bool> addPassengerToSefer(
    String ringId,
    String seferId,
    String userId,
  ) async {
    try {
      await _firestore
          .collection('ringlar')
          .doc(ringId)
          .collection('seferler')
          .doc(seferId)
          .update({
        'yolcuIds': FieldValue.arrayUnion([userId]),
      });

      debugPrint('[RING] Yolcu eklendi: $userId -> Sefer $seferId');
      return true;
    } catch (e) {
      debugPrint('[RING] Yolcu ekleme hatası: $e');
      return false;
    }
  }

  /// Yolcu çıkar
  static Future<bool> removePassengerFromSefer(
    String ringId,
    String seferId,
    String userId,
  ) async {
    try {
      await _firestore
          .collection('ringlar')
          .doc(ringId)
          .collection('seferler')
          .doc(seferId)
          .update({
        'yolcuIds': FieldValue.arrayRemove([userId]),
      });

      debugPrint('[RING] Yolcu çıkartıldı: $userId -> Sefer $seferId');
      return true;
    } catch (e) {
      debugPrint('[RING] Yolcu çıkartma hatası: $e');
      return false;
    }
  }

  // Arama ve Filtreleme

  /// Üniversite'deki tüm Ring'leri getir
  static Stream<List<Ring>> getUniversityRings(String universitesi) {
    return _firestore
        .collection('ringlar')
        .where('universitesi', isEqualTo: universitesi)
        .where('aktif', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Ring.fromFirestore(doc))
            .toList());
  }

  /// Üniversite'deki aktif Sefer'leri getir
  static Future<List<Sefer>> getActiveUniversitySeferler(String universitesi) async {
    try {
      final rings = await _firestore
          .collection('ringlar')
          .where('universitesi', isEqualTo: universitesi)
          .where('aktif', isEqualTo: true)
          .get();

      final allSeferler = <Sefer>[];

      for (var ringDoc in rings.docs) {
        final seferler = await _firestore
            .collection('ringlar')
            .doc(ringDoc.id)
            .collection('seferler')
            .where('durum', whereIn: ['yakinda_baslamali', 'devam_ediyor'])
            .get();

        for (var seferDoc in seferler.docs) {
          allSeferler.add(Sefer.fromFirestore(seferDoc));
        }
      }

      return allSeferler;
    } catch (e) {
      debugPrint('[RING] Aktif Sefer getirme hatası: $e');
      return [];
    }
  }

  /// Kullanıcının üyesi olduğu Ring'leri getir
  static Stream<List<Ring>> getUserRings(String userId) {
    return _firestore
        .collection('ringlar')
        .where('uyeIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Ring.fromFirestore(doc))
            .toList());
  }

  // Rating & Review Operations

  /// Sefer için rating ve yorum ekle
  static Future<bool> ratSefer({
    required String seferId,
    required String driverId,
    required String driverName,
    required String raterUserId,
    required double rating,
    required String comment,
    required Map<String, double> categoryRatings,
  }) async {
    try {
      final ratingRef = _firestore
          .collection('ringlar')
          .doc('')
          .collection('sefer_ratings')
          .doc();

      await ratingRef.set({
        'seferId': seferId,
        'driverId': driverId,
        'driverName': driverName,
        'raterUserId': raterUserId,
        'rating': rating,
        'comment': comment,
        'categoryRatings': categoryRatings,
        'createdAt': Timestamp.now(),
      });

      // Sürücünün ortalama rating'ini güncelle
      await _updateDriverStats(driverId, rating, categoryRatings);

      debugPrint('[RING] Sefer rating eklendi: ${ratingRef.id}');
      return true;
    } catch (e) {
      debugPrint('[RING] Rating ekleme hatası: $e');
      return false;
    }
  }

  /// Sürücü istatistiklerini güncelle
  static Future<void> _updateDriverStats(
      String driverId, double newRating, Map<String, double> categories) async {
    try {
      final statsRef = _firestore.collection('driver_stats').doc(driverId);
      final statsDoc = await statsRef.get();

      if (statsDoc.exists) {
        final currentData = statsDoc.data()!;
        final totalRatings = (currentData['totalRatings'] ?? 0).toInt();
        final currentAvg = (currentData['averageRating'] ?? 0.0).toDouble();

        final newTotal = totalRatings + 1;
        final newAvg = ((currentAvg * totalRatings) + newRating) / newTotal;

        await statsRef.update({
          'averageRating': newAvg,
          'totalRatings': newTotal,
          'lastRatedAt': Timestamp.now(),
        });
      } else {
        await statsRef.set({
          'driverId': driverId,
          'averageRating': newRating,
          'totalRatings': 1,
          'totalCompletedSefers': 1,
          'memberSince': Timestamp.now(),
        });
      }
    } catch (e) {
      debugPrint('[RING] Driver stats update hatası: $e');
    }
  }

  /// Sürücü istatistiklerini getir
  static Future<Map<String, dynamic>?> getDriverStats(String driverId) async {
    try {
      final doc = await _firestore.collection('driver_stats').doc(driverId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('[RING] Driver stats getirme hatası: $e');
      return null;
    }
  }

  /// Sürücüyü şikayet et
  static Future<String?> fileComplaint({
    required String seferId,
    required String complainantId,
    required String complainantName,
    required String defendantId,
    required String defendantName,
    required String complaintType,
    required String description,
  }) async {
    try {
      final complaintRef = _firestore.collection('sefer_complaints').doc();

      await complaintRef.set({
        'seferId': seferId,
        'complainantId': complainantId,
        'complainantName': complainantName,
        'defendantId': defendantId,
        'defendantName': defendantName,
        'complaintType': complaintType,
        'description': description,
        'createdAt': Timestamp.now(),
        'status': 'open',
        'resolution': null,
      });

      debugPrint('[RING] Şikayet açıldı: ${complaintRef.id}');
      return complaintRef.id;
    } catch (e) {
      debugPrint('[RING] Şikayet ekleme hatası: $e');
      return null;
    }
  }

  /// Sefer rating'lerini getir
  static Stream<List<Map<String, dynamic>>> getSeferRatings(String seferId) {
    return _firestore
        .collection('sefer_ratings')
        .where('seferId', isEqualTo: seferId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Sürücünün rating'lerini getir
  static Stream<List<Map<String, dynamic>>> getDriverRatings(String driverId) {
    return _firestore
        .collection('sefer_ratings')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Şikayetleri getir (Moderator)
  static Future<List<Map<String, dynamic>>> getPendingComplaints() async {
    try {
      final snapshot = await _firestore
          .collection('sefer_complaints')
          .where('status', isEqualTo: 'open')
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[RING] Complaint getirme hatası: $e');
      return [];
    }
  }

  /// Şikayet çöz
  static Future<bool> resolveComplaint({
    required String complaintId,
    required String resolution,
    required String status,
  }) async {
    try {
      await _firestore.collection('sefer_complaints').doc(complaintId).update({
        'status': status,
        'resolution': resolution,
        'resolvedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      debugPrint('[RING] Complaint çözme hatası: $e');
      return false;
    }
  }
}
