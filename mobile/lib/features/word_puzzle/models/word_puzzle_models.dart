import 'dart:convert';

class WordPrizeRuleModel {
  final int minRank;
  final int maxRank;
  final double prize;

  WordPrizeRuleModel({
    required this.minRank,
    required this.maxRank,
    required this.prize,
  });

  factory WordPrizeRuleModel.fromJson(Map<String, dynamic> json) {
    return WordPrizeRuleModel(
      minRank: json['min_rank'] as int,
      maxRank: json['max_rank'] as int,
      prize: (json['prize'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min_rank': minRank,
      'max_rank': maxRank,
      'prize': prize,
    };
  }
}

class WordContestModel {
  final int id;
  final String title;
  final double entryFee;
  final int totalSlots;
  final int joinedSlots;
  final double prizePool;
  final String difficulty;
  final String status;
  final List<WordPrizeRuleModel>? prizeRules;
  final int durationSeconds;
  final DateTime startTime;
  final DateTime endTime;

  WordContestModel({
    required this.id,
    required this.title,
    required this.entryFee,
    required this.totalSlots,
    required this.joinedSlots,
    required this.prizePool,
    required this.difficulty,
    required this.status,
    this.prizeRules,
    required this.durationSeconds,
    required this.startTime,
    required this.endTime,
  });

  factory WordContestModel.fromJson(Map<String, dynamic> json) {
    return WordContestModel(
      id: json['id'] as int,
      title: json['title'] as String,
      entryFee: (json['entry_fee'] as num).toDouble(),
      totalSlots: json['total_slots'] as int,
      joinedSlots: json['joined_slots'] as int,
      prizePool: (json['prize_pool'] as num).toDouble(),
      difficulty: json['difficulty'] as String,
      status: json['status'] as String,
      prizeRules: json['prize_rules'] != null
          ? (json['prize_rules'] as List)
              .map((item) => WordPrizeRuleModel.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      durationSeconds: json['duration_seconds'] as int,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
    );
  }
}

class WordQuestionModel {
  final int id;
  final String gameType; // 'WORD_SEARCH', 'UNSCRAMBLE', 'MISSING_LETTERS', 'CROSSWORD'
  final dynamic puzzleData; // Map or Grid representation depending on game type
  final dynamic clues; // Optional clues
  final int pointsReward;

  WordQuestionModel({
    required this.id,
    required this.gameType,
    required this.puzzleData,
    this.clues,
    required this.pointsReward,
  });

  factory WordQuestionModel.fromJson(Map<String, dynamic> json) {
    dynamic pData = json['puzzle_data'];
    if (pData is String) {
      try {
        pData = jsonDecode(pData);
      } catch (_) {}
    }
    dynamic cData = json['clues'];
    if (cData is String) {
      try {
        cData = jsonDecode(cData);
      } catch (_) {}
    }

    return WordQuestionModel(
      id: json['id'] as int,
      gameType: json['game_type'] as String,
      puzzleData: pData,
      clues: cData,
      pointsReward: json['points_reward'] as int,
    );
  }
}

class WordLeaderboardItemModel {
  final int userId;
  final String name;
  final int score;
  final double completionTimeSeconds;
  final int rank;
  final double prizeAmount;

  WordLeaderboardItemModel({
    required this.userId,
    required this.name,
    required this.score,
    required this.completionTimeSeconds,
    required this.rank,
    required this.prizeAmount,
  });

  factory WordLeaderboardItemModel.fromJson(Map<String, dynamic> json) {
    return WordLeaderboardItemModel(
      userId: json['user_id'] as int,
      name: json['name'] as String,
      score: json['score'] as int,
      completionTimeSeconds: (json['completion_time_seconds'] as num).toDouble(),
      rank: json['rank'] as int,
      prizeAmount: (json['prize_amount'] as num).toDouble(),
    );
  }
}

class WordStartSessionResponse {
  final String sessionId;
  final double entryFeeDeducted;

  WordStartSessionResponse({
    required this.sessionId,
    required this.entryFeeDeducted,
  });

  factory WordStartSessionResponse.fromJson(Map<String, dynamic> json) {
    return WordStartSessionResponse(
      sessionId: json['session_id'] as String,
      entryFeeDeducted: (json['entry_fee_deducted'] as num).toDouble(),
    );
  }
}

class WordSessionQuestionsResponse {
  final List<WordQuestionModel> questions;
  final int durationSeconds;
  final DateTime startedAt;
  final String signature;

  WordSessionQuestionsResponse({
    required this.questions,
    required this.durationSeconds,
    required this.startedAt,
    required this.signature,
  });

  factory WordSessionQuestionsResponse.fromJson(Map<String, dynamic> json) {
    return WordSessionQuestionsResponse(
      questions: (json['questions'] as List)
          .map((q) => WordQuestionModel.fromJson(q as Map<String, dynamic>))
          .toList(),
      durationSeconds: json['duration_seconds'] as int,
      startedAt: DateTime.parse(json['started_at'] as String),
      signature: json['signature'] as String,
    );
  }
}

class WordAnswerResponseModel {
  final bool isCorrect;
  final int netPoints;
  final int accumulatedScore;
  final double serverElapsedSeconds;

  WordAnswerResponseModel({
    required this.isCorrect,
    required this.netPoints,
    required this.accumulatedScore,
    required this.serverElapsedSeconds,
  });

  factory WordAnswerResponseModel.fromJson(Map<String, dynamic> json) {
    return WordAnswerResponseModel(
      isCorrect: json['is_correct'] as bool,
      netPoints: json['net_points'] as int,
      accumulatedScore: json['accumulated_score'] as int,
      serverElapsedSeconds: (json['server_elapsed_seconds'] as num).toDouble(),
    );
  }
}
