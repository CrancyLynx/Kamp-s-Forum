import 'package:cloud_firestore/cloud_firestore.dart';

/// Sistem Bot Sistemi - Otomatik görevleri yönetir
class SystemBot {
  final String id;
  final String name;
  final String description;
  final String avatar;
  final String status; // "active", "inactive", "maintenance"
  final String version;
  final List<String> capabilities; // "moderation", "announcements", "statistics", etc.
  final int responseTime; // milliseconds
  final int taskCount;
  final int completedTasks;
  final DateTime createdAt;
  final DateTime lastActivityAt;
  final Map<String, dynamic> config;
  final bool isVerified;

  SystemBot({
    required this.id,
    required this.name,
    required this.description,
    required this.avatar,
    required this.status,
    required this.version,
    required this.capabilities,
    required this.responseTime,
    required this.taskCount,
    required this.completedTasks,
    required this.createdAt,
    required this.lastActivityAt,
    required this.config,
    required this.isVerified,
  });

  factory SystemBot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SystemBot(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      avatar: data['avatar'] ?? '',
      status: data['status'] ?? 'active',
      version: data['version'] ?? '1.0.0',
      capabilities: List<String>.from(data['capabilities'] ?? []),
      responseTime: (data['responseTime'] ?? 0).toInt(),
      taskCount: (data['taskCount'] ?? 0).toInt(),
      completedTasks: (data['completedTasks'] ?? 0).toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActivityAt: (data['lastActivityAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      config: Map<String, dynamic>.from(data['config'] ?? {}),
      isVerified: data['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'avatar': avatar,
      'status': status,
      'version': version,
      'capabilities': capabilities,
      'responseTime': responseTime,
      'taskCount': taskCount,
      'completedTasks': completedTasks,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActivityAt': Timestamp.fromDate(lastActivityAt),
      'config': config,
      'isVerified': isVerified,
    };
  }

  double get successRate {
    if (taskCount == 0) return 0;
    return (completedTasks / taskCount) * 100;
  }

  bool get isActive => status == 'active';
}

/// Bot Task
class BotTask {
  final String id;
  final String botId;
  final String taskType; // "announcement", "moderation", "cleanup", "sync"
  final String title;
  final String description;
  final String status; // "pending", "in_progress", "completed", "failed"
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? error;
  final int retryCount;
  final int maxRetries;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic> result;

  BotTask({
    required this.id,
    required this.botId,
    required this.taskType,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.error,
    required this.retryCount,
    required this.maxRetries,
    required this.parameters,
    required this.result,
  });

  factory BotTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BotTask(
      id: doc.id,
      botId: data['botId'] ?? '',
      taskType: data['taskType'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      error: data['error'],
      retryCount: (data['retryCount'] ?? 0).toInt(),
      maxRetries: (data['maxRetries'] ?? 3).toInt(),
      parameters: Map<String, dynamic>.from(data['parameters'] ?? {}),
      result: Map<String, dynamic>.from(data['result'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'botId': botId,
      'taskType': taskType,
      'title': title,
      'description': description,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'error': error,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'parameters': parameters,
      'result': result,
    };
  }

  bool get canRetry => retryCount < maxRetries;

  Duration? get executionTime {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }
}

/// Bot Statistics
class BotStatistics {
  final String botId;
  final int totalTasks;
  final int completedTasks;
  final int failedTasks;
  final double averageResponseTime;
  final DateTime lastActivity;
  final DateTime period;

  BotStatistics({
    required this.botId,
    required this.totalTasks,
    required this.completedTasks,
    required this.failedTasks,
    required this.averageResponseTime,
    required this.lastActivity,
    required this.period,
  });

  factory BotStatistics.fromMap(Map<String, dynamic> data) {
    return BotStatistics(
      botId: data['botId'] ?? '',
      totalTasks: (data['totalTasks'] ?? 0).toInt(),
      completedTasks: (data['completedTasks'] ?? 0).toInt(),
      failedTasks: (data['failedTasks'] ?? 0).toInt(),
      averageResponseTime: (data['averageResponseTime'] ?? 0.0).toDouble(),
      lastActivity: (data['lastActivity'] as Timestamp?)?.toDate() ?? DateTime.now(),
      period: (data['period'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  double get successRate {
    if (totalTasks == 0) return 0;
    return (completedTasks / totalTasks) * 100;
  }

  int get pendingTasks => totalTasks - completedTasks - failedTasks;
}
