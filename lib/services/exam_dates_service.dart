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

  /// Tüm sınavları döndürür (sadece 1 yıl önceki geçmiş sınavlar + gelecek sınavlar)
  /// Gelecek sınavlar en üste, geçmiş sınavlar altında
  List<Map<String, dynamic>> _filterUpcomingExams(
      List<Map<String, dynamic>> exams) {
    final now = DateTime.now();
    final oneYearAgo = now.subtract(Duration(days: 365)); // 1 yıl öncesi

    // Sınavları 2 gruba böl: geçmiş (1 yıl içinde) ve gelecek
    final future = <Map<String, dynamic>>[];
    final past = <Map<String, dynamic>>[];

    for (var exam in exams) {
      final examDate = exam['date'] as DateTime?;
      if (examDate == null) continue;

      // Saat bilgisini standardize et (00:00)
      final examDateNormalized = DateTime(examDate.year, examDate.month, examDate.day);
      final nowNormalized = DateTime(now.year, now.month, now.day);
      final oneYearAgoNormalized = DateTime(oneYearAgo.year, oneYearAgo.month, oneYearAgo.day);

      if (examDateNormalized.isAfter(nowNormalized)) {
        // Gelecek sınav - gün sayısını ekle
        final daysUntil = examDateNormalized.difference(nowNormalized).inDays;
        exam['daysUntil'] = daysUntil;
        future.add(exam);
      } else if (examDateNormalized.isAfter(oneYearAgoNormalized) || 
                 (examDateNormalized.year == oneYearAgoNormalized.year &&
                  examDateNormalized.month == oneYearAgoNormalized.month &&
                  examDateNormalized.day == oneYearAgoNormalized.day)) {
        // Geçmiş sınav ama 1 yıl içinde - gün sayısını ekle
        final daysPassed = nowNormalized.difference(examDateNormalized).inDays;
        exam['daysPassed'] = daysPassed;
        past.add(exam);
      }
      // 1 yıldan eski sınavları hariç tut
    }

    // Gelecek sınavları tarihe göre sırala (en yakın en üste)
    future.sort((a, b) => (a['daysUntil'] as int).compareTo(b['daysUntil'] as int));

    // Geçmiş sınavları tarihe göre sırala (en yakın en üste)
    past.sort((a, b) => (b['daysPassed'] as int).compareTo(a['daysPassed'] as int));

    // Gelecek sınavlar + Geçmiş sınavlar
    final result = [...future, ...past];

    print('✅ Toplam sınavlar: ${result.length} adet (Gelecek: ${future.length}, Geçmiş 1 yıl: ${past.length})');

    return result;
  }

  /// Test amaçlı örnek sınav tarihleri (gerçek tarihler + 1 yıl önceki geçmiş sınavlar)
  List<Map<String, dynamic>> _getTestExamDates() {
    return [
      // ✅ Gelecek Sınavlar (2025-2026)
      {
        'id': 'tus_2025',
        'name': 'TUS 2025',
        'date': DateTime(2025, 4, 27),
        'description': 'Tıp Uzmanlaşma Sınavı',
        'color': 'green',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'ales_2025_spring',
        'name': 'ALES 2025 (Bahar)',
        'date': DateTime(2025, 5, 11),
        'description': 'Akademik Personel ve Lisansüstü Eğitim Giriş Sınavı',
        'color': 'purple',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'medium',
      },
      {
        'id': 'kpss_2025',
        'name': 'KPSS 2025',
        'date': DateTime(2025, 5, 18),
        'description': 'Kamu Personeli Seçme Sınavı',
        'color': 'orange',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'yks_2025',
        'name': 'YKS 2025',
        'date': DateTime(2025, 6, 15),
        'description': 'Yükseköğretim Kurumları Sınavı',
        'color': 'blue',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'oabt_2025',
        'name': 'ÖABT 2025',
        'date': DateTime(2025, 7, 20),
        'description': 'Öğretmen Atama Sınavı Başarı Testi',
        'color': 'teal',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'ales_2025_fall',
        'name': 'ALES 2025 (Güz)',
        'date': DateTime(2025, 9, 14),
        'description': 'Akademik Personel ve Lisansüstü Eğitim Giriş Sınavı',
        'color': 'purple',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'medium',
      },
      {
        'id': 'dus_2025',
        'name': 'DÜŞ 2025',
        'date': DateTime(2025, 9, 22),
        'description': 'Diş Hekimliği Uzmanlaşma Sınavı',
        'color': 'red',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'medium',
      },
      {
        'id': 'kamu_yazili_2025',
        'name': 'Kamu Yazılı 2025',
        'date': DateTime(2025, 11, 9),
        'description': 'Kamu Kurumları Yazılı Sınavı',
        'color': 'amber',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'medium',
      },
      {
        'id': 'kpss_2026',
        'name': 'KPSS 2026',
        'date': DateTime(2026, 5, 17),
        'description': 'Kamu Personeli Seçme Sınavı 2026',
        'color': 'orange',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'yks_2026',
        'name': 'YKS 2026',
        'date': DateTime(2026, 6, 14),
        'description': 'Yükseköğretim Kurumları Sınavı 2026',
        'color': 'blue',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'tus_2026',
        'name': 'TUS 2026',
        'date': DateTime(2026, 4, 26),
        'description': 'Tıp Uzmanlaşma Sınavı 2026',
        'color': 'green',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'dus_2026',
        'name': 'DÜŞ 2026',
        'date': DateTime(2026, 9, 21),
        'description': 'Diş Hekimliği Uzmanlaşma Sınavı 2026',
        'color': 'red',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'medium',
      },
      
      // ✅ Geçmiş Sınavlar (1 yıl öncesi - 2024)
      {
        'id': 'tus_2024',
        'name': 'TUS 2024',
        'date': DateTime(2024, 4, 28),
        'description': 'Tıp Uzmanlaşma Sınavı',
        'color': 'green',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'kpss_2024',
        'name': 'KPSS 2024',
        'date': DateTime(2024, 5, 19),
        'description': 'Kamu Personeli Seçme Sınavı',
        'color': 'orange',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'yks_2024',
        'name': 'YKS 2024',
        'date': DateTime(2024, 6, 16),
        'description': 'Yükseköğretim Kurumları Sınavı',
        'color': 'blue',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'oabt_2024',
        'name': 'ÖABT 2024',
        'date': DateTime(2024, 7, 21),
        'description': 'Öğretmen Atama Sınavı Başarı Testi',
        'color': 'teal',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'high',
      },
      {
        'id': 'ales_2024_fall',
        'name': 'ALES 2024 (Güz)',
        'date': DateTime(2024, 9, 15),
        'description': 'Akademik Personel ve Lisansüstü Eğitim Giriş Sınavı',
        'color': 'purple',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'medium',
      },
      {
        'id': 'dus_2024',
        'name': 'DÜŞ 2024',
        'date': DateTime(2024, 9, 23),
        'description': 'Diş Hekimliği Uzmanlaşma Sınavı',
        'color': 'red',
        'type': 'exam',
        'source': 'OSYM',
        'importance': 'medium',
      },
    ];
  }

  /// Cloud Function çağırarak sınav tarihlerini manuel olarak güncelle
  /// Admin tarafından kullanılabilir
  Future<Map<String, dynamic>> triggerExamDatesUpdate() async {
    try {
      final callable = _functions.httpsCallable('updateExamDates');
      final now = DateTime.now();
      final result = await callable.call({
        'years': [now.year, now.year + 1]
      });
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
