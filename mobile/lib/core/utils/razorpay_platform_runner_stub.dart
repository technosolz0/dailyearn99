class RazorpayPlatformRunner {
  static Future<Map<String, dynamic>?> launchCheckout({
    required String keyId,
    required String orderId,
    required double amount,
    required String userPhone,
    required String userEmail,
  }) {
    throw UnsupportedError('Razorpay is not supported on this platform');
  }
}
