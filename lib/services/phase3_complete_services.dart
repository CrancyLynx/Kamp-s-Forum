// lib/services/phase3_complete_services.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/phase3_complete_models.dart';

// ============================================================
// PHASE 3 SERVICES - Admin, Exam, Audit, Feedback
// ============================================================

class ExamCalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'exam_calendar';

  Future<List<ExamCalendar>> getAllExams() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .orderBy('examDate', descending: false)
          .get();
      
      return snapshot.docs
          .map((doc) => ExamCalendar.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching exams: $e');
      return [];
    }
  }

  Future<List<ExamCalendar>> getUpcomingExams() async {
    try {
      final now = DateTime.now();
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('examDate', isGreaterThanOrEqualTo: now)
          .orderBy('examDate', descending: false)
          .get();
      
      return snapshot.docs
          .map((doc) => ExamCalendar.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching upcoming exams: $e');
      return [];
    }
  }

  Future<void> addExam(ExamCalendar exam) async {
    try {
      await _firestore.collection(_collection).doc(exam.id).set(exam.toJson());
    } catch (e) {
      print('Error adding exam: $e');
    }
  }

  Future<void> updateExam(ExamCalendar exam) async {
    try {
      await _firestore.collection(_collection).doc(exam.id).update(exam.toJson());
    } catch (e) {
      print('Error updating exam: $e');
    }
  }

  Future<void> deleteExam(String examId) async {
    try {
      await _firestore.collection(_collection).doc(examId).delete();
    } catch (e) {
      print('Error deleting exam: $e');
    }
  }
}

// ============================================================
// VISION API QUOTA SERVICE
// ============================================================
class VisionQuotaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'vision_quotas';

  Future<VisionQuota?> getUserQuota(String userId) async {
    try {
      final DocumentSnapshot doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        return VisionQuota.fromJson({...doc.data() as Map<String, dynamic>, 'userId': doc.id});
      }
      return null;
    } catch (e) {
      print('Error fetching user quota: $e');
      return null;
    }
  }

  Future<void> updateQuotaUsage(String userId, int usedAmount) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        final quota = VisionQuota.fromJson({...doc.data() as Map<String, dynamic>, 'userId': doc.id});
        final newUsed = quota.usedThisMonth + usedAmount;
        final newRemaining = quota.monthlyLimit - newUsed;
        
        await _firestore.collection(_collection).doc(userId).update({
          'usedThisMonth': newUsed,
          'remainingQuota': newRemaining > 0 ? newRemaining : 0,
          'usageHistory': FieldValue.arrayUnion([DateTime.now().toIso8601String()]),
        });
      }
    } catch (e) {
      print('Error updating quota usage: $e');
    }
  }

  Future<void> resetMonthlyQuota(String userId) async {
    try {
      final resetDate = DateTime.now().add(Duration(days: 30));
      await _firestore.collection(_collection).doc(userId).update({
        'usedThisMonth': 0,
        'remainingQuota': 100,
        'resetDate': resetDate.toIso8601String(),
      });
    } catch (e) {
      print('Error resetting monthly quota: $e');
    }
  }
}

// ============================================================
// AUDIT LOG SERVICE
// ============================================================
class AuditLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'audit_logs';

  Future<void> logAction(AuditLog log) async {
    try {
      await _firestore.collection(_collection).doc(log.id).set(log.toJson());
    } catch (e) {
      print('Error logging action: $e');
    }
  }

  Future<List<AuditLog>> getAdminLogs(String adminId, {int limit = 50}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('adminId', isEqualTo: adminId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => AuditLog.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching admin logs: $e');
      return [];
    }
  }

  Future<List<AuditLog>> getActionLogs(String action, {int limit = 50}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('action', isEqualTo: action)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => AuditLog.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching action logs: $e');
      return [];
    }
  }

  Future<List<AuditLog>> getRecentLogs({int limit = 100}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => AuditLog.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching recent logs: $e');
      return [];
    }
  }
}

