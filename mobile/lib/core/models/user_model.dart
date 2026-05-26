class UserModel {
  final int id;
  final String? name;
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

  UserModel({
    required this.id,
    this.name,
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
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String?,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
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
    };
  }

  double get totalBalance => depositBalance + winningBalance + bonusBalance;
}
