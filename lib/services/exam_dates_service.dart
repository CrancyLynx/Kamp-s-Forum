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
  Future<List<Map<String, dynamic>>> fetchNationalExamDates() async {
    try {
      final snapshot = await _firestore
          .collection('sinavlar')
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
          'type': data['type'] ?? 'exam',
          'source': data['source'] ?? 'OSYM',
          'importance': data['importance'] ?? 'medium',
        };
      }).toList();
    } catch (e) {
      print('Sınav tarihleri çekilemedi: $e');
      return [];
    }
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
