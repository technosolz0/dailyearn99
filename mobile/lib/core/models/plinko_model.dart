class PlinkoPlayResultModel {
  final int id;
  final double betAmount;
  final int rows;
  final String mode;
  final List<int> path;
  final int finalBucket;
  final double multiplier;
  final double winAmount;
  final DateTime createdAt;
  final double updatedBalance;

  PlinkoPlayResultModel({
    required this.id,
    required this.betAmount,
    required this.rows,
    required this.mode,
    required this.path,
    required this.finalBucket,
    required this.multiplier,
    required this.winAmount,
    required this.createdAt,
    required this.updatedBalance,
  });

  factory PlinkoPlayResultModel.fromJson(Map<String, dynamic> json) {
    return PlinkoPlayResultModel(
      id: json['id'] as int,
      betAmount: (json['bet_amount'] as num).toDouble(),
      rows: json['rows'] as int,
      mode: json['mode'] as String,
      path: List<int>.from(json['path'] ?? []),
      finalBucket: json['final_bucket'] as int,
      multiplier: (json['multiplier'] as num).toDouble(),
      winAmount: (json['win_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedBalance: (json['updated_balance'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bet_amount': betAmount,
      'rows': rows,
      'mode': mode,
      'path': path,
      'final_bucket': finalBucket,
      'multiplier': multiplier,
      'win_amount': winAmount,
      'created_at': createdAt.toIso8601String(),
      'updated_balance': updatedBalance,
    };
  }
}

class PlinkoSettingsModel {
  final double minBet;
  final double maxBet;
  final bool maintenanceMode;

  PlinkoSettingsModel({
    required this.minBet,
    required this.maxBet,
    required this.maintenanceMode,
  });

  factory PlinkoSettingsModel.fromJson(Map<String, dynamic> json) {
    return PlinkoSettingsModel(
      minBet: (json['min_bet'] as num).toDouble(),
      maxBet: (json['max_bet'] as num).toDouble(),
      maintenanceMode: json['maintenance_mode'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min_bet': minBet,
      'max_bet': maxBet,
      'maintenance_mode': maintenanceMode,
    };
  }
}
