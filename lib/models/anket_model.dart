import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir Anket (Poll) Modeli
class Anket {
  final String id;
  final String createdByUserId;
  final String createdByName;
  final String title;
  final String description;
  final List<PollOption> options; // 2-5 secenekler
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final int totalVotes;
  final String category; // "egitim", "sosyal", "teknik", "diger"
  final List<String> voterIds; // Kimin oy verdigini track et
  
  Anket({
    required this.id,
    required this.createdByUserId,
    required this.createdByName,
    required this.title,
    required this.description,
    required this.options,
    required this.createdAt,
    required this.expiresAt,
    required this.isActive,
    required this.totalVotes,
    required this.category,
    required this.voterIds,
  });

  factory Anket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final optionsData = data['options'] as List? ?? [];
    
    return Anket(
      id: doc.id,
      createdByUserId: data['createdByUserId'] ?? '',
      createdByName: data['createdByName'] ?? 'Bilinmeyen',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      options: optionsData
          .map((o) => PollOption.fromMap(o as Map<String, dynamic>))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      totalVotes: (data['totalVotes'] as num?)?.toInt() ?? 0,
      category: data['category'] ?? 'diger',
      voterIds: List<String>.from(data['voterIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'title': title,
      'description': description,
      'options': options.map((o) => o.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': isActive,
      'totalVotes': totalVotes,
      'category': category,
      'voterIds': voterIds,
    };
  }

  bool isExpired() {
    return DateTime.now().isAfter(expiresAt);
  }

  double getPercentage(int voteCount) {
    if (totalVotes == 0) return 0;
    return (voteCount / totalVotes) * 100;
  }
}

/// Anket Secenegi
class PollOption {
  final String id;
  final String text;
  final int voteCount;
  final List<String> voterIds;
  final String emoji;
  
  PollOption({
    required this.id,
    required this.text,
    required this.voteCount,
    required this.voterIds,
    required this.emoji,
  });

  factory PollOption.fromMap(Map<String, dynamic> data) {
    return PollOption(
      id: data['id'] ?? '',
      text: data['text'] ?? '',
      voteCount: (data['voteCount'] as num?)?.toInt() ?? 0,
      voterIds: List<String>.from(data['voterIds'] ?? []),
      emoji: data['emoji'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'voteCount': voteCount,
      'voterIds': voterIds,
      'emoji': emoji,
    };
  }
}

/// Kullanici oy gecmisi
class PollVoteHistory {
  final String id;
  final String pollId;
  final String userId;
  final String optionId;
  final DateTime votedAt;
  
  PollVoteHistory({
    required this.id,
    required this.pollId,
    required this.userId,
    required this.optionId,
    required this.votedAt,
  });

  factory PollVoteHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PollVoteHistory(
      id: doc.id,
      pollId: data['pollId'] ?? '',
      userId: data['userId'] ?? '',
      optionId: data['optionId'] ?? '',
      votedAt: (data['votedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pollId': pollId,
      'userId': userId,
      'optionId': optionId,
      'votedAt': Timestamp.fromDate(votedAt),
    };
  }
}
