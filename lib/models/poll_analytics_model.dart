import 'package:cloud_firestore/cloud_firestore.dart';

/// Anket Sonuçları Analizi
class PollResults {
  final String pollId;
  final int totalVotes;
  final List<OptionResult> optionResults;
  final DateTime analysisDate;
  final Map<String, int> votesByUniversity;

  PollResults({
    required this.pollId,
    required this.totalVotes,
    required this.optionResults,
    required this.analysisDate,
    required this.votesByUniversity,
  });

  factory PollResults.fromMap(Map<String, dynamic> data) {
    return PollResults(
      pollId: data['pollId'] ?? '',
      totalVotes: (data['totalVotes'] ?? 0).toInt(),
      optionResults: (data['optionResults'] as List?)
              ?.map((e) => OptionResult.fromMap(e))
              .toList() ??
          [],
      analysisDate: (data['analysisDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      votesByUniversity: Map<String, int>.from(
          data['votesByUniversity']?.cast<String, int>() ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pollId': pollId,
      'totalVotes': totalVotes,
      'optionResults': optionResults.map((e) => e.toMap()).toList(),
      'analysisDate': Timestamp.fromDate(analysisDate),
      'votesByUniversity': votesByUniversity,
    };
  }

  double getOptionPercentage(int optionIndex) {
    if (totalVotes == 0) return 0;
    if (optionIndex >= optionResults.length) return 0;
    return (optionResults[optionIndex].voteCount / totalVotes) * 100;
  }

  int? getWinningOption() {
    if (optionResults.isEmpty) return null;
    int maxVotes = optionResults[0].voteCount;
    int winningIndex = 0;
    for (int i = 1; i < optionResults.length; i++) {
      if (optionResults[i].voteCount > maxVotes) {
        maxVotes = optionResults[i].voteCount;
        winningIndex = i;
      }
    }
    return winningIndex;
  }
}

/// Seçenek Sonuçları
class OptionResult {
  final String optionText;
  final int voteCount;
  final double percentage;
  final String emoji;

  OptionResult({
    required this.optionText,
    required this.voteCount,
    required this.percentage,
    required this.emoji,
  });

  factory OptionResult.fromMap(Map<String, dynamic> data) {
    return OptionResult(
      optionText: data['optionText'] ?? '',
      voteCount: (data['voteCount'] ?? 0).toInt(),
      percentage: (data['percentage'] ?? 0.0).toDouble(),
      emoji: data['emoji'] ?? '👍',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'optionText': optionText,
      'voteCount': voteCount,
      'percentage': percentage,
      'emoji': emoji,
    };
  }
}

/// Anket Trendi
class PollTrend {
  final String pollId;
  final String title;
  final int currentVotes;
  final int dailyVoteIncrease;
  final bool isTrending;
  final DateTime trendStartDate;
  final String trendCategory;

  PollTrend({
    required this.pollId,
    required this.title,
    required this.currentVotes,
    required this.dailyVoteIncrease,
    required this.isTrending,
    required this.trendStartDate,
    required this.trendCategory,
  });

  factory PollTrend.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PollTrend(
      pollId: doc.id,
      title: data['title'] ?? 'Anket',
      currentVotes: (data['currentVotes'] ?? 0).toInt(),
      dailyVoteIncrease: (data['dailyVoteIncrease'] ?? 0).toInt(),
      isTrending: data['isTrending'] ?? false,
      trendStartDate: (data['trendStartDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      trendCategory: data['trendCategory'] ?? 'general',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'currentVotes': currentVotes,
      'dailyVoteIncrease': dailyVoteIncrease,
      'isTrending': isTrending,
      'trendStartDate': Timestamp.fromDate(trendStartDate),
      'trendCategory': trendCategory,
    };
  }

  bool isTrendingNow() {
    return isTrending && dailyVoteIncrease >= 10;
  }
}

/// Anket Raporu
class PollReport {
  final String reportId;
  final String pollId;
  final String reporterUserId;
  final String reason; // "inappropriate", "spam", "misleading", "other"
  final String description;
  final DateTime createdAt;
  final String status; // "pending", "reviewed", "dismissed", "action_taken"

  PollReport({
    required this.reportId,
    required this.pollId,
    required this.reporterUserId,
    required this.reason,
    required this.description,
    required this.createdAt,
    required this.status,
  });

  factory PollReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PollReport(
      reportId: doc.id,
      pollId: data['pollId'] ?? '',
      reporterUserId: data['reporterUserId'] ?? '',
      reason: data['reason'] ?? 'other',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pollId': pollId,
      'reporterUserId': reporterUserId,
      'reason': reason,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }
}
