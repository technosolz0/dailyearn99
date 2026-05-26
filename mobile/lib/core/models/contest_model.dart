class PrizeRuleModel {
  final int minRank;
  final int maxRank;
  final double prize;

  PrizeRuleModel({
    required this.minRank,
    required this.maxRank,
    required this.prize,
  });

  factory PrizeRuleModel.fromJson(Map<String, dynamic> json) {
    return PrizeRuleModel(
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

class QuizQuestionModel {
  final String text;
  final List<String> options;
  final int correctAnswerIndex;

  QuizQuestionModel({
    required this.text,
    required this.options,
    required this.correctAnswerIndex,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      text: json['text'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswerIndex: json['correct_answer_index'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'options': options,
      'correct_answer_index': correctAnswerIndex,
    };
  }
}

class ContestModel {
  final int id;
  final String title;
  final double entryFee;
  final int totalSlots;
  final int joinedSlots;
  final double prizePool;
  final DateTime startTime;
  final String status;
  final List<PrizeRuleModel>? prizeRules;
  final List<QuizQuestionModel>? questions;

  ContestModel({
    required this.id,
    required this.title,
    required this.entryFee,
    required this.totalSlots,
    required this.joinedSlots,
    required this.prizePool,
    required this.startTime,
    required this.status,
    this.prizeRules,
    this.questions,
  });

  factory ContestModel.fromJson(Map<String, dynamic> json) {
    return ContestModel(
      id: json['id'] as int,
      title: json['title'] as String,
      entryFee: (json['entry_fee'] as num).toDouble(),
      totalSlots: json['total_slots'] as int,
      joinedSlots: json['joined_slots'] as int,
      prizePool: (json['prize_pool'] as num).toDouble(),
      startTime: DateTime.parse(json['start_time'] as String),
      status: json['status'] as String,
      prizeRules: json['prize_rules'] != null
          ? (json['prize_rules'] as List)
              .map((item) => PrizeRuleModel.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      questions: json['questions'] != null
          ? (json['questions'] as List)
              .map((item) => QuizQuestionModel.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'entry_fee': entryFee,
      'total_slots': totalSlots,
      'joined_slots': joinedSlots,
      'prize_pool': prizePool,
      'start_time': startTime.toIso8601String(),
      'status': status,
      'prize_rules': prizeRules?.map((r) => r.toJson()).toList(),
      'questions': questions?.map((q) => q.toJson()).toList(),
    };
  }

  bool get isFull => joinedSlots >= totalSlots;
}

class LeaderboardItemModel {
  final int userId;
  final String name;
  final int score;
  final int rank;

  LeaderboardItemModel({
    required this.userId,
    required this.name,
    required this.score,
    required this.rank,
  });

  factory LeaderboardItemModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardItemModel(
      userId: json['user_id'] as int,
      name: json['name'] as String,
      score: json['score'] as int,
      rank: json['rank'] as int,
    );
  }
}

class TransactionModel {
  final int id;
  final int userId;
  final String type;
  final double amount;
  final String status;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ReferralDetailsModel {
  final String referralCode;
  final int referralCount;
  final double bonusEarned;
  final List<ReferralHistoryItemModel> referrals;

  ReferralDetailsModel({
    required this.referralCode,
    required this.referralCount,
    required this.bonusEarned,
    required this.referrals,
  });

  factory ReferralDetailsModel.fromJson(Map<String, dynamic> json) {
    final referralsList = (json['referrals'] as List?)
            ?.map((item) => ReferralHistoryItemModel.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];
    return ReferralDetailsModel(
      referralCode: json['referral_code'] as String,
      referralCount: json['referral_count'] as int,
      bonusEarned: (json['bonus_earned'] as num).toDouble(),
      referrals: referralsList,
    );
  }
}

class ReferralHistoryItemModel {
  final String referredUserName;
  final String referredUserPhone;
  final bool bonusGiven;
  final DateTime createdAt;

  ReferralHistoryItemModel({
    required this.referredUserName,
    required this.referredUserPhone,
    required this.bonusGiven,
    required this.createdAt,
  });

  factory ReferralHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return ReferralHistoryItemModel(
      referredUserName: json['referred_user_name'] as String,
      referredUserPhone: json['referred_user_phone'] as String,
      bonusGiven: json['bonus_given'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
