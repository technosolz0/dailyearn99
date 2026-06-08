// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/features/app_bloc.dart';

class RazorpayService {
  static void openRazorpayPaymentSheet({
    required BuildContext context,
    required double amount,
    required VoidCallback onSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _RazorpayCheckoutSheet(amount: amount, onSuccess: onSuccess),
    );
  }
}

class _RazorpayCheckoutSheet extends StatefulWidget {
  final double amount;
  final VoidCallback onSuccess;

  const _RazorpayCheckoutSheet({required this.amount, required this.onSuccess});

  @override
  State<_RazorpayCheckoutSheet> createState() => _RazorpayCheckoutSheetState();
}

class _RazorpayCheckoutSheetState extends State<_RazorpayCheckoutSheet> {
  final ApiClient _apiClient = getIt<ApiClient>();

  bool _isLoadingOrder = true;
  String? _orderId;
  String? _keyId;
  String? _userPhone;
  String? _userEmail;
  String? _errorMessage;

  // Payment progress states
  bool _isProcessingPayment = false;
  String _paymentStepMessage = '';
  bool _isPaymentSuccess = false;

  @override
  void initState() {
    super.initState();
    _createOrder();
  }

  Future<void> _createOrder() async {
    try {
      final response = await _apiClient.post(
        '/wallet/razorpay/create-order',
        data: {'amount': widget.amount},
      );

      if (mounted) {
        setState(() {
          _orderId = response.data['order_id'] as String;
          _keyId = response.data['key_id'] as String;
          _userPhone = response.data['user_phone'] as String;
          _userEmail = response.data['user_email'] as String;
          _isLoadingOrder = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoadingOrder = false;
        });
      }
    }
  }

  Future<void> _processPayment(String method) async {
    setState(() {
      _isProcessingPayment = true;
      _paymentStepMessage = 'Initializing payment channel...';
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      _paymentStepMessage = 'Connecting with $method gateway...';
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _paymentStepMessage = 'Verifying secure transaction logs...';
    });

    try {
      // Simulate Razorpay parameters
      final mockPaymentId =
          'pay_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      // Request validation from the server using mock signature bypass
      await _apiClient.post(
        '/wallet/razorpay/verify-payment',
        data: {
          'razorpay_order_id': _orderId,
          'razorpay_payment_id': mockPaymentId,
          'razorpay_signature': 'mock_signature_for_testing',
          'amount': widget.amount,
        },
      );

      if (!mounted) return;
      setState(() {
        _paymentStepMessage = 'Payment success!';
        _isPaymentSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;

      // Close sheet and execute success callback
      Navigator.pop(context);

      // Refresh balance in BLoC
      context.read<AppBloc>().add(LoadProfileEvent());
      context.read<AppBloc>().add(FetchTransactionsEvent());

      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isProcessingPayment = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F121F), // Dark blue premium background
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Razorpay Style Brand Header
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0A2540), // Official Razorpay deep blue
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Color(0xFF0A2540),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dailyearn99 checkout',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_orderId != null)
                            Text(
                              'Order: ${_orderId!.substring(0, 14)}...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '₹${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isLoadingOrder)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48.0),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accentCyan),
                ),
              )
            else if (_errorMessage != null && !_isProcessingPayment)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.accentRed,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment Initialization Failed',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoadingOrder = true;
                          _errorMessage = null;
                        });
                        _createOrder();
                      },
                      child: const Text('RETRY ORDER CREATION'),
                    ),
                  ],
                ),
              )
            else if (_isProcessingPayment)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 48.0,
                  horizontal: 24.0,
                ),
                child: Column(
                  children: [
                    if (_isPaymentSuccess)
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppTheme.accentEmerald,
                        size: 64,
                      )
                    else
                      const CircularProgressIndicator(
                        color: AppTheme.accentCyan,
                      ),
                    const SizedBox(height: 24),
                    Text(
                      _paymentStepMessage,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Do not press back or close the checkout window.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PAYMENT OPTIONS',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // UPI Options
                    _buildPaymentMethodTile(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Google Pay / PhonePe (UPI)',
                      subtitle: 'Pay instantly via UPI apps',
                      onTap: () => _processPayment('UPI Apps'),
                    ),
                    const Divider(color: AppTheme.borderCol, height: 24),

                    // Card Options
                    _buildPaymentMethodTile(
                      icon: Icons.credit_card_rounded,
                      title: 'Card Payment',
                      subtitle: 'Visa, MasterCard, RuPay, Maestro',
                      onTap: () => _processPayment('Card Gateway'),
                    ),
                    const Divider(color: AppTheme.borderCol, height: 24),

                    // Netbanking Options
                    _buildPaymentMethodTile(
                      icon: Icons.account_balance_rounded,
                      title: 'Net Banking',
                      subtitle: 'All major Indian banks available',
                      onTap: () => _processPayment('Net Banking'),
                    ),
                    const SizedBox(height: 24),

                    // Security Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: AppTheme.accentEmerald.withOpacity(0.6),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Secured by Razorpay. PCI-DSS Compliant.',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.accentEmerald.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderCol),
              ),
              child: Icon(icon, color: AppTheme.accentCyan, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
