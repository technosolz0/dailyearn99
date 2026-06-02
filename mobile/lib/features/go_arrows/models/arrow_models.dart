class ArrowPrizeRuleModel {
  final int minRank;
  final int maxRank;
  final double prize;

  ArrowPrizeRuleModel({
    required this.minRank,
    required this.maxRank,
    required this.prize,
  });

  factory ArrowPrizeRuleModel.fromJson(Map<String, dynamic> json) {
    return ArrowPrizeRuleModel(
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

class ArrowContestModel {
  final int id;
  final String title;
  final double entryFee;
  final int totalSlots;
  final int joinedSlots;
  final double prizePool;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final List<ArrowPrizeRuleModel>? prizeRules;
  final int gridSize;
  final int durationSeconds;

  ArrowContestModel({
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
    required this.gridSize,
    required this.durationSeconds,
  });

  factory ArrowContestModel.fromJson(Map<String, dynamic> json) {
    return ArrowContestModel(
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
              .map((item) => ArrowPrizeRuleModel.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      gridSize: json['grid_size'] as int,
      durationSeconds: json['duration_seconds'] as int,
    );
  }

  bool get isFull => joinedSlots >= totalSlots;
}

class ArrowBlockModel {
  final int id;
  final int row;
  final int col;
  final String direction; // 'UP', 'DOWN', 'LEFT', 'RIGHT'
  bool isCleared;

  ArrowBlockModel({
    required this.id,
    required this.row,
    required this.col,
    required this.direction,
    this.isCleared = false,
  });

  factory ArrowBlockModel.fromJson(Map<String, dynamic> json) {
    return ArrowBlockModel(
      id: json['id'] as int,
      row: json['row'] as int,
      col: json['col'] as int,
      direction: json['dir'] as String,
      isCleared: json['is_cleared'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'row': row,
      'col': col,
      'dir': direction,
      'is_cleared': isCleared,
    };
  }
}

class TapTelemetryModel {
  final int blockId;
  final int dt; // delta milliseconds from started_at
  final bool success;

  TapTelemetryModel({
    required this.blockId,
    required this.dt,
    required this.success,
  });

  Map<String, dynamic> toJson() {
    return {
      'block_id': blockId,
      'dt': dt,
      'success': success,
    };
  }
}

class ArrowSessionModel {
  final String sessionId;
  final List<ArrowBlockModel> layout;
  final DateTime startedAt;
  final int gridSize;
  final int durationSeconds;
  final String signature;

  ArrowSessionModel({
    required this.sessionId,
    required this.layout,
    required this.startedAt,
    required this.gridSize,
    required this.durationSeconds,
    required this.signature,
  });

  factory ArrowSessionModel.fromJson(Map<String, dynamic> json) {
    return ArrowSessionModel(
      sessionId: json['session_id'] as String,
      layout: (json['layout'] as List)
          .map((item) => ArrowBlockModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      startedAt: DateTime.parse(json['started_at'] as String),
      gridSize: json['grid_size'] as int,
      durationSeconds: json['duration_seconds'] as int,
      signature: json['signature'] as String,
    );
  }
}
