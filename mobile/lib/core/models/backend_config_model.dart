class BackendConfigModel {
  final String addAmountMethod; // 'UPI' or 'BANK'
  final String adminUpiId;
  final String adminBankHolder;
  final String adminBankName;
  final String adminBankAccount;
  final String adminBankIfsc;
  final String contactEmail;
  final String contactPhone;

  BackendConfigModel({
    required this.addAmountMethod,
    required this.adminUpiId,
    required this.adminBankHolder,
    required this.adminBankName,
    required this.adminBankAccount,
    required this.adminBankIfsc,
    required this.contactEmail,
    required this.contactPhone,
  });

  factory BackendConfigModel.fromJson(Map<String, dynamic> json) {
    return BackendConfigModel(
      addAmountMethod: json['add_amount_method'] as String? ?? 'UPI',
      adminUpiId: json['admin_upi_id'] as String? ?? '',
      adminBankHolder: json['admin_bank_holder'] as String? ?? '',
      adminBankName: json['admin_bank_name'] as String? ?? '',
      adminBankAccount: json['admin_bank_account'] as String? ?? '',
      adminBankIfsc: json['admin_bank_ifsc'] as String? ?? '',
      contactEmail: json['contact_email'] as String? ?? '',
      contactPhone: json['contact_phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'add_amount_method': addAmountMethod,
      'admin_upi_id': adminUpiId,
      'admin_bank_holder': adminBankHolder,
      'admin_bank_name': adminBankName,
      'admin_bank_account': adminBankAccount,
      'admin_bank_ifsc': adminBankIfsc,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
    };
  }
}
