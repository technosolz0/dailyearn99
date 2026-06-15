import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  static const bool useLocalBackend = false;

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static String get baseUrl {
    if (useLocalBackend) {
      if (kIsWeb) return 'http://127.0.0.1:8000/api';
      return _isAndroid
          ? 'http://10.0.2.2:8000/api'
          : 'http://127.0.0.1:8000/api';
    }
    if (kIsWeb) {
      return 'https://api.dailyearn99.in/api';
    }
    // Android emulator loops back to host via 10.0.2.2
    return _isAndroid
        ? 'https://api.dailyearn99.in/api'
        : 'https://api.dailyearn99.in/api';
  }

  static String get wsUrl {
    if (useLocalBackend) {
      if (kIsWeb) return 'ws://127.0.0.1:8000/ws/leaderboard';
      return _isAndroid
          ? 'ws://10.0.2.2:8000/ws/leaderboard'
          : 'ws://127.0.0.1:8000/ws/leaderboard';
    }
    if (kIsWeb) {
      return 'wss://api.dailyearn99.in/ws/leaderboard';
    }
    return _isAndroid
        ? 'wss://api.dailyearn99.in/ws/leaderboard'
        : 'wss://api.dailyearn99.in/ws/leaderboard';
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
  static String puzzleLeaderboard(int contestId) =>
      '/puzzle/leaderboard/$contestId';
  static String puzzleWs(int contestId) {
    if (useLocalBackend) {
      if (kIsWeb) return 'ws://127.0.0.1:8000/ws/puzzle/leaderboard/$contestId';
      return _isAndroid
          ? 'ws://10.0.2.2:8000/ws/puzzle/leaderboard/$contestId'
          : 'ws://127.0.0.1:8000/ws/puzzle/leaderboard/$contestId';
    }
    if (kIsWeb) {
      return 'wss://api.dailyearn99.in/ws/puzzle/leaderboard/$contestId';
    }
    return _isAndroid
        ? 'wss://api.dailyearn99.in/ws/puzzle/leaderboard/$contestId'
        : 'wss://api.dailyearn99.in/ws/puzzle/leaderboard/$contestId';
  }

  // Word Game APIs
  static const String wordContests = '/word-game/contests';
  static const String wordJoin = '/word-game/join';
  static String wordStart(int contestId) => '/word-game/start/$contestId';
  static const String wordSubmit = '/word-game/submit';
  static String wordLeaderboard(int contestId) =>
      '/word-game/leaderboard/$contestId';
  static String wordWs(int contestId) {
    if (useLocalBackend) {
      if (kIsWeb) return 'ws://127.0.0.1:8000/ws/word/leaderboard/$contestId';
      return _isAndroid
          ? 'ws://10.0.2.2:8000/ws/word/leaderboard/$contestId'
          : 'ws://127.0.0.1:8000/ws/word/leaderboard/$contestId';
    }
    if (kIsWeb) {
      return 'wss://api.dailyearn99.in/ws/word/leaderboard/$contestId';
    }
    return _isAndroid
        ? 'wss://api.dailyearn99.in/ws/word/leaderboard/$contestId'
        : 'wss://api.dailyearn99.in/ws/word/leaderboard/$contestId';
  }

  // Fruit Slicing APIs
  static const String fruitContests = '/fruit-game/contests';
  static const String fruitJoin = '/fruit-game/join';
  static String fruitStart(int contestId) => '/fruit-game/start/$contestId';
  static const String fruitSubmit = '/fruit-game/submit';
  static String fruitLeaderboard(int contestId) =>
      '/fruit-game/leaderboard/$contestId';
  static String fruitWs(int contestId) {
    if (useLocalBackend) {
      if (kIsWeb) return 'ws://127.0.0.1:8000/ws/fruit/leaderboard/$contestId';
      return _isAndroid
          ? 'ws://10.0.2.2:8000/ws/fruit/leaderboard/$contestId'
          : 'ws://127.0.0.1:8000/ws/fruit/leaderboard/$contestId';
    }
    if (kIsWeb) {
      return 'wss://api.dailyearn99.in/ws/fruit/leaderboard/$contestId';
    }
    return _isAndroid
        ? 'wss://api.dailyearn99.in/ws/fruit/leaderboard/$contestId'
        : 'wss://api.dailyearn99.in/ws/fruit/leaderboard/$contestId';
  }

  // Go Arrows APIs
  static const String arrowContests = '/arrow/contests';
  static String arrowStart(int contestId) => '/arrow/start/$contestId';
  static const String arrowSubmit = '/arrow/submit-score';
  static String arrowLeaderboard(int contestId) =>
      '/arrow/leaderboard/$contestId';
  static String arrowWs(int contestId) {
    if (useLocalBackend) {
      if (kIsWeb) return 'ws://127.0.0.1:8000/ws/arrow/leaderboard/$contestId';
      return _isAndroid
          ? 'ws://10.0.2.2:8000/ws/arrow/leaderboard/$contestId'
          : 'ws://127.0.0.1:8000/ws/arrow/leaderboard/$contestId';
    }
    if (kIsWeb) {
      return 'wss://api.dailyearn99.in/ws/arrow/leaderboard/$contestId';
    }
    return _isAndroid
        ? 'wss://api.dailyearn99.in/ws/arrow/leaderboard/$contestId'
        : 'wss://api.dailyearn99.in/ws/arrow/leaderboard/$contestId';
  }

  // Lottery APIs
  static const String lotteryDraws = '/lottery/draws';
  static const String lotteryBuy = '/lottery/buy';
  static const String lotteryMyTickets = '/lottery/my-tickets';
}
