import 'dart:async';
import 'package:dailyearn99/core/utils/js_stub.dart'
    if (dart.library.html) 'dart:js';


class RazorpayPlatformRunner {
  static Future<Map<String, dynamic>?> launchCheckout({
    required String keyId,
    required String orderId,
    required double amount,
    required String userPhone,
    required String userEmail,
  }) {
    final completer = Completer<Map<String, dynamic>?>();
    
    try {
      if (context['Razorpay'] == null) {
        completer.completeError('Razorpay library is not loaded on this web page. Please check connection.');
        return completer.future;
      }

      final options = JsObject.jsify({
        'key': keyId,
        'amount': (amount * 100).toInt(),
        'currency': 'INR',
        'name': 'DailyEarn99',
        'description': 'Deposit via Razorpay',
        'order_id': orderId,
        'handler': allowInterop((response) {
          if (!completer.isCompleted) {
            completer.complete({
              'razorpay_payment_id': response['razorpay_payment_id'],
              'razorpay_order_id': response['razorpay_order_id'],
              'razorpay_signature': response['razorpay_signature'],
            });
          }
        }),
        'prefill': {
          'contact': userPhone,
          'email': userEmail,
        },
        'theme': {
          'color': '#0A2540'
        },
        'modal': {
          'ondismiss': allowInterop(() {
            if (!completer.isCompleted) {
              completer.complete(null); // User dismissed/cancelled the checkout
            }
          })
        }
      });
      
      final rzp = JsObject(context['Razorpay'], [options]);
      rzp.callMethod('open');
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError('Failed to initialize Razorpay: $e');
      }
    }
    
    return completer.future;
  }
}

