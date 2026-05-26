import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }
    // Android emulator loops back to host via 10.0.2.2
    return Platform.isAndroid ? 'http://10.0.2.2:8000/api' : 'http://localhost:8000/api';
  }

  static String get wsUrl {
    if (kIsWeb) {
      return 'ws://localhost:8000/ws/leaderboard';
    }
    return Platform.isAndroid ? 'ws://10.0.2.2:8000/ws/leaderboard' : 'ws://localhost:8000/ws/leaderboard';
  }

  // Endpoints
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String me = '/auth/me';
  
  static const String contests = '/contests';
  static const String joinContest = '/contests/join';
  static const String submitScore = '/contests/submit-score';
  static String leaderboard(int contestId) => '/contests/$contestId/leaderboard';
  
  static const String deposit = '/wallet/deposit';
  static const String withdraw = '/wallet/withdraw';
  static const String transactions = '/wallet/transactions';
  static const String saveBankDetails = '/wallet/bank-details';
  
  static const String referralDetails = '/referral/details';
  static const String registerFcmToken = '/auth/fcm-token';
}
