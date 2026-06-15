class LotteryDrawModel {
  final int id;
  final String title;
  final double ticketPrice;
  final double prizePool;
  final DateTime drawTime;
  final int maxTickets;
  final int joinedTickets;
  final String status;
  final String? winningNumber;
  final DateTime createdAt;

  LotteryDrawModel({
    required this.id,
    required this.title,
    required this.ticketPrice,
    required this.prizePool,
    required this.drawTime,
    required this.maxTickets,
    required this.joinedTickets,
    required this.status,
    this.winningNumber,
    required this.createdAt,
  });

  factory LotteryDrawModel.fromJson(Map<String, dynamic> json) {
    return LotteryDrawModel(
      id: json['id'] as int,
      title: json['title'] as String,
      ticketPrice: (json['ticket_price'] as num).toDouble(),
      prizePool: (json['prize_pool'] as num).toDouble(),
      drawTime: DateTime.parse(json['draw_time'] as String),
      maxTickets: json['max_tickets'] as int,
      joinedTickets: json['joined_tickets'] as int,
      status: json['status'] as String,
      winningNumber: json['winning_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'ticket_price': ticketPrice,
      'prize_pool': prizePool,
      'draw_time': drawTime.toIso8601String(),
      'max_tickets': maxTickets,
      'joined_tickets': joinedTickets,
      'status': status,
      'winning_number': winningNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class LotteryTicketModel {
  final int id;
  final int userId;
  final int drawId;
  final String ticketNumber;
  final DateTime purchaseTime;
  final bool isWinner;
  final double rewardAmount;
  final String? drawTitle;
  final String? drawStatus;

  LotteryTicketModel({
    required this.id,
    required this.userId,
    required this.drawId,
    required this.ticketNumber,
    required this.purchaseTime,
    required this.isWinner,
    required this.rewardAmount,
    this.drawTitle,
    this.drawStatus,
  });

  factory LotteryTicketModel.fromJson(Map<String, dynamic> json) {
    return LotteryTicketModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      drawId: json['draw_id'] as int,
      ticketNumber: json['ticket_number'] as String,
      purchaseTime: DateTime.parse(json['purchase_time'] as String),
      isWinner: json['is_winner'] as bool,
      rewardAmount: (json['reward_amount'] as num).toDouble(),
      drawTitle: json['draw_title'] as String?,
      drawStatus: json['draw_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'draw_id': drawId,
      'ticket_number': ticketNumber,
      'purchase_time': purchaseTime.toIso8601String(),
      'is_winner': isWinner,
      'reward_amount': rewardAmount,
      'draw_title': drawTitle,
      'draw_status': drawStatus,
    };
  }
}
