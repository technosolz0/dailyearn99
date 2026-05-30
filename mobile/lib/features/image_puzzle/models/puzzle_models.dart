class PuzzlePrizeRuleModel {
  final int minRank;
  final int maxRank;
  final double prize;

  PuzzlePrizeRuleModel({
    required this.minRank,
    required this.maxRank,
    required this.prize,
  });

  factory PuzzlePrizeRuleModel.fromJson(Map<String, dynamic> json) {
    return PuzzlePrizeRuleModel(
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

class PuzzleContestModel {
  final int id;
  final String title;
  final double entryFee;
  final int totalSlots;
  final int joinedSlots;
  final double prizePool;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final List<PuzzlePrizeRuleModel>? prizeRules;
  final String imageUrl;
  final int gridSize;
  final int durationSeconds;

  PuzzleContestModel({
    required this.id,
    required this.title,
    required this.entryFee,
    required this.totalSlots,
    required this.joinedSlots,
    required this.prizePool,
    required this.startTime,
    this.endTime,
    required this.status,
    this.prizeRules,
    required this.imageUrl,
    required this.gridSize,
    required this.durationSeconds,
  });

  factory PuzzleContestModel.fromJson(Map<String, dynamic> json) {
    return PuzzleContestModel(
      id: json['id'] as int,
      title: json['title'] as String,
      entryFee: (json['entry_fee'] as num).toDouble(),
      totalSlots: json['total_slots'] as int,
      joinedSlots: json['joined_slots'] as int,
      prizePool: (json['prize_pool'] as num).toDouble(),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      status: json['status'] as String,
      prizeRules: json['prize_rules'] != null
          ? (json['prize_rules'] as List)
              .map((item) => PuzzlePrizeRuleModel.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      imageUrl: json['image_url'] as String,
      gridSize: json['grid_size'] as int,
      durationSeconds: json['duration_seconds'] as int,
    );
  }
}

class PuzzlePieceModel {
  final int pieceId;
  final double x;
  final double y;
  final double width;
  final double height;
  final int correctPos;
  int currentPos;

  PuzzlePieceModel({
    required this.pieceId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.correctPos,
    required this.currentPos,
  });

  bool get isCorrect => correctPos == currentPos;
}

class MoveTelemetryModel {
  final int fromIndex;
  final int toIndex;
  final int dt; // delta milliseconds from started_at

  MoveTelemetryModel({
    required this.fromIndex,
    required this.toIndex,
    required this.dt,
  });

  Map<String, dynamic> toJson() {
    return {
      'from_index': fromIndex,
      'to_index': toIndex,
      'dt': dt,
    };
  }
}

class PuzzleSessionModel {
  final String sessionId;
  final List<int> shuffledLayout;
  final DateTime startedAt;
  final int gridSize;
  final int durationSeconds;
  final String imageUrl;
  final String signature;

  PuzzleSessionModel({
    required this.sessionId,
    required this.shuffledLayout,
    required this.startedAt,
    required this.gridSize,
    required this.durationSeconds,
    required this.imageUrl,
    required this.signature,
  });

  factory PuzzleSessionModel.fromJson(Map<String, dynamic> json) {
    return PuzzleSessionModel(
      sessionId: json['session_id'] as String,
      shuffledLayout: List<int>.from(json['shuffled_layout'] as List),
      startedAt: DateTime.parse(json['started_at'] as String),
      gridSize: json['grid_size'] as int,
      durationSeconds: json['duration_seconds'] as int,
      imageUrl: json['image_url'] as String,
      signature: json['signature'] as String,
    );
  }
}
