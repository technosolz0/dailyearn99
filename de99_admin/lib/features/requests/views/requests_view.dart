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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
