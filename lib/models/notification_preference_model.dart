import 'package:cloud_firestore/cloud_firestore.dart';

/// Bildirim Tercihleri Sistemi
class NotificationPreference {
  final String id;
  final String userId;
  
  // Genel Ayarlar
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool soundEnabled;
  final bool vibrationEnabled;
  
  // Kategori Bazlı Ayarlar
  final bool newsNotifications;
  final bool chatNotifications;
  final bool forumNotifications;
  final bool badgeNotifications;
  final bool eventNotifications;
  final bool gameNotifications;
  
  // Sessiz Saatler
  final bool quietHoursEnabled;
  final String? quietHoursStart; // HH:mm format
  final String? quietHoursEnd;
  
  // Bildirim Sıklığı
  final String frequency; // "instant", "hourly", "daily", "weekly"
  
  // Kişi Bazlı Bildirimler
  final Map<String, bool> userNotifications; // userId -> enabled
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  NotificationPreference({
    required this.id,
    required this.userId,
    required this.pushNotifications,
    required this.emailNotifications,
    required this.smsNotifications,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.newsNotifications,
    required this.chatNotifications,
    required this.forumNotifications,
    required this.badgeNotifications,
    required this.eventNotifications,
    required this.gameNotifications,
    required this.quietHoursEnabled,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.frequency,
    required this.userNotifications,
    required this.createdAt,
    this.updatedAt,
  });

  factory NotificationPreference.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationPreference(
      id: doc.id,
      userId: data['userId'] ?? '',
      pushNotifications: data['pushNotifications'] ?? true,
      emailNotifications: data['emailNotifications'] ?? true,
      smsNotifications: data['smsNotifications'] ?? false,
      soundEnabled: data['soundEnabled'] ?? true,
      vibrationEnabled: data['vibrationEnabled'] ?? true,
      newsNotifications: data['newsNotifications'] ?? true,
      chatNotifications: data['chatNotifications'] ?? true,
      forumNotifications: data['forumNotifications'] ?? true,
      badgeNotifications: data['badgeNotifications'] ?? true,
      eventNotifications: data['eventNotifications'] ?? true,
      gameNotifications: data['gameNotifications'] ?? true,
      quietHoursEnabled: data['quietHoursEnabled'] ?? false,
      quietHoursStart: data['quietHoursStart'],
      quietHoursEnd: data['quietHoursEnd'],
      frequency: data['frequency'] ?? 'instant',
      userNotifications: Map<String, bool>.from(data['userNotifications'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'pushNotifications': pushNotifications,
      'emailNotifications': emailNotifications,
      'smsNotifications': smsNotifications,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'newsNotifications': newsNotifications,
      'chatNotifications': chatNotifications,
      'forumNotifications': forumNotifications,
      'badgeNotifications': badgeNotifications,
      'eventNotifications': eventNotifications,
      'gameNotifications': gameNotifications,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'frequency': frequency,
      'userNotifications': userNotifications,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  NotificationPreference copyWith({
    String? id,
    String? userId,
    bool? pushNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? newsNotifications,
    bool? chatNotifications,
    bool? forumNotifications,
    bool? badgeNotifications,
    bool? eventNotifications,
    bool? gameNotifications,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    String? frequency,
    Map<String, bool>? userNotifications,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationPreference(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      newsNotifications: newsNotifications ?? this.newsNotifications,
      chatNotifications: chatNotifications ?? this.chatNotifications,
      forumNotifications: forumNotifications ?? this.forumNotifications,
      badgeNotifications: badgeNotifications ?? this.badgeNotifications,
      eventNotifications: eventNotifications ?? this.eventNotifications,
      gameNotifications: gameNotifications ?? this.gameNotifications,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      frequency: frequency ?? this.frequency,
      userNotifications: userNotifications ?? this.userNotifications,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