// ============================================================
// ERROR LOG SERVICE
// ============================================================
class ErrorLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'error_logs';

  Future<void> logError(ErrorLog log) async {
    try {
      await _firestore.collection(_collection).doc(log.id).set(log.toJson());
    } catch (e) {
      print('Error logging error: $e');
    }
  }

  Future<List<ErrorLog>> getRecentErrors({int limit = 50}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => ErrorLog.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching recent errors: $e');
      return [];
    }
  }

  Future<List<ErrorLog>> getUnresolvedErrors() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isResolved', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => ErrorLog.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching unresolved errors: $e');
      return [];
    }
  }

  Future<void> markErrorAsResolved(String errorId) async {
    try {
      await _firestore.collection(_collection).doc(errorId).update({'isResolved': true});
    } catch (e) {
      print('Error marking error as resolved: $e');
    }
  }

  Future<List<ErrorLog>> getErrorsBySeverity(String severity) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('severity', isEqualTo: severity)
          .orderBy('timestamp', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => ErrorLog.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching errors by severity: $e');
      return [];
    }
  }
}

// ============================================================
// FEEDBACK SERVICE
// ============================================================
class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'feedback';

  Future<void> submitFeedback(Feedback feedback) async {
    try {
      await _firestore.collection(_collection).doc(feedback.id).set(feedback.toJson());
    } catch (e) {
      print('Error submitting feedback: $e');
    }
  }

  Future<List<Feedback>> getNewFeedback({int limit = 50}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'new')
          .orderBy('submittedAt', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => Feedback.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching new feedback: $e');
      return [];
    }
  }

  Future<void> updateFeedbackStatus(String feedbackId, String status) async {
    try {
      await _firestore.collection(_collection).doc(feedbackId).update({'status': status});
    } catch (e) {
      print('Error updating feedback status: $e');
    }
  }

  Future<List<Feedback>> getFeedbackByCategory(String category) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category)
          .orderBy('submittedAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => Feedback.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching feedback by category: $e');
      return [];
    }
  }
}

// ============================================================
// RING PHOTO APPROVAL SERVICE
// ============================================================
class RingPhotoApprovalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'ring_photo_approvals';

  Future<void> submitForApproval(RingPhotoApproval approval) async {
    try {
      await _firestore.collection(_collection).doc(approval.id).set(approval.toJson());
    } catch (e) {
      print('Error submitting photo for approval: $e');
    }
  }

  Future<List<RingPhotoApproval>> getPendingApprovals() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => RingPhotoApproval.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching pending approvals: $e');
      return [];
    }
  }

  Future<void> approvePhoto(String approvalId, String adminId) async {
    try {
      await _firestore.collection(_collection).doc(approvalId).update({
        'status': 'approved',
        'approvedByAdminId': adminId,
        'approvalDate': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error approving photo: $e');
    }
  }

  Future<void> rejectPhoto(String approvalId, String reason) async {
    try {
      await _firestore.collection(_collection).doc(approvalId).update({
        'status': 'rejected',
        'rejectionReason': reason,
      });
    } catch (e) {
      print('Error rejecting photo: $e');
    }
  }
}

// ============================================================
// SYSTEM BOT SERVICE
// ============================================================
class SystemBotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'system_bots';

  Future<List<SystemBot>> getAllBots() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();
      
      return snapshot.docs
          .map((doc) => SystemBot.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching bots: $e');
      return [];
    }
  }

  Future<void> addBot(SystemBot bot) async {
    try {
      await _firestore.collection(_collection).doc(bot.id).set(bot.toJson());
    } catch (e) {
      print('Error adding bot: $e');
    }
  }

  Future<void> updateBotStatus(String botId, String status) async {
    try {
      await _firestore.collection(_collection).doc(botId).update({'status': status});
    } catch (e) {
      print('Error updating bot status: $e');
    }
  }

  Future<void> incrementBotActions(String botId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(botId)
          .update({'successfulActions': FieldValue.increment(1)});
    } catch (e) {
      print('Error incrementing bot actions: $e');
    }
  }

  Future<void> deactivateBot(String botId) async {
    try {
      await _firestore.collection(_collection).doc(botId).update({'isActive': false});
    } catch (e) {
      print('Error deactivating bot: $e');
    }
  }
}
