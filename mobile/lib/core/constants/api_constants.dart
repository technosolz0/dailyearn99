import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  static const bool useLocalBackend = true;

  static String get baseUrl {
    if (useLocalBackend) {
      if (kIsWeb) return 'http://127.0.0.1:8000/api';
      return Platform.isAndroid ? 'http://10.0.2.2:8000/api' : 'http://127.0.0.1:8000/api';
    }
    if (kIsWeb) {
      return 'http://target99api.serwex.in/api';
    }
    // Android emulator loops back to host via 10.0.2.2
    return Platform.isAndroid
        ? 'http://target99api.serwex.in/api'
        : 'http://target99api.serwex.in/api';
  }

  static String get wsUrl {
    if (useLocalBackend) {
      if (kIsWeb) return 'ws://127.0.0.1:8000/ws/leaderboard';
      return Platform.isAndroid ? 'ws://10.0.2.2:8000/ws/leaderboard' : 'ws://127.0.0.1:8000/ws/leaderboard';
    }
    if (kIsWeb) {
      return 'ws://target99api.serwex.in/ws/leaderboard';
    }
    return Platform.isAndroid
        ? 'ws://target99api.serwex.in/ws/leaderboard'
        : 'ws://target99api.serwex.in/ws/leaderboard';
  }

  // Endpoints
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String me = '/auth/me';

  static const String contests = '/contests';
  static const String joinContest = '/contests/join';
  static const String submitScore = '/contests/submit-score';
  static String leaderboard(int contestId) =>
      '/contests/$contestId/leaderboard';

  static const String deposit = '/wallet/deposit';
  static const String withdraw = '/wallet/withdraw';
  static const String transactions = '/wallet/transactions';
  static const String saveBankDetails = '/wallet/bank-details';

  static const String spinCreate = '/spin/create';
  static const String spinHistory = '/spin/history';

  static const String referralDetails = '/referral/details';
  static const String registerFcmToken = '/auth/fcm-token';

  // Puzzle APIs
  static const String puzzleContests = '/puzzle/contests';
  static String puzzleStart(int contestId) => '/puzzle/start/$contestId';
  static const String puzzleSubmit = '/puzzle/submit-score';
  static String puzzleLeaderboard(int contestId) => '/puzzle/leaderboard/$contestId';
  static String puzzleWs(int contestId) {
    if (useLocalBackend) {
      if (kIsWeb) return 'ws://127.0.0.1:8000/ws/puzzle/leaderboard/$contestId';
      return Platform.isAndroid
          ? 'ws://10.0.2.2:8000/ws/puzzle/leaderboard/$contestId'
          : 'ws://127.0.0.1:8000/ws/puzzle/leaderboard/$contestId';
    }
    if (kIsWeb) {
      return 'ws://target99api.serwex.in/ws/puzzle/leaderboard/$contestId';
    }
    return Platform.isAndroid
        ? 'ws://target99api.serwex.in/ws/puzzle/leaderboard/$contestId'
        : 'ws://target99api.serwex.in/ws/puzzle/leaderboard/$contestId';
  }

  // Word Game APIs
  static const String wordContests = '/word-game/contests';
  static const String wordJoin = '/word-game/join';
  static String wordStart(int contestId) => '/word-game/start/$contestId';
  static const String wordSubmit = '/word-game/submit';
  static String wordLeaderboard(int contestId) => '/word-game/leaderboard/$contestId';
  static String wordWs(int contestId) {
    if (useLocalBackend) {
      if (kIsWeb) return 'ws://127.0.0.1:8000/ws/word/leaderboard/$contestId';
      return Platform.isAndroid
          ? 'ws://10.0.2.2:8000/ws/word/leaderboard/$contestId'
          : 'ws://127.0.0.1:8000/ws/word/leaderboard/$contestId';
    }
    if (kIsWeb) {
      return 'ws://target99api.serwex.in/ws/word/leaderboard/$contestId';
    }
    return Platform.isAndroid
        ? 'ws://target99api.serwex.in/ws/word/leaderboard/$contestId'
        : 'ws://target99api.serwex.in/ws/word/leaderboard/$contestId';
  }

  // Fruit Slicing APIs
  static const String fruitContests = '/fruit-game/contests';
  static const String fruitJoin = '/fruit-game/join';
  static String fruitStart(int contestId) => '/fruit-game/start/$contestId';
  static const String fruitSubmit = '/fruit-game/submit';
  static String fruitLeaderboard(int contestId) => '/fruit-game/leaderboard/$contestId';
  static String fruitWs(int contestId) {
    if (useLocalBackend) {
      if (kIsWeb) return 'ws://127.0.0.1:8000/ws/fruit/leaderboard/$contestId';
      return Platform.isAndroid
          ? 'ws://10.0.2.2:8000/ws/fruit/leaderboard/$contestId'
          : 'ws://127.0.0.1:8000/ws/fruit/leaderboard/$contestId';
    }
    if (kIsWeb) {
      return 'ws://target99api.serwex.in/ws/fruit/leaderboard/$contestId';
    }
    return Platform.isAndroid
        ? 'ws://target99api.serwex.in/ws/fruit/leaderboard/$contestId'
        : 'ws://target99api.serwex.in/ws/fruit/leaderboard/$contestId';
  }
}

