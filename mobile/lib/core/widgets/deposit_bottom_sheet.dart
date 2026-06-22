import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/network/remote_config_service.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:dailyearn99/core/network/api_client.dart';

class AdminBankDetailModel {
  final int id;
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String? upiId;
  final bool isDefault;

  AdminBankDetailModel({
    required this.id,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    this.upiId,
    required this.isDefault,
  });

  factory AdminBankDetailModel.fromJson(Map<String, dynamic> json) {
    return AdminBankDetailModel(
      id: json['id'] as int? ?? 0,
      bankName: json['bank_name'] as String? ?? '',
      accountHolderName: json['account_holder_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      ifscCode: json['ifsc_code'] as String? ?? '',
      upiId: json['upi_id'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }
}

class DepositBottomSheet extends StatefulWidget {
  final double? defaultAmount;
  final VoidCallback? onSuccess;

  const DepositBottomSheet({super.key, this.defaultAmount, this.onSuccess});

  static void show(
    BuildContext context, {
    double? defaultAmount,
    VoidCallback? onSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DepositBottomSheet(
        defaultAmount: defaultAmount,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<DepositBottomSheet> createState() => _DepositBottomSheetState();
}

class _DepositBottomSheetState extends State<DepositBottomSheet> {
  late final TextEditingController _manualAmountController;
  late final TextEditingController _utrController;

  int _activeManualSubTab = 0; // 0 for UPI, 1 for Bank Details

  List<AdminBankDetailModel> _bankDetails = [];
  AdminBankDetailModel? _selectedBankDetail;
  bool _isLoadingBankDetails = true;
  String? _bankDetailsError;

  @override
  void initState() {
    super.initState();
    final initialAmtStr = widget.defaultAmount != null
        ? widget.defaultAmount!.ceil().toString()
        : '500';
    _manualAmountController = TextEditingController(text: initialAmtStr);
    _utrController = TextEditingController();

    // Determine initial active manual subtab based on backend config method
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final backendConfig = context.read<AppBloc>().state.backendConfig;
        final method = backendConfig?.addAmountMethod ?? "UPI";
        if (method == "BANK") {
          setState(() {
            _activeManualSubTab = 1;
          });
        } else {
          setState(() {
            _activeManualSubTab = 0;
          });
        }
      }
    });

    _fetchBankDetails();
  }

  Future<void> _fetchBankDetails() async {
    try {
      final response = await getIt<ApiClient>().get('/wallet/bank-details');
      final data = response.data as List;
      final list = data.map((json) => AdminBankDetailModel.fromJson(json)).toList();
      if (mounted) {
        setState(() {
          _bankDetails = list;
          _isLoadingBankDetails = false;
          if (_bankDetails.isNotEmpty) {
            _selectedBankDetail = _bankDetails.firstWhere(
              (element) => element.isDefault,
              orElse: () => _bankDetails.first,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBankDetails = false;
          _bankDetailsError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _manualAmountController.dispose();
    _utrController.dispose();
    super.dispose();
  }

  void _selectPresetAmount(double amount) {
    setState(() {
      _manualAmountController.text = amount.toInt().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final blocState = context.read<AppBloc>().state;
    final backendConfig = blocState.backendConfig;
    final remoteConfig = getIt<RemoteConfigService>();

    final String method = backendConfig?.addAmountMethod ?? "UPI";

    final String upiId = _selectedBankDetail?.upiId?.isNotEmpty == true
        ? _selectedBankDetail!.upiId!
        : (backendConfig?.adminUpiId.isNotEmpty == true
            ? backendConfig!.adminUpiId
            : remoteConfig.adminUpiId);
    final String bankHolder = _selectedBankDetail?.accountHolderName.isNotEmpty == true
        ? _selectedBankDetail!.accountHolderName
        : (backendConfig?.adminBankHolder.isNotEmpty == true
            ? backendConfig!.adminBankHolder
            : remoteConfig.adminBankHolder);
    final String bankName = _selectedBankDetail?.bankName.isNotEmpty == true
        ? _selectedBankDetail!.bankName
        : (backendConfig?.adminBankName.isNotEmpty == true
            ? backendConfig!.adminBankName
            : remoteConfig.adminBankName);
    final String bankAccount = _selectedBankDetail?.accountNumber.isNotEmpty == true
        ? _selectedBankDetail!.accountNumber
        : (backendConfig?.adminBankAccount.isNotEmpty == true
            ? backendConfig!.adminBankAccount
            : remoteConfig.adminBankAccount);
    final String bankIfsc = _selectedBankDetail?.ifscCode.isNotEmpty == true
        ? _selectedBankDetail!.ifscCode
        : (backendConfig?.adminBankIfsc.isNotEmpty == true
            ? backendConfig!.adminBankIfsc
            : remoteConfig.adminBankIfsc);
    final String supportPhone = backendConfig?.contactPhone.isNotEmpty == true
        ? backendConfig!.contactPhone
        : remoteConfig.adminContactPhone;
    final String supportEmail = backendConfig?.contactEmail.isNotEmpty == true
        ? backendConfig!.contactEmail
        : remoteConfig.adminContactEmail;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header handle indicator
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Instant Manual Payout',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentCyan,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.defaultAmount != null
                      ? 'Transfer shortfall of ₹${widget.defaultAmount!.toStringAsFixed(2)} to Admin details below. After payment is complete, enter UTR number to verify.'
                      : 'Transfer payment to the Admin details below. After payment is complete, enter the transaction UTR number to instantly credit your wallet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 20),
                if (_isLoadingBankDetails)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(color: AppTheme.accentCyan),
                    ),
                  )
                else if (_bankDetails.length > 1) ...[
                  const Text(
                    'SELECT DEPOSIT ACCOUNT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderCol),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AdminBankDetailModel>(
                        value: _selectedBankDetail,
                        dropdownColor: AppTheme.cardBg,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.accentCyan),
                        items: _bankDetails.map((detail) {
                          return DropdownMenuItem<AdminBankDetailModel>(
                            value: detail,
                            child: Text(
                              '${detail.bankName} - ${detail.accountHolderName}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedBankDetail = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  const SizedBox(height: 20),
                ],

                // Manual Sub-Switcher
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderCol),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeManualSubTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _activeManualSubTab == 0
                                  ? AppTheme.accentCyan.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: _activeManualSubTab == 0
                                  ? Border.all(
                                      color: AppTheme.accentCyan.withOpacity(
                                        0.5,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'UPI Transfer',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _activeManualSubTab == 0
                                      ? AppTheme.accentCyan
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeManualSubTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _activeManualSubTab == 1
                                  ? AppTheme.accentPurple.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: _activeManualSubTab == 1
                                  ? Border.all(
                                      color: AppTheme.accentPurple.withOpacity(
                                        0.5,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Bank Account',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _activeManualSubTab == 1
                                      ? AppTheme.accentPurple
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // UPI Card
                if (_activeManualSubTab == 0)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTheme.borderCol),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'OFFICIAL UPI ADDRESS',
                            style: TextStyle(
                              fontSize: 8,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: SelectableText(
                                  upiId,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.copy,
                                  color: AppTheme.accentCyan,
                                  size: 18,
                                ),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: upiId));
                                  ScaffoldMessenger.of(context)
                                    ..clearSnackBars()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'UPI ID copied to clipboard.',
                                        ),
                                        backgroundColor: AppTheme.accentCyan,
                                      ),
                                    );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bank Card
                if (_activeManualSubTab == 1)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTheme.borderCol),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildDetailRow(context, 'BANK NAME', bankName),
                          const Divider(color: AppTheme.borderCol, height: 16),
                          _buildDetailRow(context, 'HOLDER NAME', bankHolder),
                          const Divider(color: AppTheme.borderCol, height: 16),
                          _buildDetailRow(
                            context,
                            'ACCOUNT NUMBER',
                            bankAccount,
                          ),
                          const Divider(color: AppTheme.borderCol, height: 16),
                          _buildDetailRow(context, 'IFSC CODE', bankIfsc),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Support block
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderCol),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.support_agent,
                            color: AppTheme.accentAmber,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ADMIN SUPPORT & QUERIES',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentAmber,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Phone: $supportPhone',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: supportPhone),
                              );
                              ScaffoldMessenger.of(context)
                                ..clearSnackBars()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Support phone copied.'),
                                    backgroundColor: AppTheme.accentAmber,
                                  ),
                                );
                            },
                            child: const Text(
                              'COPY',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.accentAmber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Email: $supportEmail',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: supportEmail),
                              );
                              ScaffoldMessenger.of(context)
                                ..clearSnackBars()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Support email copied.'),
                                    backgroundColor: AppTheme.accentAmber,
                                  ),
                                );
                            },
                            child: const Text(
                              'COPY',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.accentAmber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Inputs Block
                const Text(
                  'SUBMIT PAYMENT RECEIPT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _manualAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount Paid (₹)',
                    hintText: 'Enter amount paid',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _utrController,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: 'UTR / Transaction ID',
                    hintText: '12-digit payment transaction number',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                _buildPresetsRow(),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () {
                    final double? amt = double.tryParse(
                      _manualAmountController.text.trim(),
                    );
                    final String utr = _utrController.text.trim();

                    if (amt == null || amt <= 0.0) {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid amount.'),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                      return;
                    }
                    if (utr.length != 12) {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a valid 12-digit UTR/Reference ID.',
                            ),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                      return;
                    }

                    // Close bottom sheet
                    Navigator.pop(context);

                    // Dispatch manual deposit
                    context.read<AppBloc>().add(
                      DepositMoneyEvent(amt, utr: utr),
                    );

                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            'Deposit request of ₹${amt.toStringAsFixed(2)} submitted successfully for verification! (UTR: $utr)',
                          ),
                          backgroundColor: AppTheme.accentEmerald,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text('I HAVE PAID - CONFIRM DEPOSIT'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetsRow() {
    final List<double> basePresets = [100, 500, 1000, 2000];
    final List<double> presets = [];

    // Add shortfall to presets if exists
    if (widget.defaultAmount != null) {
      final double shortfallCeil = widget.defaultAmount!.ceilToDouble();
      if (shortfallCeil > 0) {
        presets.add(shortfallCeil);
      }
    }

    // Add remaining presets
    for (var p in basePresets) {
      if (!presets.contains(p)) {
        presets.add(p);
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: presets.map((amt) {
          final isShortfall =
              widget.defaultAmount != null &&
              amt == widget.defaultAmount!.ceilToDouble();
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              label: Text(
                isShortfall ? '₹${amt.toInt()} (Need)' : '₹${amt.toInt()}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isShortfall ? Colors.black : Colors.white70,
                ),
              ),
              backgroundColor: isShortfall
                  ? AppTheme.accentCyan
                  : AppTheme.cardBg,
              side: BorderSide(
                color: isShortfall ? AppTheme.accentCyan : AppTheme.borderCol,
              ),
              onPressed: () => _selectPresetAmount(amt),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 8,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 14, color: AppTheme.accentCyan),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text('$label copied to clipboard.'),
                  backgroundColor: AppTheme.accentCyan,
                ),
              );
          },
        ),
      ],
    );
  }
}
