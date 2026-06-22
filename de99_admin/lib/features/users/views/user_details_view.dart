import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';
import 'package:de99_admin/features/users/bloc/users_cubit.dart';

class UserDetailsView extends StatefulWidget {
  final AdminUser user;

  const UserDetailsView({super.key, required this.user});

  @override
  State<UserDetailsView> createState() => _UserDetailsViewState();
}

class _UserDetailsViewState extends State<UserDetailsView> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  List<dynamic> _transactions = [];
  bool _isLoadingTxs = true;
  String? _txError;

  @override
  void initState() {
    super.initState();
    _fetchUserTransactions();
  }

  Future<void> _fetchUserTransactions() async {
    try {
      final response = await _apiClient.dio.get(
        '/admin/users/${widget.user.id}/transactions',
      );
      if (mounted) {
        setState(() {
          _transactions = response.data as List;
          _isLoadingTxs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _txError = e.toString();
          _isLoadingTxs = false;
        });
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AdminTheme.primary,
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, String value, {bool isCode = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AdminTheme.textMuted, fontSize: 14),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: AdminTheme.textMain,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: isCode ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
    );
    final totalBalance =
        widget.user.depositBalance +
        widget.user.winningBalance +
        widget.user.bonusBalance;

    return Scaffold(
      appBar: AppBar(title: Text(widget.user.name ?? 'User Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Meta Header Card
            Card(
              color: AdminTheme.surfaceDark,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AdminTheme.primary.withOpacity(0.1),
                      child: Text(
                        (widget.user.name?.isNotEmpty ?? false)
                            ? widget.user.name![0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.user.name ?? 'Anonymous User',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.user.phone}  •  ID: ${widget.user.id}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AdminTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // KYC Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (widget.user.kycStatus == 'VERIFIED'
                                        ? AdminTheme.success
                                        : AdminTheme.warning)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.user.kycStatus == 'VERIFIED'
                                  ? AdminTheme.success
                                  : AdminTheme.warning,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'KYC: ${widget.user.kycStatus}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.user.kycStatus == 'VERIFIED'
                                  ? AdminTheme.success
                                  : AdminTheme.warning,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (widget.user.isBanned
                                        ? AdminTheme.error
                                        : AdminTheme.success)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.user.isBanned
                                  ? AdminTheme.error
                                  : AdminTheme.success,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.user.isBanned ? 'BANNED' : 'ACTIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.user.isBanned
                                  ? AdminTheme.error
                                  : AdminTheme.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            _buildSectionTitle('Wallet Details'),
            // Wallets Balance Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatBox(
                  currencyFormatter.format(widget.user.depositBalance),
                  'Deposit Wallet',
                  AdminTheme.primary,
                ),
                _buildStatBox(
                  currencyFormatter.format(widget.user.winningBalance),
                  'Winning Wallet',
                  AdminTheme.success,
                ),
                _buildStatBox(
                  currencyFormatter.format(widget.user.bonusBalance),
                  'Bonus Wallet',
                  AdminTheme.warning,
                ),
                _buildStatBox(
                  currencyFormatter.format(totalBalance),
                  'Total Value',
                  AdminTheme.textMain,
                ),
              ],
            ),

            _buildSectionTitle('Personal Details'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildFieldRow('First Name', widget.user.firstName ?? '-'),
                    _buildFieldRow('Last Name', widget.user.lastName ?? '-'),
                    _buildFieldRow('Email Address', widget.user.email ?? '-'),
                    _buildFieldRow(
                      'Referral Code',
                      widget.user.referralCode,
                      isCode: true,
                    ),
                    _buildFieldRow(
                      'Referred By Code',
                      widget.user.referredBy ?? '-',
                      isCode: true,
                    ),
                    _buildFieldRow(
                      'Device Specs',
                      widget.user.deviceDetails ?? 'Unknown Device',
                    ),
                  ],
                ),
              ),
            ),

            _buildSectionTitle('Bank Accounts for Withdrawal'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child:
                    widget.user.bankAccountNumber != null &&
                        widget.user.bankAccountNumber!.isNotEmpty
                    ? Column(
                        children: [
                          _buildFieldRow(
                            'Account Holder',
                            widget.user.bankAccountHolderName ?? '-',
                          ),
                          _buildFieldRow(
                            'Bank Name',
                            widget.user.bankName ?? '-',
                          ),
                          _buildFieldRow(
                            'Account Number',
                            widget.user.bankAccountNumber!,
                            isCode: true,
                          ),
                          _buildFieldRow(
                            'IFSC Code',
                            widget.user.bankIfscCode ?? '-',
                            isCode: true,
                          ),
                        ],
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: Text(
                            'No bank account details registered by this user.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AdminTheme.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
              ),
            ),

            _buildSectionTitle('Game Engagement Metrics'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildFieldRow(
                      'Math Quiz (Joins / Cleared)',
                      '${widget.user.joinedContestIds.length} / ${widget.user.completedContestIds.length}',
                    ),
                    _buildFieldRow(
                      'Word Search (Joins / Cleared)',
                      '${widget.user.joinedWordContestIds.length} / ${widget.user.completedWordContestIds.length}',
                    ),
                    _buildFieldRow(
                      'Slide Puzzle (Joins / Cleared)',
                      '${widget.user.joinedPuzzleContestIds.length} / ${widget.user.completedPuzzleContestIds.length}',
                    ),
                    _buildFieldRow(
                      'Fruit Slicing (Joins / Cleared)',
                      '${widget.user.joinedFruitContestIds.length} / ${widget.user.completedFruitContestIds.length}',
                    ),
                    _buildFieldRow(
                      'Go Arrows (Joins / Cleared)',
                      '${widget.user.joinedArrowContestIds.length} / ${widget.user.completedArrowContestIds.length}',
                    ),
                  ],
                ),
              ),
            ),

            _buildSectionTitle('Recent Wallet Transactions'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isLoadingTxs
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AdminTheme.primary,
                        ),
                      )
                    : _txError != null
                    ? Center(
                        child: Text(
                          'Error loading transactions: $_txError',
                          style: const TextStyle(
                            color: AdminTheme.error,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : _transactions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: Text(
                            'No transactions recorded for this user.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AdminTheme.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _transactions.length > 10
                            ? 10
                            : _transactions.length,
                        itemBuilder: (context, index) {
                          final tx =
                              _transactions[index] as Map<String, dynamic>;
                          final amount = (tx['amount'] ?? 0).toDouble();
                          final type = tx['type'] ?? '';
                          final status = tx['status'] ?? '';
                          final description = tx['description'] ?? '';
                          final createdAtStr = tx['created_at'] ?? '';
                          final dateStr = createdAtStr.isNotEmpty
                              ? DateFormat.yMMMd().add_jm().format(
                                  DateTime.parse(createdAtStr),
                                )
                              : '-';

                          Color typeColor = AdminTheme.warning;
                          String prefix = '';
                          if (type == 'DEPOSIT' ||
                              type == 'PRIZE_WIN' ||
                              type == 'REFERRAL_BONUS') {
                            typeColor = AdminTheme.success;
                            prefix = '+';
                          } else if (type == 'WITHDRAWAL' ||
                              type == 'ENTRY_FEE') {
                            typeColor = AdminTheme.error;
                            prefix = '-';
                          }

                          Color statusColor = AdminTheme.warning;
                          if (status == 'SUCCESS')
                            statusColor = AdminTheme.success;
                          if (status == 'FAILED')
                            statusColor = AdminTheme.error;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: typeColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              type,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: typeColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (description.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4.0,
                                          ),
                                          child: Text(
                                            description,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AdminTheme.textMain,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dateStr,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AdminTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$prefix${currencyFormatter.format(amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
