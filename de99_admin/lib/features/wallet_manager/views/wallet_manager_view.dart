import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';

class WalletUserBrief {
  final int id;
  final String phone;
  final String name;
  final double depositBalance;
  final double winningBalance;
  final double bonusBalance;

  WalletUserBrief({
    required this.id,
    required this.phone,
    required this.name,
    required this.depositBalance,
    required this.winningBalance,
    required this.bonusBalance,
  });

  factory WalletUserBrief.fromJson(Map<String, dynamic> json) {
    return WalletUserBrief(
      id: json['id'] ?? 0,
      phone: json['phone'] ?? '',
      name: json['name'] ?? 'Anonymous User',
      depositBalance: (json['deposit_balance'] ?? 0).toDouble(),
      winningBalance: (json['winning_balance'] ?? 0).toDouble(),
      bonusBalance: (json['bonus_balance'] ?? 0).toDouble(),
    );
  }
}

class WalletManagerView extends StatefulWidget {
  const WalletManagerView({super.key});

  @override
  State<WalletManagerView> createState() => _WalletManagerViewState();
}

class _WalletManagerViewState extends State<WalletManagerView> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  List<WalletUserBrief> _users = [];
  WalletUserBrief? _selectedUser;
  
  String _walletType = 'deposit'; // 'deposit', 'winning', 'bonus'
  final _amountController = TextEditingController();
  final _searchController = TextEditingController();
  List<WalletUserBrief> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _apiClient.dio.get('/admin/users');
      final users = (res.data as List).map((x) => WalletUserBrief.fromJson(x)).toList();

      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.response?.data['detail'] ?? e.message ?? 'Failed to load user accounts';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((u) {
          final q = query.toLowerCase();
          return u.phone.contains(q) || u.name.toLowerCase().contains(q) || u.id.toString() == q;
        }).toList();
      }
    });
  }

  Future<void> _adjustBalance() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user account first.'), backgroundColor: AdminTheme.error),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid non-zero adjustment amount.'), backgroundColor: AdminTheme.error),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await _apiClient.dio.post(
        '/admin/users/${_selectedUser!.id}/adjust-balance',
        data: {
          'amount': amount,
          'wallet_type': _walletType,
        },
      );

      final updatedUser = WalletUserBrief.fromJson(response.data);
      
      // Update in local lists
      setState(() {
        _users = _users.map((u) => u.id == updatedUser.id ? updatedUser : u).toList();
        _selectedUser = updatedUser;
        _filterUsers(_searchController.text);
        _amountController.clear();
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully adjusted ${_walletType.toUpperCase()} balance by ₹${amount.toStringAsFixed(2)}'),
          backgroundColor: AdminTheme.success,
        ),
      );
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to adjust balance'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    if (_isLoading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: AdminTheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Wallet balance adjuster',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.primary),
              ),
              const SizedBox(height: 16),

              // Search Bar
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search user by phone or name...',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                    ),
                    onChanged: _filterUsers,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // User dropdown
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<WalletUserBrief>(
                    value: _selectedUser,
                    decoration: const InputDecoration(
                      labelText: 'Select User Account',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: _filteredUsers.map((u) {
                      return DropdownMenuItem<WalletUserBrief>(
                        value: u,
                        child: Text('${u.name} (${u.phone}) - ID: ${u.id}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedUser = val;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Current Balance read-outs
              if (_selectedUser != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Wallet Balances',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildBalanceCol('Deposit Wallet', currencyFormatter.format(_selectedUser!.depositBalance), AdminTheme.primary),
                            _buildBalanceCol('Winning Wallet', currencyFormatter.format(_selectedUser!.winningBalance), AdminTheme.success),
                            _buildBalanceCol('Bonus Wallet', currencyFormatter.format(_selectedUser!.bonusBalance), AdminTheme.warning),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Adjuster Form
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Adjust Wallet Balance',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.textMain),
                        ),
                        const SizedBox(height: 16),

                        // Dropdown for target wallet
                        DropdownButtonFormField<String>(
                          value: _walletType,
                          decoration: const InputDecoration(
                            labelText: 'Select Target Wallet',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'deposit', child: Text('Deposit Wallet')),
                            DropdownMenuItem(value: 'winning', child: Text('Winning Wallet')),
                            DropdownMenuItem(value: 'bonus', child: Text('Bonus Wallet')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _walletType = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Amount input
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Adjustment Amount (INR)',
                            prefixIcon: Icon(Icons.currency_rupee),
                            hintText: 'e.g. 500 (or -500 to subtract)',
                            helperText: 'Enter positive value to add, or negative value to subtract funds.',
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_isSubmitting)
                          const Center(child: CircularProgressIndicator(color: AdminTheme.primary))
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.primary,
                              foregroundColor: AdminTheme.background,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _adjustBalance,
                            child: const Text('SUBMIT ADJUSTMENT', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('Select a user account above to adjust wallet balances.', style: TextStyle(color: AdminTheme.textMuted)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCol(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
