import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/models/user_model.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:dailyearn99/core/widgets/deposit_bottom_sheet.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _amountController = TextEditingController();
  final _panController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AppBloc>().add(FetchTransactionsEvent());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _panController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final user = state.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Wallet'),
            backgroundColor: AppTheme.darkBg,
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<AppBloc>().add(FetchTransactionsEvent());
              context.read<AppBloc>().add(LoadProfileEvent());
            },
            color: AppTheme.accentCyan,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Net Balance Summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text(
                            'NET WALLET BALANCE',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${user?.totalBalance.toStringAsFixed(2) ?? "0.00"}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: AppTheme.borderCol, height: 1),
                          const SizedBox(height: 16),

                          // Three Wallets list
                          _walletRow(
                            'Deposit Wallet',
                            'Added money for play',
                            '₹${user?.depositBalance.toStringAsFixed(2) ?? "0.00"}',
                            AppTheme.accentCyan,
                          ),
                          const SizedBox(height: 12),
                          _walletRow(
                            'Winning Wallet',
                            'Prize money (Withdrawal ok)',
                            '₹${user?.winningBalance.toStringAsFixed(2) ?? "0.00"}',
                            AppTheme.accentEmerald,
                          ),
                          const SizedBox(height: 12),
                          _walletRow(
                            'Bonus Wallet',
                            'Referral and cashbacks',
                            '₹${user?.bonusBalance.toStringAsFixed(2) ?? "0.00"}',
                            AppTheme.accentPurple,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions row (Add / Withdraw)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => DepositBottomSheet.show(context),
                          child: const Text('ADD MONEY'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (user?.bankAccountNumber == null ||
                                user!.bankAccountNumber!.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '⚠️ Please add your bank details below before withdrawing winnings.',
                                  ),
                                  backgroundColor: AppTheme.accentRed,
                                ),
                              );
                              return;
                            }
                            _showWithdrawalDialog(
                              context,
                              user.winningBalance,
                              user.kycStatus,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cardBg,
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.borderCol),
                          ),
                          child: const Text('WITHDRAW'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Bank Details Section
                  _buildBankDetailsCard(context, user),

                  const SizedBox(height: 32),

                  // Transaction History header
                  const Row(
                    children: [
                      Icon(Icons.history, color: AppTheme.accentCyan, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'TRANSACTION HISTORY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Transactions list
                  if (state.isWalletLoading && state.transactions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    )
                  else if (state.transactions.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No transactions recorded yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.transactions.length,
                      itemBuilder: (context, index) {
                        final tx = state.transactions[index];

                        IconData iconData = Icons.payment;
                        Color iconColor = AppTheme.accentCyan;
                        String prefixSign = '';

                        if (tx.type == 'DEPOSIT') {
                          iconData = Icons.add_circle_outline;
                          iconColor = AppTheme.accentEmerald;
                          prefixSign = '+';
                        } else if (tx.type == 'WITHDRAWAL') {
                          iconData = Icons.remove_circle_outline;
                          iconColor = AppTheme.accentRed;
                          prefixSign = '-';
                        } else if (tx.type == 'ENTRY_FEE') {
                          iconData = Icons.sports_esports_outlined;
                          iconColor = AppTheme.accentCyan;
                          prefixSign = '-';
                        } else if (tx.type == 'PRIZE_WIN') {
                          iconData = Icons.emoji_events_outlined;
                          iconColor = AppTheme.accentAmber;
                          prefixSign = '+';
                        } else if (tx.type == 'REFERRAL_BONUS') {
                          iconData = Icons.card_giftcard_outlined;
                          iconColor = AppTheme.accentPurple;
                          prefixSign = '+';
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(iconData, color: iconColor),
                            title: Text(
                              tx.type.replaceAll('_', ' '),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '${tx.createdAt.day}/${tx.createdAt.month} • Status: ${tx.status}',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            trailing: Text(
                              '$prefixSign₹${tx.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: prefixSign == '+'
                                    ? AppTheme.accentEmerald
                                    : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _walletRow(String title, String subtitle, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }


  void _showWithdrawalDialog(
    BuildContext context,
    double winBalance,
    String kycStatus,
  ) {
    _amountController.clear();
    _panController.clear();

    showDialog(
      context: context,
      builder: (ctx) {
        bool showKycStep = kycStatus != "VERIFIED";

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              title: Text(
                showKycStep ? 'Legal KYC Verification' : 'Withdraw Winnings',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showKycStep) ...[
                    const Text(
                      'Indian gaming laws require verification of a PAN card to process withdrawals.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _panController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Enter 10-character PAN number',
                        labelText: 'PAN Card Number',
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Available Winning Balance: ₹${winBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.accentEmerald,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Enter amount to withdraw',
                        prefixText: '₹ ',
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (showKycStep) {
                      final pan = _panController.text.trim().toUpperCase();
                      if (pan.length != 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Invalid PAN format (Must be 10 characters)',
                            ),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                        return;
                      }
                      // Move to amount step
                      setDialogState(() {
                        showKycStep = false;
                      });
                    } else {
                      final amt = double.tryParse(
                        _amountController.text.trim(),
                      );
                      if (amt == null || amt <= 0) return;
                      if (amt > winBalance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Withdrawal amount exceeds Winning Balance',
                            ),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                        return;
                      }

                      final pan = _panController.text.trim().toUpperCase();
                      Navigator.pop(ctx);

                      // Submit withdrawal request
                      context.read<AppBloc>().add(
                        WithdrawMoneyEvent(
                          amt,
                          pan.isNotEmpty
                              ? pan
                              : "ABCDE1234F", // fallback dummy PAN
                        ),
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Withdrawal request submitted! Pending Admin Approval.',
                          ),
                          backgroundColor: AppTheme.accentCyan,
                        ),
                      );
                    }
                  },
                  child: Text(showKycStep ? 'VERIFY PAN' : 'SUBMIT REQUEST'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBankDetailsCard(BuildContext context, UserModel? user) {
    final hasBankDetails =
        user?.bankAccountNumber != null && user!.bankAccountNumber!.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.account_balance,
                      color: AppTheme.accentCyan,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'BANK ACCOUNT DETAILS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _showBankDetailsDialog(context, user),
                  child: Text(
                    hasBankDetails ? 'EDIT' : 'ADD',
                    style: const TextStyle(
                      color: AppTheme.accentCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasBankDetails) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accentRed.withOpacity(0.15),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.accentRed,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bank account not set. Add bank details to enable winnings withdrawal.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _bankDetailRow(
                'Account Holder',
                user.bankAccountHolderName ?? '',
              ),
              const SizedBox(height: 8),
              _bankDetailRow('Bank Name', user.bankName ?? ''),
              const SizedBox(height: 8),
              _bankDetailRow(
                'Account Number',
                _maskAccountNumber(user.bankAccountNumber ?? ''),
              ),
              const SizedBox(height: 8),
              _bankDetailRow('IFSC Code', user.bankIfscCode ?? ''),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bankDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _maskAccountNumber(String number) {
    if (number.length <= 4) return number;
    return '${'x' * (number.length - 4)}${number.substring(number.length - 4)}';
  }

  void _showBankDetailsDialog(BuildContext context, UserModel? user) {
    final acNoController = TextEditingController(
      text: user?.bankAccountNumber ?? '',
    );
    final ifscController = TextEditingController(
      text: user?.bankIfscCode ?? '',
    );
    final nameController = TextEditingController(
      text: user?.bankAccountHolderName ?? '',
    );
    final bankController = TextEditingController(text: user?.bankName ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text(
            user?.bankAccountNumber != null
                ? 'Edit Bank Details'
                : 'Add Bank Details',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Account Holder Name',
                    hintText: 'Enter name on passbook',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Bank Name',
                    hintText: 'e.g. ICICI Bank',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: acNoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Account Number',
                    hintText: '9 to 18 digits number',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ifscController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'IFSC Code',
                    hintText: '11-digit IFSC code',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final acNo = acNoController.text.trim();
                final ifsc = ifscController.text.trim().toUpperCase();
                final name = nameController.text.trim();
                final bank = bankController.text.trim();

                if (name.isEmpty ||
                    bank.isEmpty ||
                    acNo.isEmpty ||
                    ifsc.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All fields are required.'),
                      backgroundColor: AppTheme.accentRed,
                    ),
                  );
                  return;
                }

                if (acNo.length < 9 || acNo.length > 18) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Account number must be between 9 and 18 digits.',
                      ),
                      backgroundColor: AppTheme.accentRed,
                    ),
                  );
                  return;
                }

                if (ifsc.length != 11) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('IFSC code must be exactly 11 characters.'),
                      backgroundColor: AppTheme.accentRed,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                context.read<AppBloc>().add(
                  SaveBankDetailsEvent(
                    accountNumber: acNo,
                    ifscCode: ifsc,
                    accountHolderName: name,
                    bankName: bank,
                  ),
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bank account details saved successfully!'),
                    backgroundColor: AppTheme.accentEmerald,
                  ),
                );
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    ).then((_) {
      acNoController.dispose();
      ifscController.dispose();
      nameController.dispose();
      bankController.dispose();
    });
  }
}
