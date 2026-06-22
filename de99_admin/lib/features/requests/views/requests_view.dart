import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';
import 'package:de99_admin/features/requests/bloc/requests_cubit.dart';

class RequestsView extends StatefulWidget {
  const RequestsView({super.key});

  @override
  State<RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends State<RequestsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _filterType = '';
  String _filterStatus = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<RequestsCubit>().fetchRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildDepositsList(List<PendingRequest> deposits, NumberFormat currencyFormatter) {
    if (deposits.isEmpty) {
      return const Center(
        child: Text('No pending manual deposits.', style: TextStyle(color: AdminTheme.textMuted)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deposits.length,
      itemBuilder: (context, index) {
        final req = deposits[index];
        final timeStr = DateFormat.yMMMd().add_jm().format(req.createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.userName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textMain),
                          ),
                          const SizedBox(height: 2),
                          Text(req.userPhone, style: const TextStyle(fontSize: 13, color: AdminTheme.textMuted)),
                        ],
                      ),
                    ),
                    Text(
                      currencyFormatter.format(req.amount),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.success),
                    ),
                  ],
                ),
                const Divider(color: AdminTheme.borderColor, height: 24),
                _buildDetailsRow('UTR / Ref ID', req.utr ?? 'N/A', isMonospace: true, isHighlight: true),
                _buildDetailsRow('Submitted On', timeStr),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _confirmAction(context, req, false, true),
                      style: TextButton.styleFrom(foregroundColor: AdminTheme.error),
                      child: const Text('REJECT'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _confirmAction(context, req, true, true),
                      style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.success, foregroundColor: Colors.white),
                      child: const Text('APPROVE'),
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

  Widget _buildWithdrawalsList(List<PendingRequest> withdrawals, NumberFormat currencyFormatter) {
    if (withdrawals.isEmpty) {
      return const Center(
        child: Text('No pending withdrawals.', style: TextStyle(color: AdminTheme.textMuted)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: withdrawals.length,
      itemBuilder: (context, index) {
        final req = withdrawals[index];
        final timeStr = DateFormat.yMMMd().add_jm().format(req.createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.userName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textMain),
                          ),
                          const SizedBox(height: 2),
                          Text(req.userPhone, style: const TextStyle(fontSize: 13, color: AdminTheme.textMuted)),
                        ],
                      ),
                    ),
                    Text(
                      currencyFormatter.format(req.amount),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.error),
                    ),
                  ],
                ),
                const Divider(color: AdminTheme.borderColor, height: 24),
                _buildDetailsRow('Holder Name', req.bankHolder ?? 'N/A'),
                _buildDetailsRow('Bank Name', req.bankName ?? 'N/A'),
                _buildDetailsRow('Account No', req.bankAccount ?? 'N/A', isMonospace: true),
                _buildDetailsRow('IFSC Code', req.bankIfsc ?? 'N/A', isMonospace: true),
                _buildDetailsRow('Requested On', timeStr),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _confirmAction(context, req, false, false),
                      style: TextButton.styleFrom(foregroundColor: AdminTheme.error),
                      child: const Text('REJECT'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _confirmAction(context, req, true, false),
                      style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primary, foregroundColor: AdminTheme.background),
                      child: const Text('APPROVE & PAY'),
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

  Widget _buildDetailsRow(String label, String value, {bool isMonospace = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isHighlight ? AdminTheme.primary : AdminTheme.textMain,
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAction(BuildContext context, PendingRequest req, bool approve, bool isDeposit) {
    final actionText = approve ? 'APPROVE' : 'REJECT';
    final requestType = isDeposit ? 'deposit' : 'withdrawal';

    showDialog(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: Text('Confirm $actionText'),
        content: Text('Are you sure you want to $actionText this $requestType of ₹${req.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(diagContext),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(diagContext);
              if (isDeposit) {
                context.read<RequestsCubit>().approveDeposit(req.id, approve);
              } else {
                context.read<RequestsCubit>().approveWithdrawal(req.id, approve);
              }
            },
            child: Text('CONFIRM', style: TextStyle(color: approve ? AdminTheme.primary : AdminTheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: AdminTheme.surfaceDark,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AdminTheme.primary,
            labelColor: AdminTheme.primary,
            unselectedLabelColor: AdminTheme.textMuted,
            tabs: const [
              Tab(icon: Icon(Icons.download), text: 'Pending Deposits'),
              Tab(icon: Icon(Icons.upload), text: 'Pending Withdrawals'),
              Tab(icon: Icon(Icons.history), text: 'Transactions History'),
            ],
          ),
        ),
      ),
      body: BlocBuilder<RequestsCubit, RequestsState>(
        builder: (context, state) {
          if (state is RequestsLoading) {
            return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
          } else if (state is RequestsError) {
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
                      onPressed: () => context.read<RequestsCubit>().fetchRequests(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          } else if (state is RequestsLoaded) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildDepositsList(state.pendingDeposits, currencyFormatter),
                _buildWithdrawalsList(state.pendingWithdrawals, currencyFormatter),
                _buildTransactionsHistoryList(state.allTransactions, currencyFormatter),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTransactionsHistoryList(List<PendingRequest> txs, NumberFormat currencyFormatter) {
    final filtered = txs.where((t) {
      final matchesSearch = t.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.userPhone.contains(_searchQuery) ||
          t.id.toString() == _searchQuery ||
          t.userId.toString() == _searchQuery ||
          (t.utr ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesType = _filterType.isEmpty || _filterType == 'ALL' || t.type == _filterType;
      final matchesStatus = _filterStatus.isEmpty || _filterStatus == 'ALL' || t.status == _filterStatus;

      return matchesSearch && matchesType && matchesStatus;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: AdminTheme.textMain, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search phone/name/ID/UTR...',
                    hintStyle: TextStyle(color: AdminTheme.textMuted, fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 18, color: AdminTheme.textMuted),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filterType.isEmpty ? 'ALL' : _filterType,
                dropdownColor: AdminTheme.surfaceDark,
                style: const TextStyle(color: AdminTheme.textMain, fontSize: 12),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Types')),
                  DropdownMenuItem(value: 'DEPOSIT', child: Text('Deposits')),
                  DropdownMenuItem(value: 'WITHDRAWAL', child: Text('Withdrawals')),
                  DropdownMenuItem(value: 'PRIZE_WIN', child: Text('Prizes')),
                  DropdownMenuItem(value: 'ENTRY_FEE', child: Text('Entry Fees')),
                  DropdownMenuItem(value: 'REFERRAL_BONUS', child: Text('Referrals')),
                ],
                onChanged: (val) {
                  setState(() {
                    _filterType = val == 'ALL' ? '' : val!;
                  });
                },
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filterStatus.isEmpty ? 'ALL' : _filterStatus,
                dropdownColor: AdminTheme.surfaceDark,
                style: const TextStyle(color: AdminTheme.textMain, fontSize: 12),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'SUCCESS', child: Text('Success')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                  DropdownMenuItem(value: 'FAILED', child: Text('Failed')),
                ],
                onChanged: (val) {
                  setState(() {
                    _filterStatus = val == 'ALL' ? '' : val!;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No transactions match the criteria.', style: TextStyle(color: AdminTheme.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    final timeStr = DateFormat.yMMMd().add_jm().format(tx.createdAt);
                    
                    Color typeColor = AdminTheme.warning;
                    IconData typeIcon = Icons.swap_horiz;
                    String prefix = '';
                    
                    if (tx.type == 'DEPOSIT' || tx.type == 'PRIZE_WIN' || tx.type == 'REFERRAL_BONUS') {
                      typeColor = AdminTheme.success;
                      typeIcon = Icons.arrow_downward;
                      prefix = '+';
                    } else if (tx.type == 'WITHDRAWAL') {
                      typeColor = AdminTheme.error;
                      typeIcon = Icons.arrow_upward;
                      prefix = '-';
                    } else if (tx.type == 'ENTRY_FEE') {
                      typeColor = AdminTheme.warning;
                      typeIcon = Icons.arrow_upward;
                      prefix = '-';
                    }

                    Color statusColor = AdminTheme.warning;
                    if (tx.status == 'SUCCESS') statusColor = AdminTheme.success;
                    if (tx.status == 'FAILED') statusColor = AdminTheme.error;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: typeColor.withOpacity(0.1),
                          child: Icon(typeIcon, color: typeColor, size: 20),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(tx.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.textMain)),
                            Text(
                              '$prefix${currencyFormatter.format(tx.amount)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: typeColor, fontSize: 14),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${tx.userPhone} • ID: ${tx.userId} • Tx: #${tx.id}', style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                              if (tx.description != null && tx.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(tx.description!, style: const TextStyle(fontSize: 12, color: AdminTheme.textMain)),
                                ),
                              if (tx.utr != null && tx.utr!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text('UTR: ${tx.utr}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AdminTheme.primary)),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(timeStr, style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: statusColor, width: 0.5),
                                    ),
                                    child: Text(
                                      tx.status,
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
