import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';
import 'package:de99_admin/features/users/bloc/users_cubit.dart';
import 'package:de99_admin/features/users/views/user_details_view.dart';
import 'package:de99_admin/features/users/widgets/adjust_balance_dialog.dart';

class UsersView extends StatefulWidget {
  const UsersView({super.key});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load users on tab view initialization
    context.read<UsersCubit>().fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    context.read<UsersCubit>().searchUsers(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _showAdjustBalanceDialog(BuildContext context, AdminUser user) {
    showDialog(
      context: context,
      builder: (diagContext) => AdjustBalanceDialog(
        user: user,
        onConfirm: (walletType, amount) {
          context.read<UsersCubit>().adjustBalance(user.id, walletType, amount);
        },
      ),
    );
  }

  void _confirmDeleteUser(BuildContext context, AdminUser user) {
    showDialog(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Confirm Account Deletion'),
        content: Text(
          'Are you sure you want to permanently delete user ${user.name ?? "Anonymous"} (${user.phone})? '
          'This will wipe all transactions, scores, and metadata. This action is IRREVERSIBLE.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(diagContext),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(diagContext);
              context.read<UsersCubit>().deleteUser(user.id);
            },
            child: const Text('DELETE PERMANENTLY', style: TextStyle(color: AdminTheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Column(
      children: [
        // Search Bar Row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Users',
              hintText: 'Enter name, phone number, or code...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Users ListView Builder
        Expanded(
          child: BlocBuilder<UsersCubit, UsersState>(
            builder: (context, state) {
              if (state is UsersLoading) {
                return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
              } else if (state is UsersError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 50, color: AdminTheme.error),
                        const SizedBox(height: 12),
                        Text(state.message, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => context.read<UsersCubit>().fetchUsers(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (state is UsersLoaded) {
                final users = state.filteredUsers;

                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching users found.',
                      style: TextStyle(color: AdminTheme.textMuted),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final u = users[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u.name ?? 'Anonymous User',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AdminTheme.textMain,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Phone: ${u.phone}',
                                        style: const TextStyle(fontSize: 13, color: AdminTheme.textMuted),
                                      ),
                                      Text(
                                        'Code: ${u.referralCode}',
                                        style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                ),
                                // Badges for KYC and Ban Status
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (u.kycStatus == 'VERIFIED' ? AdminTheme.success : AdminTheme.warning).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        u.kycStatus,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: u.kycStatus == 'VERIFIED' ? AdminTheme.success : AdminTheme.warning,
                                        ),
                                      ),
                                    ),
                                    if (u.isBanned) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AdminTheme.error.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'BANNED',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AdminTheme.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const Divider(color: AdminTheme.borderColor, height: 24),
                            // Balances
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Deposit', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                    Text(currencyFormatter.format(u.depositBalance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.primary)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Winnings', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                    Text(currencyFormatter.format(u.winningBalance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.success)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Bonus', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                    Text(currencyFormatter.format(u.bonusBalance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.warning)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Quick Action Buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UserDetailsView(user: u),
                                      ),
                                    );
                                  },
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.visibility_outlined, size: 16),
                                      SizedBox(width: 4),
                                      Text('Details', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    foregroundColor: AdminTheme.primary,
                                  ),
                                  onPressed: () => _showAdjustBalanceDialog(context, u),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined, size: 16),
                                      SizedBox(width: 4),
                                      Text('Adjust Bal', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    foregroundColor: u.isBanned ? AdminTheme.success : AdminTheme.warning,
                                  ),
                                  onPressed: () {
                                    context.read<UsersCubit>().toggleBan(u.id, !u.isBanned);
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(u.isBanned ? Icons.check_circle_outline : Icons.block_flipped, size: 16),
                                      const SizedBox(width: 4),
                                      Text(u.isBanned ? 'Unban' : 'Ban', style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (u.isBanned)
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      foregroundColor: AdminTheme.error,
                                    ),
                                    onPressed: () => _confirmDeleteUser(context, u),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.delete_outline, size: 16),
                                        SizedBox(width: 4),
                                        Text('Delete', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}
