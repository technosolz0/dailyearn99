class UserModel {
  final int id;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String phone;
  final String? email;
  final String referralCode;
  final String? referredBy;
  final double depositBalance;
  final double winningBalance;
  final double bonusBalance;
  final String kycStatus;
  final bool isBanned;
  final String? bankAccountNumber;
  final String? bankIfscCode;
  final String? bankAccountHolderName;
  final String? bankName;
  final List<int> joinedContestIds;
  final List<int> completedContestIds;
  final List<int> joinedWordContestIds;
  final List<int> completedWordContestIds;
  final List<int> joinedPuzzleContestIds;
  final List<int> completedPuzzleContestIds;
  final List<int> joinedFruitContestIds;
  final List<int> completedFruitContestIds;

  UserModel({
    required this.id,
    this.name,
    this.firstName,
    this.lastName,
    required this.phone,
    this.email,
    required this.referralCode,
    this.referredBy,
    required this.depositBalance,
    required this.winningBalance,
    required this.bonusBalance,
    required this.kycStatus,
    required this.isBanned,
    this.bankAccountNumber,
    this.bankIfscCode,
    this.bankAccountHolderName,
    this.bankName,
    required this.joinedContestIds,
    required this.completedContestIds,
    required this.joinedWordContestIds,
    required this.completedWordContestIds,
    required this.joinedPuzzleContestIds,
    required this.completedPuzzleContestIds,
    required this.joinedFruitContestIds,
    required this.completedFruitContestIds,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      referralCode: json['referral_code'] as String,
      referredBy: json['referred_by'] as String?,
      depositBalance: (json['deposit_balance'] as num).toDouble(),
      winningBalance: (json['winning_balance'] as num).toDouble(),
      bonusBalance: (json['bonus_balance'] as num).toDouble(),
      kycStatus: json['kyc_status'] as String,
      isBanned: json['is_banned'] as bool,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankIfscCode: json['bank_ifsc_code'] as String?,
      bankAccountHolderName: json['bank_account_holder_name'] as String?,
      bankName: json['bank_name'] as String?,
      joinedContestIds: (json['joined_contest_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      completedContestIds: (json['completed_contest_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      joinedWordContestIds: (json['joined_word_contest_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      completedWordContestIds: (json['completed_word_contest_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      joinedPuzzleContestIds: (json['joined_puzzle_contest_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      completedPuzzleContestIds: (json['completed_puzzle_contest_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      joinedFruitContestIds: (json['joined_fruit_contest_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      completedFruitContestIds: (json['completed_fruit_contest_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'referral_code': referralCode,
      'referred_by': referredBy,
      'deposit_balance': depositBalance,
      'winning_balance': winningBalance,
      'bonus_balance': bonusBalance,
      'kyc_status': kycStatus,
      'is_banned': isBanned,
      'bank_account_number': bankAccountNumber,
      'bank_ifsc_code': bankIfscCode,
      'bank_account_holder_name': bankAccountHolderName,
      'bank_name': bankName,
      'joined_contest_ids': joinedContestIds,
      'completed_contest_ids': completedContestIds,
      'joined_word_contest_ids': joinedWordContestIds,
      'completed_word_contest_ids': completedWordContestIds,
      'joined_puzzle_contest_ids': joinedPuzzleContestIds,
      'completed_puzzle_contest_ids': completedPuzzleContestIds,
      'joined_fruit_contest_ids': joinedFruitContestIds,
      'completed_fruit_contest_ids': completedFruitContestIds,
    };
  }

  double get totalBalance => depositBalance + winningBalance + bonusBalance;
}
