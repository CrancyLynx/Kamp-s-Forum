import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ExamDatesService {
  static final ExamDatesService _instance = ExamDatesService._internal();

  factory ExamDatesService() {
    return _instance;
  }

  ExamDatesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  /// Ülke geneli sınav tarihlerini Firestore'dan çeker
  /// Sadece gelecek sınavları (25+ gün sonra) döndürür
  /// Veri yoksa test verisi döndürür
  Future<List<Map<String, dynamic>>> fetchNationalExamDates() async {
    try {
      final snapshot = await _firestore
          .collection('sinavlar')
          .orderBy('date', descending: false)
          .get();

      List<Map<String, dynamic>> exams = [];
      
      if (snapshot.docs.isNotEmpty) {
        exams = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Sınav',
            'date': (data['date'] as Timestamp?)?.toDate(),
            'description': data['description'] ?? '',
            'color': data['color'] ?? 'orange',
            'type': data['type'] ?? 'exam',
            'source': data['source'] ?? 'OSYM',
            'importance': data['importance'] ?? 'medium',
          };
        }).toList();
      } else {
        // Firestore'da veri yoksa test verisi döndür
        print('⚠️ Firestore\'da sınav verisi bulunamadı - Test verisi gösteriliyor');
        exams = _getTestExamDates();
      }
      
      // Gelecek sınavları filtrele (25+ gün sonra olanları)
      return _filterUpcomingExams(exams);
      
    } catch (e) {
      print('❌ Sınav tarihleri çekilemedi: $e');
      // Hata durumunda da test verisi döndür
      print('⚠️ Hata nedeniyle test verisi gösteriliyor');
      final testExams = _getTestExamDates();
      return _filterUpcomingExams(testExams);
    }
  }

  /// Geçmiş sınavları (25 gün öncesi) filtreler, sadece gelecek sınavları döndürür
  List<Map<String, dynamic>> _filterUpcomingExams(
      List<Map<String, dynamic>> exams) {
    final now = DateTime.now();
    final cutoffDate = now.add(Duration(days: 25));

    // Tarih >= cutoffDate olan sınavları filtrele
    final upcoming = exams.where((exam) {
      final examDate = exam['date'] as DateTime?;
      if (examDate == null) return false;
      return examDate.isAfter(cutoffDate) || 
             examDate.year == cutoffDate.year &&
             examDate.month == cutoffDate.month &&
             examDate.day == cutoffDate.day;
    }).toList();

    print('✅ Gelecek sınavlar: ${upcoming.length} adet (25+ gün sonra)');
    
    // Eğer hiç sınav yoksa
    if (upcoming.isEmpty) {
      print('⚠️ Gelecek sınav bulunamadı');
    }

    return upcoming;
  }

  /// Test amaçlı örnek sınav tarihleri (25+ gün sonra olan sınavlar)
  List<Map<String, dynamic>> _getTestExamDates() {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: 25));
    
    return [
      {
        'id': 'kpss_2025',
        'name': 'KPSS 2025',
        'date': futureDate.add(Duration(days: 30)), // 55 gün sonra
        'description': 'Kamu Personeli Seçme Sınavı',
        'color': 'orange',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'yks_2025',
        'name': 'YKS 2025',
        'date': futureDate.add(Duration(days: 50)), // 75 gün sonra
        'description': 'Yükseköğretim Kurumları Sınavı',
        'color': 'blue',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'dus_2025',
        'name': 'DÜŞ 2025',
        'date': futureDate.add(Duration(days: 120)), // 145 gün sonra
        'description': 'Diş Hekimliği Uzmanlaşma Sınavı',
        'color': 'red',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'medium',
      },
      {
        'id': 'tus_2025',
        'name': 'TUS 2025',
        'date': futureDate.add(Duration(days: 25)), // Tam 50 gün sonra
        'description': 'Tıp Uzmanlaşma Sınavı',
        'color': 'green',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'ales_2025_spring',
        'name': 'ALES 2025 (Bahar)',
        'date': futureDate.add(Duration(days: 35)), // 60 gün sonra
        'description': 'Akademik Personel ve Lisansüstü Eğitim Giriş Sınavı',
        'color': 'purple',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'medium',
      },
      {
        'id': 'ales_2025_fall',
        'name': 'ALES 2025 (Güz)',
        'date': futureDate.add(Duration(days: 110)), // 135 gün sonra
        'description': 'Akademik Personel ve Lisansüstü Eğitim Giriş Sınavı',
        'color': 'purple',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'medium',
      },
      {
        'id': 'oabt_2025',
        'name': 'ÖABT 2025',
        'date': futureDate.add(Duration(days: 75)), // 100 gün sonra
        'description': 'Öğretmen Atama Sınavı Başarı Testi',
        'color': 'teal',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'kamu_yazili_2025',
        'name': 'Kamu Yazılı 2025',
        'date': futureDate.add(Duration(days: 160)), // 185 gün sonra
        'description': 'Kamu Kurumları Yazılı Sınavı',
        'color': 'amber',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'medium',
      },
      {
        'id': 'kpss_2026',
        'name': 'KPSS 2026',
        'date': futureDate.add(Duration(days: 200)), // 225 gün sonra
        'description': 'Kamu Personeli Seçme Sınavı 2026',
        'color': 'orange',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
    ];
  }

  /// Cloud Function çağırarak sınav tarihlerini manuel olarak güncelle
  /// Admin tarafından kullanılabilir
  Future<Map<String, dynamic>> triggerExamDatesUpdate() async {
    try {
      final callable = _functions.httpsCallable('updateExamDates');
      final result = await callable.call();
      return {
        'success': true,
        'message': result.data['message'] ?? 'Sınav tarihleri güncellendi',
        'count': result.data['count'] ?? 0,
      };
    } on FirebaseException catch (e) {
      print('Cloud Function hatası: ${e.message}');
      return {
        'success': false,
        'error': e.message ?? 'Bilinmeyen hata',
      };
    } catch (e) {
      print('Sınav tarihleri güncelleme hatası: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Belirli bir sınava kaç gün kaldığını hesapla
  int calculateDaysUntilExam(DateTime examDate) {
    final now = DateTime.now();
    return examDate.difference(now).inDays;
  }

  /// Sınava kaç gün kaldığını insan okunabilir şekilde döndür
  String getExamCountdownText(DateTime examDate) {
    final daysLeft = calculateDaysUntilExam(examDate);

    if (daysLeft < 0) {
      return 'Sınav Geçmişi';
    } else if (daysLeft == 0) {
      return 'Bugün!';
    } else if (daysLeft == 1) {
      return 'Yarın';
    } else if (daysLeft <= 7) {
      return '$daysLeft gün kaldı';
    } else if (daysLeft <= 30) {
      final weeks = (daysLeft / 7).ceil();
      return '$weeks hafta kaldı';
    } else {
      final months = (daysLeft / 30).ceil();
      return '$months ay kaldı';
    }
  }

  /// Sınav önemini renge göre döndür
  String getImportanceColor(String importance) {
    switch (importance.toLowerCase()) {
      case 'high':
        return 'red';
      case 'medium':
        return 'orange';
      case 'low':
        return 'grey';
      default:
        return 'blue';
    }
  }

  /// En yaklaşan sınavı getir
  Future<Map<String, dynamic>?> getNextUpcomingExam() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('sinavlar')
          .where('date', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('date', descending: false)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Sınav',
        'date': (data['date'] as Timestamp?)?.toDate(),
        'description': data['description'] ?? '',
        'color': data['color'] ?? 'orange',
        'daysLeft': calculateDaysUntilExam(
          (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ),
      };
    } catch (e) {
      print('Yaklaşan sınav alınamadı: $e');
      return null;
    }
  }

  /// Belirli ay içindeki sınavları getir
  Future<List<Map<String, dynamic>>> getExamsByMonth(int year, int month) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0);

      final snapshot = await _firestore
          .collection('sinavlar')
          .where('date',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('date', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sınav',
          'date': (data['date'] as Timestamp?)?.toDate(),
          'description': data['description'] ?? '',
          'color': data['color'] ?? 'orange',
        };
      }).toList();
    } catch (e) {
      print('Ay sınavları alınamadı: $e');
      return [];
    }
  }

  /// Sınavları önem derecesine göre filtrele
  Future<List<Map<String, dynamic>>> getExamsByImportance(
      String importance) async {
    try {
      final snapshot = await _firestore
          .collection('sinavlar')
          .where('importance', isEqualTo: importance)
          .orderBy('date', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sınav',
          'date': (data['date'] as Timestamp?)?.toDate(),
          'description': data['description'] ?? '',
          'color': data['color'] ?? 'orange',
          'importance': importance,
        };
      }).toList();
    } catch (e) {
      print('Önem derecesine göre sınavlar alınamadı: $e');
      return [];
    }
  }

  /// Real-time sınav tarihleri stream'i (Listenin güncellenmesi için)
  Stream<List<Map<String, dynamic>>> getExamDatesStream() {
    return _firestore
        .collection('sinavlar')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sınav',
          'date': (data['date'] as Timestamp?)?.toDate(),
          'description': data['description'] ?? '',
          'color': data['color'] ?? 'orange',
          'type': data['type'] ?? 'exam',
          'source': data['source'] ?? 'OSYM',
          'importance': data['importance'] ?? 'medium',
        };
      }).toList();
    });
  }
}
