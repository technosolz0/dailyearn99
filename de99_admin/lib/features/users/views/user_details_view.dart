import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';
import 'package:de99_admin/features/users/bloc/users_cubit.dart';

class UserDetailsView extends StatelessWidget {
  final AdminUser user;

  const UserDetailsView({super.key, required this.user});

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
          Text(label, style: const TextStyle(color: AdminTheme.textMuted, fontSize: 14)),
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
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
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final totalBalance = user.depositBalance + user.winningBalance + user.bonusBalance;

    return Scaffold(
      appBar: AppBar(
        title: Text(user.name ?? 'User Profile'),
      ),
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
                        (user.name?.isNotEmpty ?? false) ? user.name![0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AdminTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.name ?? 'Anonymous User',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.textMain),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.phone}  •  ID: ${user.id}',
                      style: const TextStyle(fontSize: 13, color: AdminTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // KYC Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (user.kycStatus == 'VERIFIED' ? AdminTheme.success : AdminTheme.warning).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: user.kycStatus == 'VERIFIED' ? AdminTheme.success : AdminTheme.warning,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'KYC: ${user.kycStatus}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: user.kycStatus == 'VERIFIED' ? AdminTheme.success : AdminTheme.warning,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (user.isBanned ? AdminTheme.error : AdminTheme.success).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: user.isBanned ? AdminTheme.error : AdminTheme.success,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            user.isBanned ? 'BANNED' : 'ACTIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: user.isBanned ? AdminTheme.error : AdminTheme.success,
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
                _buildStatBox(currencyFormatter.format(user.depositBalance), 'Deposit Wallet', AdminTheme.primary),
                _buildStatBox(currencyFormatter.format(user.winningBalance), 'Winning Wallet', AdminTheme.success),
                _buildStatBox(currencyFormatter.format(user.bonusBalance), 'Bonus Wallet', AdminTheme.warning),
                _buildStatBox(currencyFormatter.format(totalBalance), 'Total Value', AdminTheme.textMain),
              ],
            ),

            _buildSectionTitle('Personal Details'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildFieldRow('First Name', user.firstName ?? '-'),
                    _buildFieldRow('Last Name', user.lastName ?? '-'),
                    _buildFieldRow('Email Address', user.email ?? '-'),
                    _buildFieldRow('Referral Code', user.referralCode, isCode: true),
                    _buildFieldRow('Referred By Code', user.referredBy ?? '-', isCode: true),
                    _buildFieldRow('Device Specs', user.deviceDetails ?? 'Unknown Device'),
                  ],
                ),
              ),
            ),

            _buildSectionTitle('Bank Accounts for Withdrawal'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: user.bankAccountNumber != null && user.bankAccountNumber!.isNotEmpty
                    ? Column(
                        children: [
                          _buildFieldRow('Account Holder', user.bankAccountHolderName ?? '-'),
                          _buildFieldRow('Bank Name', user.bankName ?? '-'),
                          _buildFieldRow('Account Number', user.bankAccountNumber!, isCode: true),
                          _buildFieldRow('IFSC Code', user.bankIfscCode ?? '-', isCode: true),
                        ],
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: Text(
                            'No bank account details registered by this user.',
                            style: TextStyle(fontSize: 13, color: AdminTheme.textMuted, fontStyle: FontStyle.italic),
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
                    _buildFieldRow('Math Quiz (Joins / Cleared)', '${user.joinedContestIds.length} / ${user.completedContestIds.length}'),
                    _buildFieldRow('Word Search (Joins / Cleared)', '${user.joinedWordContestIds.length} / ${user.completedWordContestIds.length}'),
                    _buildFieldRow('Slide Puzzle (Joins / Cleared)', '${user.joinedPuzzleContestIds.length} / ${user.completedPuzzleContestIds.length}'),
                    _buildFieldRow('Fruit Slicing (Joins / Cleared)', '${user.joinedFruitContestIds.length} / ${user.completedFruitContestIds.length}'),
                    _buildFieldRow('Go Arrows (Joins / Cleared)', '${user.joinedArrowContestIds.length} / ${user.completedArrowContestIds.length}'),
                  ],
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
