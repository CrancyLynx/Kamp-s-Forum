import 'package:cloud_firestore/cloud_firestore.dart';

/// Sınav Takvimi Sistemi
class ExamCalendar {
  final String id;
  final String name;
  final String description;
  final String subject;
  final String examType; // "midterm", "final", "quiz", "practical"
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final String room;
  final int totalStudents;
  final int registeredStudents;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final List<String> tags;
  final Map<String, dynamic> additionalInfo;

  ExamCalendar({
    required this.id,
    required this.name,
    required this.description,
    required this.subject,
    required this.examType,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.room,
    required this.totalStudents,
    required this.registeredStudents,
    required this.isPublished,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    required this.tags,
    required this.additionalInfo,
  });

  factory ExamCalendar.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamCalendar(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      subject: data['subject'] ?? '',
      examType: data['examType'] ?? 'quiz',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: data['location'] ?? '',
      room: data['room'] ?? '',
      totalStudents: (data['totalStudents'] ?? 0).toInt(),
      registeredStudents: (data['registeredStudents'] ?? 0).toInt(),
      isPublished: data['isPublished'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      additionalInfo: Map<String, dynamic>.from(data['additionalInfo'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'subject': subject,
      'examType': examType,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'location': location,
      'room': room,
      'totalStudents': totalStudents,
      'registeredStudents': registeredStudents,
      'isPublished': isPublished,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'tags': tags,
      'additionalInfo': additionalInfo,
    };
  }

  ExamCalendar copyWith({
    String? id,
    String? name,
    String? description,
    String? subject,
    String? examType,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    String? room,
    int? totalStudents,
    int? registeredStudents,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    List<String>? tags,
    Map<String, dynamic>? additionalInfo,
  }) {
    return ExamCalendar(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      examType: examType ?? this.examType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      room: room ?? this.room,
      totalStudents: totalStudents ?? this.totalStudents,
      registeredStudents: registeredStudents ?? this.registeredStudents,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      tags: tags ?? this.tags,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  /// Sınavın başlanmadı mı
  bool get isUpcoming => startDate.isAfter(DateTime.now());

  /// Sınav şu anda devam ediyor mu
  bool get isOngoing => !isUpcoming && endDate.isAfter(DateTime.now());

  /// Sınav bitti mi
  bool get isCompleted => endDate.isBefore(DateTime.now());

  /// Geri kalan saat
  int get hoursUntilStart => isUpcoming ? startDate.difference(DateTime.now()).inHours : 0;
}

/// Sınav Kayıdı
class ExamRegistration {
  final String id;
  final String examId;
  final String userId;
  final String userName;
  final String email;
  final DateTime registeredAt;
  final String status; // "registered", "confirmed", "attended", "absent", "withdrawn"
  final String? seatNumber;
  final bool received;
  final String? notes;

  ExamRegistration({
    required this.id,
    required this.examId,
    required this.userId,
    required this.userName,
    required this.email,
    required this.registeredAt,
    required this.status,
    this.seatNumber,
    required this.received,
    this.notes,
  });

  factory ExamRegistration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamRegistration(
      id: doc.id,
      examId: data['examId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      email: data['email'] ?? '',
      registeredAt: (data['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'registered',
      seatNumber: data['seatNumber'],
      received: data['received'] ?? false,
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'examId': examId,
      'userId': userId,
      'userName': userName,
      'email': email,
      'registeredAt': Timestamp.fromDate(registeredAt),
      'status': status,
      'seatNumber': seatNumber,
      'received': received,
      'notes': notes,
    };
  }
}
