import 'package:flutter/material.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';
import 'package:de99_admin/features/users/bloc/users_cubit.dart';

class AdjustBalanceDialog extends StatefulWidget {
  final AdminUser user;
  final Function(String walletType, double amount) onConfirm;

  const AdjustBalanceDialog({
    super.key,
    required this.user,
    required this.onConfirm,
  });

  @override
  State<AdjustBalanceDialog> createState() => _AdjustBalanceDialogState();
}

class _AdjustBalanceDialogState extends State<AdjustBalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _walletType = 'deposit'; // Default selection

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Adjust Wallet Balance'),
          const SizedBox(height: 4),
          Text(
            '${widget.user.name ?? "Anonymous"} (${widget.user.phone})',
            style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wallet Type Selector
            DropdownButtonFormField<String>(
              value: _walletType,
              decoration: const InputDecoration(
                labelText: 'Select Wallet',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
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
            
            // Amount Input
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Adjustment Amount',
                hintText: 'e.g. 100 or -50',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter adjustment amount';
                }
                final numVal = double.tryParse(value);
                if (numVal == null || numVal == 0.0) {
                  return 'Please enter a valid non-zero number';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Use positive values to Credit (+) and negative values to Debit (-) balance.',
              style: TextStyle(fontSize: 11, color: AdminTheme.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final amount = double.parse(_amountController.text);
              widget.onConfirm(_walletType, amount);
              Navigator.pop(context);
            }
          },
          child: const Text('CONFIRM', style: TextStyle(color: AdminTheme.primary)),
        ),
      ],
    );
  }
}
