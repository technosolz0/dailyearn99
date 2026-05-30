import 'dart:convert';

class FruitPrizeRuleModel {
  final int minRank;
  final int maxRank;
  final double prize;

  FruitPrizeRuleModel({
    required this.minRank,
    required this.maxRank,
    required this.prize,
  });

  factory FruitPrizeRuleModel.fromJson(Map<String, dynamic> json) {
    return FruitPrizeRuleModel(
      minRank: json['min_rank'] ?? 0,
      maxRank: json['max_rank'] ?? 0,
      prize: (json['prize'] ?? 0.0).toDouble(),
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

class FruitContestModel {
  final int id;
  final String title;
  final double entryFee;
  final int totalSlots;
  final int joinedSlots;
  final double prizePool;
  final String status;
  final List<FruitPrizeRuleModel> prizeRules;
  final int durationSeconds;
  final String seed;
  final DateTime startTime;
  final DateTime endTime;

  FruitContestModel({
    required this.id,
    required this.title,
    required this.entryFee,
    required this.totalSlots,
    required this.joinedSlots,
    required this.prizePool,
    required this.status,
    required this.prizeRules,
    required this.durationSeconds,
    required this.seed,
    required this.startTime,
    required this.endTime,
  });

  factory FruitContestModel.fromJson(Map<String, dynamic> json) {
    var rulesList = json['prize_rules'];
    List<FruitPrizeRuleModel> parsedRules = [];
    if (rulesList != null) {
      if (rulesList is String) {
        try {
          var decoded = jsonDecode(rulesList) as List;
          parsedRules = decoded.map((r) => FruitPrizeRuleModel.fromJson(r)).toList();
        } catch (_) {}
      } else if (rulesList is List) {
        parsedRules = rulesList.map((r) => FruitPrizeRuleModel.fromJson(r)).toList();
      }
    }

    return FruitContestModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      entryFee: (json['entry_fee'] ?? 0.0).toDouble(),
      totalSlots: json['total_slots'] ?? 0,
      joinedSlots: json['joined_slots'] ?? 0,
      prizePool: (json['prize_pool'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'UPCOMING',
      prizeRules: parsedRules,
      durationSeconds: json['duration_seconds'] ?? 60,
      seed: json['seed'] ?? '',
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
    );
  }
}

class FruitSessionModel {
  final String sessionId;
  final String seed;
  final int durationSeconds;
  final String signature;
  final DateTime startedAt;

  FruitSessionModel({
    required this.sessionId,
    required this.seed,
    required this.durationSeconds,
    required this.signature,
    required this.startedAt,
  });

  factory FruitSessionModel.fromJson(Map<String, dynamic> json) {
    return FruitSessionModel(
      sessionId: json['session_id'] ?? '',
      seed: json['seed'] ?? '',
      durationSeconds: json['duration_seconds'] ?? 60,
      signature: json['signature'] ?? '',
      startedAt: DateTime.parse(json['started_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class CoordinateModel {
  final double x;
  final double y;
  final int? t;

  CoordinateModel({required this.x, required this.y, this.t});

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{'x': x, 'y': y};
    if (t != null) {
      data['t'] = t;
    }
    return data;
  }
}

class SlicedItemModel {
  final int id;
  final String itemType;
  final double sliceAngle;

  SlicedItemModel({
    required this.id,
    required this.itemType,
    required this.sliceAngle,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_type': itemType,
      'slice_angle': sliceAngle,
    };
  }
}

class SwipeTelemetryModel {
  final int timestampMs;
  final List<CoordinateModel> path;
  final List<SlicedItemModel> slicedItems;
  final bool isBombHit;

  SwipeTelemetryModel({
    required this.timestampMs,
    required this.path,
    required this.slicedItems,
    required this.isBombHit,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp_ms': timestampMs,
      'path': path.map((p) => p.toJson()).toList(),
      'sliced_items': slicedItems.map((s) => s.toJson()).toList(),
      'is_bomb_hit': isBombHit,
    };
  }
}

class FruitLeaderboardItemModel {
  final int userId;
  final String name;
  final int score;
  final int maxCombo;
  final int missCount;
  final int rank;
  final double prizeAmount;

  FruitLeaderboardItemModel({
    required this.userId,
    required this.name,
    required this.score,
    required this.maxCombo,
    required this.missCount,
    required this.rank,
    required this.prizeAmount,
  });

  factory FruitLeaderboardItemModel.fromJson(Map<String, dynamic> json) {
    return FruitLeaderboardItemModel(
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? 'Player',
      score: json['score'] ?? 0,
      maxCombo: json['max_combo'] ?? 0,
      missCount: json['miss_count'] ?? 0,
      rank: json['rank'] ?? 9999,
      prizeAmount: (json['prize_amount'] ?? 0.0).toDouble(),
    );
  }
}

class LocalSlicedItem {
  final int id;
  final String type;
  final double angle;

  LocalSlicedItem({
    required this.id,
    required this.type,
    required this.angle,
  });
}
