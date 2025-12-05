import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_models.dart';

class ExamCalendarService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sınav ekle
  static Future<String> addExamEntry(ExamCalendarEntry exam) async {
    try {
      final docRef = await _firestore.collection('exam_calendar').add(exam.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Sınav ekleme hatası: $e');
    }
  }

  /// Sınav güncelle
  static Future<void> updateExam(String examId, ExamCalendarEntry exam) async {
    try {
      await _firestore.collection('exam_calendar').doc(examId).update(exam.toFirestore());
    } catch (e) {
      throw Exception('Sınav güncelleme hatası: $e');
    }
  }

  /// Sınav sil
  static Future<void> deleteExam(String examId) async {
    try {
      await _firestore.collection('exam_calendar').doc(examId).delete();
    } catch (e) {
      throw Exception('Sınav silme hatası: $e');
    }
  }

  /// Yaklaşan sınavlar
  static Stream<List<ExamCalendarEntry>> getUpcomingExams() {
    final now = DateTime.now();
    return _firestore
        .collection('exam_calendar')
        .where('examDate', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('examDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExamCalendarEntry.fromFirestore(doc))
            .toList());
  }

  /// Üniversiteye göre sınavlar
  static Stream<List<ExamCalendarEntry>> getExamsByUniversity(String university) {
    return _firestore
        .collection('exam_calendar')
        .where('university', isEqualTo: university)
        .orderBy('examDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExamCalendarEntry.fromFirestore(doc))
            .toList());
  }

  /// Ders koduna göre sınavları bul
  static Future<List<ExamCalendarEntry>> getExamsByCourseCode(String courseCode) async {
    try {
      final snapshot = await _firestore
          .collection('exam_calendar')
          .where('courseCode', isEqualTo: courseCode)
          .get();
      return snapshot.docs.map((doc) => ExamCalendarEntry.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ders sınavları alma hatası: $e');
    }
  }

  /// Sınav tipine göre filtre
  static Stream<List<ExamCalendarEntry>> getExamsByType(String examType) {
    return _firestore
        .collection('exam_calendar')
        .where('examType', isEqualTo: examType)
        .orderBy('examDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExamCalendarEntry.fromFirestore(doc))
            .toList());
  }

  /// Bugünün sınavları
  static Future<List<ExamCalendarEntry>> getTodaysExams() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('exam_calendar')
          .where('examDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('examDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      return snapshot.docs.map((doc) => ExamCalendarEntry.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Bugünün sınavları alma hatası: $e');
    }
  }

  /// Haftalık sınavlar
  static Future<List<ExamCalendarEntry>> getWeeklyExams() async {
    try {
      final now = DateTime.now();
      final endOfWeek = now.add(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('exam_calendar')
          .where('examDate', isGreaterThan: Timestamp.fromDate(now))
          .where('examDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
          .get();
      return snapshot.docs.map((doc) => ExamCalendarEntry.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Haftalık sınavlar alma hatası: $e');
    }
  }

  /// Sınav sayısını al
  static Future<int> getExamCount(String courseCode) async {
    try {
      final snapshot = await _firestore
          .collection('exam_calendar')
          .where('courseCode', isEqualTo: courseCode)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Sınav sayısı alma hatası: $e');
    }
  }
}

class VisionApiQuotaService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ay ayını kuota bilgisini al
  static Future<VisionApiQuota?> getMonthlyQuota(String month) async {
    try {
      final doc = await _firestore.collection('vision_api_quota').doc(month).get();
      if (doc.exists) {
        return VisionApiQuota.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Kuota bilgisi alma hatası: $e');
    }
  }

  /// Kuota kullanımını arttır
  static Future<void> incrementQuotaUsage(String month) async {
    try {
      await _firestore.collection('vision_api_quota').doc(month).update({
        'usedCount': FieldValue.increment(1),
        'remainingCount': FieldValue.increment(-1),
      });
    } catch (e) {
      throw Exception('Kuota artırma hatası: $e');
    }
  }

  /// Kalan kuotayı kontrol et
  static Future<bool> hasQuotaRemaining(String month) async {
    try {
      final quota = await getMonthlyQuota(month);
      return quota != null && quota.remainingCount > 0;
    } catch (e) {
      throw Exception('Kuota kontrolü hatası: $e');
    }
  }

  /// Kuota yüzdesini al
  static Future<double> getQuotaUsagePercentage(String month) async {
    try {
      final quota = await getMonthlyQuota(month);
      if (quota == null) return 0.0;
      return quota.getUsagePercentage();
    } catch (e) {
      throw Exception('Kuota yüzdesi alma hatası: $e');
    }
  }

  /// Ay sıfırla
  static Future<void> resetMonthlyQuota(String month, int newLimit) async {
    try {
      await _firestore.collection('vision_api_quota').doc(month).set({
        'monthlyLimit': newLimit,
        'usedCount': 0,
        'remainingCount': newLimit,
        'costPerImage': 0.0015,
        'resetDate': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Kuota sıfırlama hatası: $e');
    }
  }

  /// Maliyet hesapla
  static Future<double> calculateMonthlyCost(String month) async {
    try {
      final quota = await getMonthlyQuota(month);
      if (quota == null) return 0.0;
      return quota.usedCount * quota.costPerImage;
    } catch (e) {
      throw Exception('Maliyet hesaplama hatası: $e');
    }
  }
}

class AuditLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Audit log kaydı oluştur
  static Future<String> createAuditLog(AuditLog log) async {
    try {
      final docRef = await _firestore.collection('audit_logs').add(log.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Audit log oluşturma hatası: $e');
    }
  }

  /// Admin tarafından yapılan işlemler
  static Stream<List<AuditLog>> getAdminActions(String adminId) {
    return _firestore
        .collection('audit_logs')
        .where('adminId', isEqualTo: adminId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AuditLog.fromFirestore(doc))
            .toList());
  }

  /// Hedef tipine göre işlemler
  static Stream<List<AuditLog>> getActionsByTargetType(String targetType) {
    return _firestore
        .collection('audit_logs')
        .where('targetType', isEqualTo: targetType)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AuditLog.fromFirestore(doc))
            .toList());
  }

  /// Belirli bir hedef hakkındaki tüm işlemler
  static Stream<List<AuditLog>> getTargetHistory(String targetId) {
    return _firestore
        .collection('audit_logs')
        .where('targetId', isEqualTo: targetId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AuditLog.fromFirestore(doc))
            .toList());
  }

  /// İşlem tipine göre filtre
  static Stream<List<AuditLog>> getActionsByType(String action) {
    return _firestore
        .collection('audit_logs')
        .where('action', isEqualTo: action)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AuditLog.fromFirestore(doc))
            .toList());
  }

  /// Zaman aralığına göre logs
  static Future<List<AuditLog>> getLogsByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final snapshot = await _firestore
          .collection('audit_logs')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) => AuditLog.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Log alma hatası: $e');
    }
  }
}

class ErrorLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Hata kaydı ekle
  static Future<String> logError(ErrorLog errorLog) async {
    try {
      final docRef = await _firestore.collection('error_logs').add(errorLog.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Hata kaydı ekleme hatası: $e');
    }
  }

  /// Kritik hatalar
  static Stream<List<ErrorLog>> getCriticalErrors() {
    return _firestore
        .collection('error_logs')
        .where('severity', isEqualTo: 'critical')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ErrorLog.fromFirestore(doc))
            .toList());
  }

  /// Platforma göre hatalar
  static Stream<List<ErrorLog>> getErrorsByPlatform(String platform) {
    return _firestore
        .collection('error_logs')
        .where('platform', isEqualTo: platform)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ErrorLog.fromFirestore(doc))
            .toList());
  }

  /// Kullanıcı hatalarını al
  static Stream<List<ErrorLog>> getUserErrors(String userId) {
    return _firestore
        .collection('error_logs')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ErrorLog.fromFirestore(doc))
            .toList());
  }

  /// Ağır olan hatalardan beri sayısı
  static Future<int> getErrorCountBySeverity(String severity) async {
    try {
      final snapshot = await _firestore
          .collection('error_logs')
          .where('severity', isEqualTo: severity)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Hata sayısı alma hatası: $e');
    }
  }

  /// Başında en sık karşılaşılan hatalar
  static Future<List<String>> getFrequentErrors(int limit) async {
    try {
      final snapshot = await _firestore
          .collection('error_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit * 3)
          .get();
      
      final errorMap = <String, int>{};
      for (final doc in snapshot.docs) {
        final error = doc['errorMessage'] as String;
        errorMap[error] = (errorMap[error] ?? 0) + 1;
      }
      
      final sorted = errorMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return sorted.take(limit).map((e) => e.key).toList();
    } catch (e) {
      throw Exception('Sık hatalar alma hatası: $e');
    }
  }
}

class FeedbackService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Feedback gönder
  static Future<String> submitFeedback(UserFeedback feedback) async {
    try {
      final docRef = await _firestore.collection('user_feedback').add(feedback.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Feedback gönderme hatası: $e');
    }
  }

  /// Feedback durumunu güncelle
  static Future<void> updateFeedbackStatus(String feedbackId, String status) async {
    try {
      await _firestore.collection('user_feedback').doc(feedbackId).update({
        'status': status,
      });
    } catch (e) {
      throw Exception('Feedback durumu güncelleme hatası: $e');
    }
  }

  /// Yanıt ekle
  static Future<void> addResponse(String feedbackId, String response) async {
    try {
      await _firestore.collection('user_feedback').doc(feedbackId).update({
        'response': response,
        'status': 'responded',
      });
    } catch (e) {
      throw Exception('Yanıt ekleme hatası: $e');
    }
  }

  /// Açık feedbackler
  static Stream<List<UserFeedback>> getOpenFeedback() {
    return _firestore
        .collection('user_feedback')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserFeedback.fromFirestore(doc))
            .toList());
  }

  /// Kategoriye göre feedback
  static Stream<List<UserFeedback>> getFeedbackByCategory(String category) {
    return _firestore
        .collection('user_feedback')
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserFeedback.fromFirestore(doc))
            .toList());
  }

  /// Kullanıcının tüm feedbackleri
  static Stream<List<UserFeedback>> getUserFeedback(String userId) {
    return _firestore
        .collection('user_feedback')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserFeedback.fromFirestore(doc))
            .toList());
  }

  /// İstatistik al
  static Future<Map<String, int>> getFeedbackStats() async {
    try {
      final all = await _firestore.collection('user_feedback').count().get();
      final open = await _firestore
          .collection('user_feedback')
          .where('status', isEqualTo: 'open')
          .count()
          .get();
      final responded = await _firestore
          .collection('user_feedback')
          .where('status', isEqualTo: 'responded')
          .count()
          .get();

      return {
        'total': all.count ?? 0,
        'open': open.count ?? 0,
        'responded': responded.count ?? 0,
      };
    } catch (e) {
      throw Exception('İstatistik alma hatası: $e');
    }
  }
}
