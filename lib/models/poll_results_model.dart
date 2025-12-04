import 'package:cloud_firestore/cloud_firestore.dart';

/// Anket Görselleştirme Sistemi
class PollResults {
  final String id;
  final String pollId;
  final String title;
  final String description;
  final List<PollOption> options;
  final int totalVotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final bool isActive;
  final bool allowMultiple;
  final List<String> voterIds;

  PollResults({
    required this.id,
    required this.pollId,
    required this.title,
    required this.description,
    required this.options,
    required this.totalVotes,
    required this.createdAt,
    this.updatedAt,
    this.expiresAt,
    required this.isActive,
    required this.allowMultiple,
    required this.voterIds,
  });

  factory PollResults.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final optionsList = (data['options'] as List?)
        ?.map((opt) => PollOption.fromMap(opt as Map<String, dynamic>))
        .toList() ?? [];
    return PollResults(
      id: doc.id,
      pollId: data['pollId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      options: optionsList,
      totalVotes: (data['totalVotes'] ?? 0).toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
      allowMultiple: data['allowMultiple'] ?? false,
      voterIds: List<String>.from(data['voterIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pollId': pollId,
      'title': title,
      'description': description,
      'options': options.map((o) => o.toMap()).toList(),
      'totalVotes': totalVotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
      'allowMultiple': allowMultiple,
      'voterIds': voterIds,
    };
  }
}

/// Anket Seçeneği
class PollOption {
  final String id;
  final String text;
  final int votes;
  final double percentage;
  final List<String> voterIds;

  PollOption({
    required this.id,
    required this.text,
    required this.votes,
    required this.percentage,
    required this.voterIds,
  });

  factory PollOption.fromMap(Map<String, dynamic> data) {
    return PollOption(
      id: data['id'] ?? '',
      text: data['text'] ?? '',
      votes: (data['votes'] ?? 0).toInt(),
      percentage: (data['percentage'] ?? 0.0).toDouble(),
      voterIds: List<String>.from(data['voterIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'votes': votes,
      'percentage': percentage,
      'voterIds': voterIds,
    };
  }

  PollOption copyWith({
    String? id,
    String? text,
    int? votes,
    double? percentage,
    List<String>? voterIds,
  }) {
    return PollOption(
      id: id ?? this.id,
      text: text ?? this.text,
      votes: votes ?? this.votes,
      percentage: percentage ?? this.percentage,
      voterIds: voterIds ?? this.voterIds,
    );
  }
}
