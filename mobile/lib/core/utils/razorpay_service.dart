import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/core/utils/razorpay_platform_runner.dart';
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
    _createOrderAndLaunch();
  }

  Future<void> _createOrderAndLaunch() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingOrder = true;
          _errorMessage = null;
          _isProcessingPayment = false;
        });
      }

      // 1. Request encrypted Razorpay order configuration from backend
      final response = await _apiClient.post(
        '/wallet/razorpay/create-order',
        data: {'amount': widget.amount},
      );

      final String encryptedData = response.data['encrypted_data'] as String;
      final String ivB64 = response.data['iv'] as String;

      // 2. Decrypt response payload using AES-CBC-PKCS7
      final keyStr = "dailyearn99_super_secret_signing";
      final key = encrypt.Key.fromUtf8(keyStr);
      final iv = encrypt.IV.fromBase64(ivB64);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      
      final decrypted = encrypter.decrypt(
        encrypt.Encrypted.fromBase64(encryptedData),
        iv: iv,
      );
      
      final decryptedJson = json.decode(decrypted) as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _orderId = decryptedJson['order_id'] as String;
          _keyId = decryptedJson['key_id'] as String;
          _userPhone = decryptedJson['user_phone'] as String;
          _userEmail = decryptedJson['user_email'] as String;
          _isLoadingOrder = false;
          _isProcessingPayment = true;
          _paymentStepMessage = 'Launching payment portal...';
        });
      }

      // 3. Initiate platform-specific Razorpay Checkout SDK/JS iframe
      final result = await RazorpayPlatformRunner.launchCheckout(
        keyId: _keyId!,
        orderId: _orderId!,
        amount: widget.amount,
        userPhone: _userPhone!,
        userEmail: _userEmail!,
      );

      if (result == null) {
        // User closed/cancelled the transaction
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // 4. Submit captured signature back to server for verification
      if (mounted) {
        setState(() {
          _paymentStepMessage = 'Verifying payment signature securely...';
        });
      }

      await _apiClient.post(
        '/wallet/razorpay/verify-payment',
        data: {
          'razorpay_order_id': result['razorpay_order_id'],
          'razorpay_payment_id': result['razorpay_payment_id'],
          'razorpay_signature': result['razorpay_signature'],
          'amount': widget.amount,
        },
      );

      if (!mounted) return;
      setState(() {
        _paymentStepMessage = 'Deposit processed successfully!';
        _isPaymentSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      // Close the bottom sheet and refresh the wallet
      Navigator.pop(context);

      context.read<AppBloc>().add(LoadProfileEvent());
      context.read<AppBloc>().add(FetchTransactionsEvent());

      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoadingOrder = false;
          _isProcessingPayment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F121F), // Premium dark theme matching Dailyearn99
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
                            'DailyEarn99 Secure Deposit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_orderId != null)
                            Text(
                              'Order: ${_orderId!.substring(0, _orderId!.length > 18 ? 18 : _orderId!.length)}...',
                              style: TextStyle(
                                color: Colors.white.withAlpha(128),
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
                      color: Colors.white.withAlpha(20),
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
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppTheme.accentCyan),
                    SizedBox(height: 16),
                    Text(
                      'Securing payment tunnel...',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              )
            else if (_errorMessage != null)
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
                    const Text(
                      'Payment Channel Failed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.borderCol),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('CANCEL'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _createOrderAndLaunch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentCyan,
                              foregroundColor: const Color(0xFF0F121F),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('RETRY'),
                          ),
                        ),
                      ],
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
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Do not press back or close this sheet.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            
            // Security Footer
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: AppTheme.accentEmerald.withAlpha(150),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Secured by Razorpay. PCI-DSS Compliant.',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.accentEmerald.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
