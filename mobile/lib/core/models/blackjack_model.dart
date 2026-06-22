import 'dart:convert';

class BlackjackCardModel {
  final String suit;
  final String rank;
  final int value;

  BlackjackCardModel({
    required this.suit,
    required this.rank,
    required this.value,
  });

  factory BlackjackCardModel.fromJson(Map<String, dynamic> json) {
    return BlackjackCardModel(
      suit: json['suit'] as String,
      rank: json['rank'] as String,
      value: json['value'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'suit': suit,
      'rank': rank,
      'value': value,
    };
  }
}

class BlackjackGameModel {
  final int id;
  final int userId;
  final double betAmount;
  final bool isSplit;
  final double splitBetAmount;
  final List<BlackjackCardModel> playerHand1;
  final List<BlackjackCardModel> playerHand2;
  final List<BlackjackCardModel> dealerHand;
  final int currentHandIndex;
  final String hand1Status;
  final String hand2Status;
  final String status;
  final double winAmount;
  final DateTime createdAt;
  final double? updatedBalance;

  BlackjackGameModel({
    required this.id,
    required this.userId,
    required this.betAmount,
    required this.isSplit,
    required this.splitBetAmount,
    required this.playerHand1,
    required this.playerHand2,
    required this.dealerHand,
    required this.currentHandIndex,
    required this.hand1Status,
    required this.hand2Status,
    required this.status,
    required this.winAmount,
    required this.createdAt,
    this.updatedBalance,
  });

  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED';

  factory BlackjackGameModel.fromJson(Map<String, dynamic> json) {
    List<BlackjackCardModel> parseHand(dynamic handData) {
      if (handData == null) return [];
      if (handData is String) {
        try {
          final decoded = jsonDecode(handData) as List;
          return decoded
              .map((e) => BlackjackCardModel.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {
          return [];
        }
      }
      if (handData is List) {
        return handData
            .map((e) => BlackjackCardModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    return BlackjackGameModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      betAmount: (json['bet_amount'] as num).toDouble(),
      isSplit: json['is_split'] as bool? ?? false,
      splitBetAmount: (json['split_bet_amount'] as num? ?? 0.0).toDouble(),
      playerHand1: parseHand(json['player_hand_1']),
      playerHand2: parseHand(json['player_hand_2']),
      dealerHand: parseHand(json['dealer_hand']),
      currentHandIndex: json['current_hand_index'] as int? ?? 0,
      hand1Status: json['hand_1_status'] as String? ?? 'IN_PROGRESS',
      hand2Status: json['hand_2_status'] as String? ?? 'IN_PROGRESS',
      status: json['status'] as String,
      winAmount: (json['win_amount'] as num? ?? 0.0).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedBalance: json['updated_balance'] != null
          ? (json['updated_balance'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'bet_amount': betAmount,
      'is_split': isSplit,
      'split_bet_amount': splitBetAmount,
      'player_hand_1': playerHand1.map((e) => e.toJson()).toList(),
      'player_hand_2': playerHand2.map((e) => e.toJson()).toList(),
      'dealer_hand': dealerHand.map((e) => e.toJson()).toList(),
      'current_hand_index': currentHandIndex,
      'hand_1_status': hand1Status,
      'hand_2_status': hand2Status,
      'status': status,
      'win_amount': winAmount,
      'created_at': createdAt.toIso8601String(),
      'updated_balance': updatedBalance,
    };
  }
}

class BlackjackSettingsModel {
  final double minBet;
  final double maxBet;
  final double winningPercentage;
  final bool maintenanceMode;

  BlackjackSettingsModel({
    required this.minBet,
    required this.maxBet,
    required this.winningPercentage,
    required this.maintenanceMode,
  });

  factory BlackjackSettingsModel.fromJson(Map<String, dynamic> json) {
    return BlackjackSettingsModel(
      minBet: (json['min_bet'] as num).toDouble(),
      maxBet: (json['max_bet'] as num).toDouble(),
      winningPercentage:
          (json['winning_percentage'] as num? ?? 50.0).toDouble(),
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min_bet': minBet,
      'max_bet': maxBet,
      'winning_percentage': winningPercentage,
      'maintenance_mode': maintenanceMode,
    };
  }
}
