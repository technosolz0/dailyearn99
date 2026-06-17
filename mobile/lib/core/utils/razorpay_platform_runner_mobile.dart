import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayPlatformRunner {
  static Future<Map<String, dynamic>?> launchCheckout({
    required String keyId,
    required String orderId,
    required double amount,
    required String userPhone,
    required String userEmail,
  }) {
    final completer = Completer<Map<String, dynamic>?>();
    final razorpay = Razorpay();
    
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      if (!completer.isCompleted) {
        completer.complete({
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': response.orderId,
          'razorpay_signature': response.signature,
        });
      }
      razorpay.clear();
    });
    
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      if (!completer.isCompleted) {
        // Handle cancellation or failure
        if (response.code == Razorpay.PAYMENT_CANCELLED) {
          completer.complete(null); // User cancelled, return null gracefully
        } else {
          completer.completeError(response.message ?? 'Payment failed');
        }
      }
      razorpay.clear();
    });
    
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
      if (!completer.isCompleted) {
        completer.completeError('External wallet selection not supported: ${response.walletName}');
      }
      razorpay.clear();
    });
    
    final options = {
      'key': keyId,
      'amount': (amount * 100).toInt(), // Razorpay expects amount in paise
      'name': 'DailyEarn99',
      'description': 'Deposit via Razorpay',
      'order_id': orderId,
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'theme': {
        'color': '#0A2540'
      }
    };
    
    try {
      razorpay.open(options);
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError('Failed to open Razorpay: $e');
      }
      razorpay.clear();
    }
    
    return completer.future;
  }
}
