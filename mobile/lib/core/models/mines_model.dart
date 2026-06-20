class MinesGameModel {
  final int id;
  final double betAmount;
  final int minesCount;
  final List<int> revealedPositions;
  final double currentMultiplier;
  final double currentWin;
  final String status;
  final DateTime createdAt;
  final List<int>? minesPositions;
  final double? updatedBalance;

  MinesGameModel({
    required this.id,
    required this.betAmount,
    required this.minesCount,
    required this.revealedPositions,
    required this.currentMultiplier,
    required this.currentWin,
    required this.status,
    required this.createdAt,
    this.minesPositions,
    this.updatedBalance,
  });

  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isWon => status == 'WON';
  bool get isLost => status == 'LOST';

  factory MinesGameModel.fromJson(Map<String, dynamic> json) {
    return MinesGameModel(
      id: json['id'] as int,
      betAmount: (json['bet_amount'] as num).toDouble(),
      minesCount: json['mines_count'] as int,
      revealedPositions: List<int>.from(json['revealed_positions'] ?? []),
      currentMultiplier: (json['current_multiplier'] as num).toDouble(),
      currentWin: (json['current_win'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      minesPositions: json['mines_positions'] != null
          ? List<int>.from(json['mines_positions'])
          : null,
      updatedBalance: json['updated_balance'] != null
          ? (json['updated_balance'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bet_amount': betAmount,
      'mines_count': minesCount,
      'revealed_positions': revealedPositions,
      'current_multiplier': currentMultiplier,
      'current_win': currentWin,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'mines_positions': minesPositions,
      'updated_balance': updatedBalance,
    };
  }
}
