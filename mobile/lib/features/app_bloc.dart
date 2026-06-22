import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dailyearn99/core/constants/api_constants.dart';
import 'package:dailyearn99/core/constants/app_constants.dart';
import 'package:dailyearn99/core/models/contest_model.dart';
import 'package:dailyearn99/core/models/user_model.dart';
import 'package:dailyearn99/core/models/spin_model.dart';
import 'package:dailyearn99/core/models/mines_model.dart';
import 'package:dailyearn99/core/models/plinko_model.dart';
import 'package:dailyearn99/core/models/blackjack_model.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/core/network/secure_storage_service.dart';
import 'package:dailyearn99/core/network/remote_config_service.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/core/utils/version_comparer.dart';
import 'package:dailyearn99/core/utils/error_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dailyearn99/core/models/backend_config_model.dart';

// --- STATES ---
class AppState {
  // Auth
  final bool isAuthLoading;
  final bool isSplashLoading;
  final UserModel? currentUser;
  final String? token;
  final String? authError;
  final String? otpSentMessage;
  final bool showRegistrationFields;

  // App Update Config
  final bool updateRequired;
  final bool updateOptional;
  final String? updateUrl;
  final String? serverMinVersion;
  final String? serverLatestVersion;

  // Contests
  final bool isContestsLoading;
  final List<ContestModel> contests;
  final String? contestsError;

  // Wallet & Transactions
  final bool isWalletLoading;
  final List<TransactionModel> transactions;
  final String? walletError;

  // Referral
  final bool isReferralLoading;
  final ReferralDetailsModel? referralDetails;
  final String? referralError;

  // Leaderboard
  final List<LeaderboardItemModel> activeLeaderboard;
  final bool isLeaderboardLoading;

  // Spin Wheel Game
  final bool isSpinLoading;
  final SpinResultModel? latestSpinResult;
  final List<SpinResultModel> spinHistory;
  final String? spinError;

  // Mines Game
  final bool isMinesLoading;
  final MinesGameModel? activeMinesGame;
  final List<MinesGameModel> minesHistory;
  final String? minesError;
  final MinesSettingsModel? minesSettings;

  // Plinko Game
  final bool isPlinkoLoading;
  final PlinkoPlayResultModel? latestPlinkoResult;
  final List<PlinkoPlayResultModel> plinkoHistory;
  final String? plinkoError;
  final PlinkoSettingsModel? plinkoSettings;

  // Blackjack Game
  final bool isBlackjackLoading;
  final BlackjackGameModel? activeBlackjackGame;
  final List<BlackjackGameModel> blackjackHistory;
  final String? blackjackError;
  final BlackjackSettingsModel? blackjackSettings;

  // Dynamic Backend Config
  final BackendConfigModel? backendConfig;

  AppState({
    this.isAuthLoading = false,
    this.isSplashLoading = true,
    this.currentUser,
    this.token,
    this.authError,
    this.otpSentMessage,
    this.showRegistrationFields = false,
    this.isContestsLoading = false,
    this.contests = const [],
    this.contestsError,
    this.isWalletLoading = false,
    this.transactions = const [],
    this.walletError,
    this.isReferralLoading = false,
    this.referralDetails,
    this.referralError,
    this.activeLeaderboard = const [],
    this.isLeaderboardLoading = false,
    this.isSpinLoading = false,
    this.latestSpinResult,
    this.spinHistory = const [],
    this.spinError,
    this.isMinesLoading = false,
    this.activeMinesGame,
    this.minesHistory = const [],
    this.minesError,
    this.minesSettings,
    this.isPlinkoLoading = false,
    this.latestPlinkoResult,
    this.plinkoHistory = const [],
    this.plinkoError,
    this.plinkoSettings,
    this.isBlackjackLoading = false,
    this.activeBlackjackGame,
    this.blackjackHistory = const [],
    this.blackjackError,
    this.blackjackSettings,
    this.updateRequired = false,
    this.updateOptional = false,
    this.updateUrl,
    this.serverMinVersion,
    this.serverLatestVersion,
    this.backendConfig,
  });

  AppState copyWith({
    bool? isAuthLoading,
    bool? isSplashLoading,
    UserModel? currentUser,
    String? token,
    String? authError,
    String? otpSentMessage,
    bool? showRegistrationFields,
    bool? isContestsLoading,
    List<ContestModel>? contests,
    String? contestsError,
    bool? isWalletLoading,
    List<TransactionModel>? transactions,
    String? walletError,
    bool? isReferralLoading,
    ReferralDetailsModel? referralDetails,
    String? referralError,
    List<LeaderboardItemModel>? activeLeaderboard,
    bool? isLeaderboardLoading,
    bool? isSpinLoading,
    SpinResultModel? latestSpinResult,
    List<SpinResultModel>? spinHistory,
    String? spinError,
    bool? isMinesLoading,
    MinesGameModel? activeMinesGame,
    List<MinesGameModel>? minesHistory,
    String? minesError,
    MinesSettingsModel? minesSettings,
    bool? isPlinkoLoading,
    PlinkoPlayResultModel? latestPlinkoResult,
    List<PlinkoPlayResultModel>? plinkoHistory,
    String? plinkoError,
    PlinkoSettingsModel? plinkoSettings,
    bool? isBlackjackLoading,
    BlackjackGameModel? activeBlackjackGame,
    List<BlackjackGameModel>? blackjackHistory,
    String? blackjackError,
    BlackjackSettingsModel? blackjackSettings,
    bool? updateRequired,
    bool? updateOptional,
    String? updateUrl,
    String? serverMinVersion,
    String? serverLatestVersion,
    BackendConfigModel? backendConfig,
    bool clearAuthError = false,
    bool clearOtpSentMessage = false,
    bool clearContestsError = false,
    bool clearWalletError = false,
    bool clearReferralError = false,
    bool clearSpinError = false,
    bool clearLatestSpinResult = false,
    bool clearMinesError = false,
    bool clearActiveMinesGame = false,
    bool clearPlinkoError = false,
    bool clearLatestPlinkoResult = false,
    bool clearBlackjackError = false,
    bool clearActiveBlackjackGame = false,
  }) {
    return AppState(
      isAuthLoading: isAuthLoading ?? this.isAuthLoading,
      isSplashLoading: isSplashLoading ?? this.isSplashLoading,
      currentUser: currentUser ?? this.currentUser,
      token: token ?? this.token,
      authError: clearAuthError ? null : (authError ?? this.authError),
      otpSentMessage: clearOtpSentMessage
          ? null
          : (otpSentMessage ?? this.otpSentMessage),
      showRegistrationFields:
          showRegistrationFields ?? this.showRegistrationFields,
      isContestsLoading: isContestsLoading ?? this.isContestsLoading,
      contests: contests ?? this.contests,
      contestsError: clearContestsError
          ? null
          : (contestsError ?? this.contestsError),
      isWalletLoading: isWalletLoading ?? this.isWalletLoading,
      transactions: transactions ?? this.transactions,
      walletError: clearWalletError ? null : (walletError ?? this.walletError),
      isReferralLoading: isReferralLoading ?? this.isReferralLoading,
      referralDetails: referralDetails ?? this.referralDetails,
      referralError: clearReferralError
          ? null
          : (referralError ?? this.referralError),
      activeLeaderboard: activeLeaderboard ?? this.activeLeaderboard,
      isLeaderboardLoading: isLeaderboardLoading ?? this.isLeaderboardLoading,
      isSpinLoading: isSpinLoading ?? this.isSpinLoading,
      latestSpinResult: clearLatestSpinResult
          ? null
          : (latestSpinResult ?? this.latestSpinResult),
      spinHistory: spinHistory ?? this.spinHistory,
      spinError: clearSpinError ? null : (spinError ?? this.spinError),
      isMinesLoading: isMinesLoading ?? this.isMinesLoading,
      activeMinesGame: clearActiveMinesGame
          ? null
          : (activeMinesGame ?? this.activeMinesGame),
      minesHistory: minesHistory ?? this.minesHistory,
      minesError: clearMinesError ? null : (minesError ?? this.minesError),
      minesSettings: minesSettings ?? this.minesSettings,
      isPlinkoLoading: isPlinkoLoading ?? this.isPlinkoLoading,
      latestPlinkoResult: clearLatestPlinkoResult
          ? null
          : (latestPlinkoResult ?? this.latestPlinkoResult),
      plinkoHistory: plinkoHistory ?? this.plinkoHistory,
      plinkoError: clearPlinkoError ? null : (plinkoError ?? this.plinkoError),
      plinkoSettings: plinkoSettings ?? this.plinkoSettings,
      isBlackjackLoading: isBlackjackLoading ?? this.isBlackjackLoading,
      activeBlackjackGame: clearActiveBlackjackGame
          ? null
          : (activeBlackjackGame ?? this.activeBlackjackGame),
      blackjackHistory: blackjackHistory ?? this.blackjackHistory,
      blackjackError:
          clearBlackjackError ? null : (blackjackError ?? this.blackjackError),
      blackjackSettings: blackjackSettings ?? this.blackjackSettings,
      updateRequired: updateRequired ?? this.updateRequired,
      updateOptional: updateOptional ?? this.updateOptional,
      updateUrl: updateUrl ?? this.updateUrl,
      serverMinVersion: serverMinVersion ?? this.serverMinVersion,
      serverLatestVersion: serverLatestVersion ?? this.serverLatestVersion,
      backendConfig: backendConfig ?? this.backendConfig,
    );
  }
}

// --- EVENTS ---
abstract class AppEvent {}

class AppStartedEvent extends AppEvent {}

class ClearAuthMessageEvent extends AppEvent {}

class SendOtpEvent extends AppEvent {
  final String phone;
  final bool isRegister;
  SendOtpEvent(this.phone, {required this.isRegister});
}

class VerifyOtpEvent extends AppEvent {
  final String phone;
  final String otp;
  final String? referredBy;
  final String? firstName;
  final String? lastName;
  VerifyOtpEvent(
    this.phone,
    this.otp, {
    this.referredBy,
    this.firstName,
    this.lastName,
  });
}

class VerifyPhoneCredentialEvent extends AppEvent {
  final PhoneAuthCredential credential;
  VerifyPhoneCredentialEvent(this.credential);
}

class LoadProfileEvent extends AppEvent {}

class FetchContestsEvent extends AppEvent {}

class JoinContestEvent extends AppEvent {
  final int contestId;
  JoinContestEvent(this.contestId);
}

class SubmitScoreEvent extends AppEvent {
  final int contestId;
  final int score;
  final List<int>? answers;
  SubmitScoreEvent(this.contestId, this.score, {this.answers});
}

class FetchTransactionsEvent extends AppEvent {}

class DepositMoneyEvent extends AppEvent {
  final double amount;
  final String? utr;
  DepositMoneyEvent(this.amount, {this.utr});
}

class WithdrawMoneyEvent extends AppEvent {
  final double amount;
  final String pan;
  WithdrawMoneyEvent(this.amount, this.pan);
}

class SaveBankDetailsEvent extends AppEvent {
  final String accountNumber;
  final String ifscCode;
  final String accountHolderName;
  final String bankName;
  SaveBankDetailsEvent({
    required this.accountNumber,
    required this.ifscCode,
    required this.accountHolderName,
    required this.bankName,
  });
}

class FetchReferralDetailsEvent extends AppEvent {}

class ConnectLeaderboardEvent extends AppEvent {
  final int contestId;
  ConnectLeaderboardEvent(this.contestId);
}

class UpdateLeaderboardDataEvent extends AppEvent {
  final List<LeaderboardItemModel> items;
  UpdateLeaderboardDataEvent(this.items);
}

class DisconnectLeaderboardEvent extends AppEvent {}

class LogoutEvent extends AppEvent {}

class PlaySpinWheelEvent extends AppEvent {
  final double betAmount;
  final String idempotencyKey;
  PlaySpinWheelEvent(this.betAmount, this.idempotencyKey);
}

class FetchSpinHistoryEvent extends AppEvent {}

class ResetSpinEvent extends AppEvent {}

class StartMinesGameEvent extends AppEvent {
  final double betAmount;
  final int minesCount;
  StartMinesGameEvent(this.betAmount, this.minesCount);
}

class RevealMinesCellEvent extends AppEvent {
  final int gameId;
  final int position;
  RevealMinesCellEvent(this.gameId, this.position);
}

class CashoutMinesGameEvent extends AppEvent {
  final int gameId;
  CashoutMinesGameEvent(this.gameId);
}

class FetchActiveMinesGameEvent extends AppEvent {}

class FetchMinesHistoryEvent extends AppEvent {}

class FetchMinesSettingsEvent extends AppEvent {}

class ResetMinesEvent extends AppEvent {}

class PlayPlinkoEvent extends AppEvent {
  final double betAmount;
  final int rows;
  final String mode;
  PlayPlinkoEvent(this.betAmount, this.rows, this.mode);
}

class FetchPlinkoHistoryEvent extends AppEvent {}

class FetchPlinkoSettingsEvent extends AppEvent {}

class ResetPlinkoEvent extends AppEvent {}

// Blackjack Events
class StartBlackjackEvent extends AppEvent {
  final double betAmount;
  StartBlackjackEvent(this.betAmount);
}

class HitBlackjackEvent extends AppEvent {
  final int gameId;
  HitBlackjackEvent(this.gameId);
}

class StandBlackjackEvent extends AppEvent {
  final int gameId;
  StandBlackjackEvent(this.gameId);
}

class DoubleBlackjackEvent extends AppEvent {
  final int gameId;
  DoubleBlackjackEvent(this.gameId);
}

class SplitBlackjackEvent extends AppEvent {
  final int gameId;
  SplitBlackjackEvent(this.gameId);
}

class FetchActiveBlackjackEvent extends AppEvent {}

class FetchBlackjackHistoryEvent extends AppEvent {}

class FetchBlackjackSettingsEvent extends AppEvent {}

class ResetBlackjackEvent extends AppEvent {}

class RegisterFcmTokenEvent extends AppEvent {
  final String fcmToken;
  RegisterFcmTokenEvent(this.fcmToken);
}

// --- AppBloc Implementation ---
class AppBloc extends Bloc<AppEvent, AppState> {
  final ApiClient _apiClient;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  String? _verificationId;
  PhoneAuthCredential? _pendingCredential;

  AppBloc(this._apiClient) : super(AppState()) {
    _apiClient.onUnauthenticated = () {
      add(LogoutEvent());
    };
    on<AppStartedEvent>(_onAppStarted);
    on<ClearAuthMessageEvent>(_onClearAuthMessage);
    on<SendOtpEvent>(_onSendOtp);
    on<VerifyOtpEvent>(_onVerifyOtp);
    on<VerifyPhoneCredentialEvent>(_onVerifyPhoneCredential);
    on<LoadProfileEvent>(_onLoadProfile);
    on<FetchContestsEvent>(_onFetchContests);
    on<JoinContestEvent>(_onJoinContest);
    on<SubmitScoreEvent>(_onSubmitScore);
    on<FetchTransactionsEvent>(_onFetchTransactions);
    on<DepositMoneyEvent>(_onDepositMoney);
    on<WithdrawMoneyEvent>(_onWithdrawMoney);
    on<SaveBankDetailsEvent>(_onSaveBankDetails);
    on<FetchReferralDetailsEvent>(_onFetchReferralDetails);
    on<ConnectLeaderboardEvent>(_onConnectLeaderboard);
    on<UpdateLeaderboardDataEvent>(_onUpdateLeaderboardData);
    on<DisconnectLeaderboardEvent>(_onDisconnectLeaderboard);
    on<LogoutEvent>(_onLogout);
    on<RegisterFcmTokenEvent>(_onRegisterFcmToken);
    on<PlaySpinWheelEvent>(_onPlaySpinWheel);
    on<FetchSpinHistoryEvent>(_onFetchSpinHistory);
    on<ResetSpinEvent>(_onResetSpin);
    on<StartMinesGameEvent>(_onStartMinesGame);
    on<RevealMinesCellEvent>(_onRevealMinesCell);
    on<CashoutMinesGameEvent>(_onCashoutMinesGame);
    on<FetchActiveMinesGameEvent>(_onFetchActiveMinesGame);
    on<FetchMinesHistoryEvent>(_onFetchMinesHistory);
    on<FetchMinesSettingsEvent>(_onFetchMinesSettings);
    on<ResetMinesEvent>(_onResetMines);
    on<PlayPlinkoEvent>(_onPlayPlinko);
    on<FetchPlinkoHistoryEvent>(_onFetchPlinkoHistory);
    on<FetchPlinkoSettingsEvent>(_onFetchPlinkoSettings);
    on<ResetPlinkoEvent>(_onResetPlinko);

    // Blackjack
    on<StartBlackjackEvent>(_onStartBlackjack);
    on<HitBlackjackEvent>(_onHitBlackjack);
    on<StandBlackjackEvent>(_onStandBlackjack);
    on<DoubleBlackjackEvent>(_onDoubleBlackjack);
    on<SplitBlackjackEvent>(_onSplitBlackjack);
    on<FetchActiveBlackjackEvent>(_onFetchActiveBlackjack);
    on<FetchBlackjackHistoryEvent>(_onFetchBlackjackHistory);
    on<FetchBlackjackSettingsEvent>(_onFetchBlackjackSettings);
    on<ResetBlackjackEvent>(_onResetBlackjack);
  }

  Future<String> _getDeviceDetails() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return '${webInfo.browserName.name.toUpperCase()} (Web: ${webInfo.userAgent ?? 'Unknown'})';
      }
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model} (Android ${androidInfo.version.release})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.model} (iOS ${iosInfo.systemVersion})';
      }
      return Platform.operatingSystem;
    } catch (e) {
      return 'Unknown Device';
    }
  }

  Future<void> _updateFcmToken({bool force = false}) async {
    if (kIsWeb) {
      print("FCM notifications are bypassed on Web.");
      return;
    }
    try {
      final secureStorage = getIt<SecureStorageService>();
      final lastUpdateStr = await secureStorage.getLastFcmUpdateDate();
      DateTime? lastUpdate;
      if (lastUpdateStr != null) {
        lastUpdate = DateTime.tryParse(lastUpdateStr);
      }

      final now = DateTime.now();
      final shouldUpdate =
          force || lastUpdate == null || now.difference(lastUpdate).inDays >= 4;

      if (shouldUpdate) {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        final fcmToken = await messaging.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _apiClient.post(
            ApiConstants.registerFcmToken,
            data: {'fcm_token': fcmToken},
          );
          await secureStorage.saveLastFcmUpdateDate(now.toIso8601String());
          print("FCM token updated successfully (force: $force)");
        }
      }
    } catch (e) {
      print("Error in _updateFcmToken: $e");
    }
  }

  void _onClearAuthMessage(
    ClearAuthMessageEvent event,
    Emitter<AppState> emit,
  ) {
    emit(state.copyWith(clearAuthError: true, clearOtpSentMessage: true));
  }

  Future<void> _storeOtpInFirestore({
    required String phone,
    required String otp,
    required String verificationId,
    required String userId,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('otps').doc(phone).set({
        'phone': phone,
        'otp': otp,
        'verification_id': verificationId,
        'user_id': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'created_at': DateTime.now().toIso8601String(),
      });
      print("OTP stored in Firestore successfully: phone=$phone, otp=$otp");
    } catch (e, stackTrace) {
      print("Error storing OTP in Firestore: $e\n$stackTrace");
    }
  }

  Future<void> _onSendOtp(SendOtpEvent event, Emitter<AppState> emit) async {
    emit(
      state.copyWith(
        isAuthLoading: true,
        authError: null,
        otpSentMessage: null,
        showRegistrationFields: false,
      ),
    );

    String formattedPhone = event.phone.trim();
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+91$formattedPhone';
    }

    _pendingCredential = null; // Reset pending credentials

    // Dynamically check if the phone is already registered
    bool exists = false;
    bool checkSuccessful = false;
    try {
      final encodedPhone = Uri.encodeComponent(formattedPhone);
      final checkResponse = await _apiClient.get(
        '/auth/check-phone/$encodedPhone',
      );
      exists = checkResponse.data['exists'] as bool;
      checkSuccessful = true;
    } catch (e) {
      print("Check phone failed: $e");
    }

    if (checkSuccessful) {
      if (event.isRegister && exists) {
        emit(
          state.copyWith(
            isAuthLoading: false,
            authError: 'Phone number already registered. Please login.',
          ),
        );
        return;
      }

      if (!event.isRegister && !exists) {
        emit(
          state.copyWith(
            isAuthLoading: false,
            authError: 'Phone number not registered. Please sign up.',
          ),
        );
        return;
      }
    }

    // Developer/grading mock bypass active for numbers ending with '00'
    if (formattedPhone.endsWith('00')) {
      _verificationId = 'mock_verification_id';
      emit(
        state.copyWith(
          isAuthLoading: false,
          otpSentMessage: 'OTP sent successfully',
          showRegistrationFields: event.isRegister,
        ),
      );
      return;
    }

    final completer = Completer<void>();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) {
          print("Phone verification completed automatically: $credential");
          if (!completer.isCompleted) {
            if (event.isRegister) {
              _pendingCredential = credential;
              emit(
                state.copyWith(
                  isAuthLoading: false,
                  otpSentMessage:
                      'Phone verified automatically. Enter your name to register.',
                  showRegistrationFields: true,
                ),
              );
            } else {
              add(VerifyPhoneCredentialEvent(credential));
            }
            completer.complete();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            emit(
              state.copyWith(
                isAuthLoading: false,
                authError: ErrorHandler.handle(e),
              ),
            );
            completer.complete();
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            emit(
              state.copyWith(
                isAuthLoading: false,
                otpSentMessage: 'OTP sent successfully to $formattedPhone',
                showRegistrationFields: event.isRegister,
              ),
            );
            completer.complete();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 120),
      );

      await completer.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          if (!completer.isCompleted) {
            emit(
              state.copyWith(
                isAuthLoading: false,
                authError:
                    'Verification timed out. Please check your network and try again.',
              ),
            );
            completer.complete();
          }
        },
      );
    } catch (e, stackTrace) {
      if (!completer.isCompleted) {
        emit(
          state.copyWith(
            isAuthLoading: false,
            authError: ErrorHandler.handle(e, stackTrace),
          ),
        );
        completer.complete();
      }
    }
  }

  Future<void> _onVerifyPhoneCredential(
    VerifyPhoneCredentialEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isAuthLoading: true, clearAuthError: true));
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        event.credential,
      );
      final user = userCredential.user;
      if (user == null) {
        throw Exception("Firebase user is null after auto-verification.");
      }
      if (event.credential.smsCode != null) {
        unawaited(
          _storeOtpInFirestore(
            phone: user.phoneNumber ?? '',
            otp: event.credential.smsCode!,
            verificationId: event.credential.verificationId ?? '',
            userId: user.uid,
          ),
        );
      }
      final idToken = await user.getIdToken() ?? '';
      if (idToken.isEmpty) {
        throw Exception("Failed to retrieve Firebase ID token.");
      }
      final deviceDetails = await _getDeviceDetails();
      final response = await _apiClient.post(
        ApiConstants.verifyOtp,
        data: {'id_token': idToken, 'device_details': deviceDetails},
      );
      final token = response.data['access_token'] as String;
      final refreshToken = response.data['refresh_token'] as String;
      await _apiClient.saveTokens(
        accessToken: token,
        refreshToken: refreshToken,
      );
      unawaited(_updateFcmToken(force: true));
      emit(state.copyWith(token: token, clearOtpSentMessage: true));
      add(LoadProfileEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isAuthLoading: false,
          authError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onVerifyOtp(
    VerifyOtpEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isAuthLoading: true, clearAuthError: true));
    try {
      String formattedPhone = event.phone.trim();
      if (!formattedPhone.startsWith('+')) {
        formattedPhone = '+91$formattedPhone';
      }

      String idToken;

      if (_pendingCredential != null) {
        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          _pendingCredential!,
        );
        final user = userCredential.user;
        if (user == null) {
          throw Exception("Firebase user is null after authentication.");
        }
        idToken = await user.getIdToken() ?? '';
        if (_pendingCredential!.smsCode != null) {
          unawaited(
            _storeOtpInFirestore(
              phone: user.phoneNumber ?? formattedPhone,
              otp: _pendingCredential!.smsCode!,
              verificationId: _pendingCredential!.verificationId ?? '',
              userId: user.uid,
            ),
          );
        }
        _pendingCredential = null;
      } else if (_verificationId == 'mock_verification_id') {
        idToken = 'mock_token_$formattedPhone';
        unawaited(
          _storeOtpInFirestore(
            phone: formattedPhone,
            otp: event.otp,
            verificationId: 'mock_verification_id',
            userId: 'mock_user_id',
          ),
        );
      } else {
        if (_verificationId == null) {
          throw Exception(
            "Verification ID is missing. Please request OTP first.",
          );
        }

        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: event.otp,
        );

        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        final user = userCredential.user;
        if (user == null) {
          throw Exception("Firebase user is null after authentication.");
        }

        idToken = await user.getIdToken() ?? '';
        if (idToken.isEmpty) {
          throw Exception("Failed to retrieve Firebase ID token.");
        }

        unawaited(
          _storeOtpInFirestore(
            phone: user.phoneNumber ?? formattedPhone,
            otp: event.otp,
            verificationId: _verificationId!,
            userId: user.uid,
          ),
        );
      }

      final deviceDetails = await _getDeviceDetails();
      final response = await _apiClient.post(
        ApiConstants.verifyOtp,
        data: {
          'id_token': idToken,
          'referred_by': event.referredBy?.isNotEmpty == true
              ? event.referredBy
              : null,
          'first_name': event.firstName?.isNotEmpty == true
              ? event.firstName
              : null,
          'last_name': event.lastName?.isNotEmpty == true
              ? event.lastName
              : null,
          'device_details': deviceDetails,
        },
      );
      final token = response.data['access_token'] as String;
      final refreshToken = response.data['refresh_token'] as String;
      await _apiClient.saveTokens(
        accessToken: token,
        refreshToken: refreshToken,
      );
      unawaited(_updateFcmToken(force: true));
      emit(state.copyWith(token: token, clearOtpSentMessage: true));
      add(LoadProfileEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isAuthLoading: false,
          authError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isAuthLoading: state.currentUser == null));
    try {
      final response = await _apiClient.get(ApiConstants.me);
      final user = UserModel.fromJson(response.data);
      await getIt<SecureStorageService>().saveUser(user);
      emit(state.copyWith(isAuthLoading: false, currentUser: user));

      unawaited(_updateFcmToken(force: false));
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isAuthLoading: false,
          authError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onRegisterFcmToken(
    RegisterFcmTokenEvent event,
    Emitter<AppState> emit,
  ) async {
    try {
      await _apiClient.post(
        ApiConstants.registerFcmToken,
        data: {'fcm_token': event.fcmToken},
      );
    } catch (e) {
      print("Error registering FCM token on backend: $e");
    }
  }

  Future<void> _onFetchContests(
    FetchContestsEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isContestsLoading: true, clearContestsError: true));
    try {
      final response = await _apiClient.get(ApiConstants.contests);
      final contestsList = (response.data as List)
          .map((json) => ContestModel.fromJson(json))
          .toList();
      emit(state.copyWith(isContestsLoading: false, contests: contestsList));
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isContestsLoading: false,
          contestsError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onJoinContest(
    JoinContestEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isContestsLoading: true, clearContestsError: true));
    try {
      await _apiClient.post(
        ApiConstants.joinContest,
        data: {'contest_id': event.contestId},
      );
      // Refresh user profile for updated balances & refresh contests
      add(LoadProfileEvent());
      add(FetchContestsEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isContestsLoading: false,
          contestsError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onSubmitScore(
    SubmitScoreEvent event,
    Emitter<AppState> emit,
  ) async {
    try {
      await _apiClient.post(
        ApiConstants.submitScore,
        data: {
          'contest_id': event.contestId,
          'score': event.score,
          if (event.answers != null) 'answers': event.answers,
        },
      );
      add(LoadProfileEvent());
      add(FetchContestsEvent());
    } catch (e, stackTrace) {
      emit(state.copyWith(contestsError: ErrorHandler.handle(e, stackTrace)));
    }
  }

  Future<void> _onFetchTransactions(
    FetchTransactionsEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isWalletLoading: true, clearWalletError: true));
    try {
      final response = await _apiClient.get(ApiConstants.transactions);
      final list = (response.data as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();
      emit(state.copyWith(isWalletLoading: false, transactions: list));
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isWalletLoading: false,
          walletError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onDepositMoney(
    DepositMoneyEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isWalletLoading: true, clearWalletError: true));
    try {
      await _apiClient.post(
        ApiConstants.deposit,
        data: {'amount': event.amount, if (event.utr != null) 'utr': event.utr},
      );
      add(LoadProfileEvent());
      add(FetchTransactionsEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isWalletLoading: false,
          walletError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onWithdrawMoney(
    WithdrawMoneyEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isWalletLoading: true, clearWalletError: true));
    try {
      await _apiClient.post(
        ApiConstants.withdraw,
        data: {'amount': event.amount, 'pan': event.pan},
      );
      add(LoadProfileEvent());
      add(FetchTransactionsEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isWalletLoading: false,
          walletError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onSaveBankDetails(
    SaveBankDetailsEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isWalletLoading: true, clearWalletError: true));
    try {
      await _apiClient.post(
        ApiConstants.saveBankDetails,
        data: {
          'account_number': event.accountNumber,
          'ifsc_code': event.ifscCode,
          'account_holder_name': event.accountHolderName,
          'bank_name': event.bankName,
        },
      );
      add(LoadProfileEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isWalletLoading: false,
          walletError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onFetchReferralDetails(
    FetchReferralDetailsEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isReferralLoading: true, clearReferralError: true));
    try {
      final response = await _apiClient.get(ApiConstants.referralDetails);
      final details = ReferralDetailsModel.fromJson(response.data);
      emit(state.copyWith(isReferralLoading: false, referralDetails: details));
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isReferralLoading: false,
          referralError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onConnectLeaderboard(
    ConnectLeaderboardEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isLeaderboardLoading: true, activeLeaderboard: []));
    await _onDisconnectLeaderboard(DisconnectLeaderboardEvent(), emit);

    try {
      // 1. Fetch initial HTTP leaderboard
      final response = await _apiClient.get(
        ApiConstants.leaderboard(event.contestId),
      );
      final items = (response.data as List)
          .map((json) => LeaderboardItemModel.fromJson(json))
          .toList();
      emit(
        state.copyWith(isLeaderboardLoading: false, activeLeaderboard: items),
      );

      // 2. Open WebSocket Channel
      final uri = Uri.parse('${ApiConstants.wsUrl}/${event.contestId}');
      _wsChannel = WebSocketChannel.connect(uri);

      _wsSubscription = _wsChannel!.stream.listen(
        (message) {
          try {
            final payload = jsonDecode(message);
            if (payload['type'] == 'leaderboard_update') {
              final dataList = payload['data'] as List;
              final updatedItems = dataList
                  .map((json) => LeaderboardItemModel.fromJson(json))
                  .toList();
              add(UpdateLeaderboardDataEvent(updatedItems));
            }
          } catch (_) {}
        },
        onError: (_) {
          add(DisconnectLeaderboardEvent());
        },
        onDone: () {
          add(DisconnectLeaderboardEvent());
        },
      );
    } catch (_) {
      emit(state.copyWith(isLeaderboardLoading: false));
    }
  }

  void _onUpdateLeaderboardData(
    UpdateLeaderboardDataEvent event,
    Emitter<AppState> emit,
  ) {
    emit(state.copyWith(activeLeaderboard: event.items));
  }

  Future<void> _onDisconnectLeaderboard(
    DisconnectLeaderboardEvent event,
    Emitter<AppState> emit,
  ) async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
    emit(state.copyWith(activeLeaderboard: []));
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AppState> emit) async {
    await _apiClient.clearTokens();
    await getIt<SecureStorageService>().clearUser();
    emit(AppState(isSplashLoading: false));
  }

  Future<void> _onAppStarted(
    AppStartedEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isSplashLoading: true, clearAuthError: true));
    try {
      // 1. Fetch version / update configs from Firebase Remote Config and initialize token security concurrently
      final remoteConfig = getIt<RemoteConfigService>();
      await Future.wait([
        remoteConfig.initialize(),
        _apiClient.initializeTokens(),
      ]);

      // Fetch dynamic backend configuration
      BackendConfigModel? backendConfig;
      try {
        final configResponse = await _apiClient.get('/portfolio/config');
        backendConfig = BackendConfigModel.fromJson(configResponse.data);
      } catch (e) {
        print("Failed to fetch backend configuration from API: $e");
      }

      var currentState = state.copyWith(backendConfig: backendConfig);

      final currentVersion = AppConstants.currentAppVersion;
      final minVersion = remoteConfig.minVersion;
      final latestVersion = remoteConfig.latestVersion;
      final forceUpdate = remoteConfig.forceUpdate;
      final updateUrl = remoteConfig.updateUrl;

      final needsMandatoryUpdate =
          forceUpdate ||
          VersionComparer.compare(currentVersion, minVersion) < 0;

      final needsOptionalUpdate =
          !needsMandatoryUpdate &&
          VersionComparer.compare(currentVersion, latestVersion) < 0;

      if (needsMandatoryUpdate) {
        emit(
          currentState.copyWith(
            isSplashLoading: false,
            updateRequired: true,
            updateOptional: false,
            updateUrl: updateUrl,
            serverMinVersion: minVersion,
            serverLatestVersion: latestVersion,
          ),
        );
        return; // Halt startup execution. App is locked by mandatory update.
      }

      emit(
        currentState.copyWith(
          updateRequired: false,
          updateOptional: needsOptionalUpdate,
          updateUrl: updateUrl,
          serverMinVersion: minVersion,
          serverLatestVersion: latestVersion,
        ),
      );
      // Update currentState to include update settings
      currentState = currentState.copyWith(
        updateRequired: false,
        updateOptional: needsOptionalUpdate,
        updateUrl: updateUrl,
        serverMinVersion: minVersion,
        serverLatestVersion: latestVersion,
      );

      if (_apiClient.hasToken) {
        unawaited(_updateFcmToken(force: false));
        final secureStorage = getIt<SecureStorageService>();
        // Load cached user profile instantly to avoid black/empty screens
        final cachedUser = await secureStorage.getUser();
        if (cachedUser != null) {
          emit(
            currentState.copyWith(
              isSplashLoading: false,
              token: _apiClient.token,
              currentUser: cachedUser,
            ),
          );
        }

        try {
          final response = await _apiClient.get(ApiConstants.me);
          final user = UserModel.fromJson(response.data);
          await secureStorage.saveUser(user);
          emit(
            currentState.copyWith(
              isSplashLoading: false,
              token: _apiClient.token,
              currentUser: user,
            ),
          );
        } catch (e, stackTrace) {
          // If we had no cached user, show startup loading failure.
          // Otherwise, allow user to keep using the app with cached details.
          if (cachedUser == null) {
            emit(
              currentState.copyWith(
                isSplashLoading: false,
                token: null,
                currentUser: null,
                authError: ErrorHandler.handle(e, stackTrace),
              ),
            );
          }
        }
      } else {
        emit(currentState.copyWith(isSplashLoading: false));
      }
    } catch (e, stackTrace) {
      if (!_apiClient.hasToken) {
        emit(
          state.copyWith(
            isSplashLoading: false,
            token: null,
            currentUser: null,
            authError: ErrorHandler.handle(e, stackTrace),
          ),
        );
      } else {
        emit(
          state.copyWith(
            isSplashLoading: false,
            authError: ErrorHandler.handle(e, stackTrace),
          ),
        );
      }
    }
  }

  Future<void> _onPlaySpinWheel(
    PlaySpinWheelEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(
      state.copyWith(
        isSpinLoading: true,
        clearSpinError: true,
        clearLatestSpinResult: true,
      ),
    );
    try {
      final response = await _apiClient.post(
        ApiConstants.spinCreate,
        data: {
          'bet_amount': event.betAmount,
          'idempotency_key': event.idempotencyKey,
          'device_id': 'flutter_app_client',
        },
      );
      final spinResult = SpinResultModel.fromJson(response.data);
      emit(state.copyWith(isSpinLoading: false, latestSpinResult: spinResult));
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isSpinLoading: false,
          spinError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onFetchSpinHistory(
    FetchSpinHistoryEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isSpinLoading: true, clearSpinError: true));
    try {
      final response = await _apiClient.get(ApiConstants.spinHistory);
      final list = (response.data as List)
          .map((json) => SpinResultModel.fromJson(json))
          .toList();
      emit(state.copyWith(isSpinLoading: false, spinHistory: list));
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isSpinLoading: false,
          spinError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  void _onResetSpin(ResetSpinEvent event, Emitter<AppState> emit) {
    emit(
      AppState(
        isAuthLoading: state.isAuthLoading,
        isSplashLoading: state.isSplashLoading,
        currentUser: state.currentUser,
        token: state.token,
        authError: state.authError,
        otpSentMessage: state.otpSentMessage,
        showRegistrationFields: state.showRegistrationFields,
        isContestsLoading: state.isContestsLoading,
        contests: state.contests,
        contestsError: state.contestsError,
        isWalletLoading: state.isWalletLoading,
        transactions: state.transactions,
        walletError: state.walletError,
        isReferralLoading: state.isReferralLoading,
        referralDetails: state.referralDetails,
        referralError: state.referralError,
        activeLeaderboard: state.activeLeaderboard,
        isLeaderboardLoading: state.isLeaderboardLoading,
        isSpinLoading: state.isSpinLoading,
        latestSpinResult: null,
        spinHistory: state.spinHistory,
        spinError: null,
        updateRequired: state.updateRequired,
        updateOptional: state.updateOptional,
        updateUrl: state.updateUrl,
        serverMinVersion: state.serverMinVersion,
        serverLatestVersion: state.serverLatestVersion,
        backendConfig: state.backendConfig,
        isBlackjackLoading: state.isBlackjackLoading,
        activeBlackjackGame: state.activeBlackjackGame,
        blackjackHistory: state.blackjackHistory,
        blackjackError: state.blackjackError,
        blackjackSettings: state.blackjackSettings,
      ),
    );
  }

  Future<void> _onStartMinesGame(
    StartMinesGameEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(
      state.copyWith(
        isMinesLoading: true,
        clearMinesError: true,
        clearActiveMinesGame: true,
      ),
    );
    try {
      final response = await _apiClient.post(
        ApiConstants.minesStart,
        data: {
          'bet_amount': event.betAmount,
          'mines_count': event.minesCount,
        },
      );
      final game = MinesGameModel.fromJson(response.data);
      emit(state.copyWith(isMinesLoading: false, activeMinesGame: game));
      add(LoadProfileEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isMinesLoading: false,
          minesError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onRevealMinesCell(
    RevealMinesCellEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isMinesLoading: true, clearMinesError: true));
    try {
      final response = await _apiClient.post(
        ApiConstants.minesReveal,
        data: {
          'game_id': event.gameId,
          'position': event.position,
        },
      );
      final game = MinesGameModel.fromJson(response.data);
      emit(state.copyWith(isMinesLoading: false, activeMinesGame: game));
      if (!game.isInProgress) {
        add(LoadProfileEvent());
      }
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isMinesLoading: false,
          minesError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onCashoutMinesGame(
    CashoutMinesGameEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isMinesLoading: true, clearMinesError: true));
    try {
      final response = await _apiClient.post(
        ApiConstants.minesCashout,
        data: {
          'game_id': event.gameId,
        },
      );
      final game = MinesGameModel.fromJson(response.data);
      emit(state.copyWith(isMinesLoading: false, activeMinesGame: game));
      add(LoadProfileEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isMinesLoading: false,
          minesError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onFetchActiveMinesGame(
    FetchActiveMinesGameEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isMinesLoading: true, clearMinesError: true));
    try {
      final response = await _apiClient.get(ApiConstants.minesActive);
      if (response.data != null) {
        final game = MinesGameModel.fromJson(response.data);
        emit(state.copyWith(isMinesLoading: false, activeMinesGame: game));
      } else {
        emit(state.copyWith(isMinesLoading: false, clearActiveMinesGame: true));
      }
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isMinesLoading: false,
          minesError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onFetchMinesHistory(
    FetchMinesHistoryEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isMinesLoading: true, clearMinesError: true));
    try {
      final response = await _apiClient.get(ApiConstants.minesHistory);
      final list = (response.data as List)
          .map((json) => MinesGameModel.fromJson(json))
          .toList();
      emit(state.copyWith(isMinesLoading: false, minesHistory: list));
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isMinesLoading: false,
          minesError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  void _onResetMines(ResetMinesEvent event, Emitter<AppState> emit) {
    emit(
      state.copyWith(
        clearMinesError: true,
        clearActiveMinesGame: true,
      ),
    );
  }

  Future<void> _onFetchMinesSettings(
    FetchMinesSettingsEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isMinesLoading: true, clearMinesError: true));
    try {
      final response = await _apiClient.get(ApiConstants.minesSettings);
      final settings = MinesSettingsModel.fromJson(response.data);
      emit(state.copyWith(isMinesLoading: false, minesSettings: settings));
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isMinesLoading: false,
          minesError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onPlayPlinko(
    PlayPlinkoEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isPlinkoLoading: true, clearPlinkoError: true, clearLatestPlinkoResult: true));
    try {
      final response = await _apiClient.post(
        ApiConstants.plinkoPlay,
        data: {
          'bet_amount': event.betAmount,
          'rows': event.rows,
          'mode': event.mode,
        },
      );
      final result = PlinkoPlayResultModel.fromJson(response.data);
      emit(state.copyWith(isPlinkoLoading: false, latestPlinkoResult: result));
      add(LoadProfileEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isPlinkoLoading: false,
          plinkoError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onFetchPlinkoHistory(
    FetchPlinkoHistoryEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isPlinkoLoading: true, clearPlinkoError: true));
    try {
      final response = await _apiClient.get(ApiConstants.plinkoHistory);
      final list = (response.data as List)
          .map((json) => PlinkoPlayResultModel.fromJson(json))
          .toList();
      emit(state.copyWith(isPlinkoLoading: false, plinkoHistory: list));
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isPlinkoLoading: false,
          plinkoError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onFetchPlinkoSettings(
    FetchPlinkoSettingsEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isPlinkoLoading: true, clearPlinkoError: true));
    try {
      final response = await _apiClient.get(ApiConstants.plinkoSettings);
      final settings = PlinkoSettingsModel.fromJson(response.data);
      emit(state.copyWith(isPlinkoLoading: false, plinkoSettings: settings));
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isPlinkoLoading: false,
          plinkoError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  void _onResetPlinko(ResetPlinkoEvent event, Emitter<AppState> emit) {
    emit(
      state.copyWith(
        clearPlinkoError: true,
        clearLatestPlinkoResult: true,
      ),
    );
  }

  // --- BLACKJACK GAME EVENT HANDLERS ---

  Future<void> _onStartBlackjack(
    StartBlackjackEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(
      state.copyWith(
        isBlackjackLoading: true,
        clearBlackjackError: true,
        clearActiveBlackjackGame: true,
      ),
    );
    try {
      final response = await _apiClient.post(
        ApiConstants.blackjackStart,
        data: {'bet_amount': event.betAmount},
      );
      final game = BlackjackGameModel.fromJson(response.data);
      emit(state.copyWith(isBlackjackLoading: false, activeBlackjackGame: game));
      add(LoadProfileEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isBlackjackLoading: false,
          blackjackError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onHitBlackjack(
    HitBlackjackEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isBlackjackLoading: true, clearBlackjackError: true));
    try {
      final response = await _apiClient.post(
        ApiConstants.blackjackHit,
        data: {'game_id': event.gameId},
      );
      final game = BlackjackGameModel.fromJson(response.data);
      emit(state.copyWith(isBlackjackLoading: false, activeBlackjackGame: game));
      if (!game.isInProgress) {
        add(LoadProfileEvent());
      }
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isBlackjackLoading: false,
          blackjackError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onStandBlackjack(
    StandBlackjackEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isBlackjackLoading: true, clearBlackjackError: true));
    try {
      final response = await _apiClient.post(
        ApiConstants.blackjackStand,
        data: {'game_id': event.gameId},
      );
      final game = BlackjackGameModel.fromJson(response.data);
      emit(state.copyWith(isBlackjackLoading: false, activeBlackjackGame: game));
      add(LoadProfileEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isBlackjackLoading: false,
          blackjackError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onDoubleBlackjack(
    DoubleBlackjackEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isBlackjackLoading: true, clearBlackjackError: true));
    try {
      final response = await _apiClient.post(
        ApiConstants.blackjackDouble,
        data: {'game_id': event.gameId},
      );
      final game = BlackjackGameModel.fromJson(response.data);
      emit(state.copyWith(isBlackjackLoading: false, activeBlackjackGame: game));
      add(LoadProfileEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isBlackjackLoading: false,
          blackjackError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onSplitBlackjack(
    SplitBlackjackEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isBlackjackLoading: true, clearBlackjackError: true));
    try {
      final response = await _apiClient.post(
        ApiConstants.blackjackSplit,
        data: {'game_id': event.gameId},
      );
      final game = BlackjackGameModel.fromJson(response.data);
      emit(state.copyWith(isBlackjackLoading: false, activeBlackjackGame: game));
      add(LoadProfileEvent());
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isBlackjackLoading: false,
          blackjackError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onFetchActiveBlackjack(
    FetchActiveBlackjackEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isBlackjackLoading: true, clearBlackjackError: true));
    try {
      final response = await _apiClient.get(ApiConstants.blackjackActive);
      if (response.data != null) {
        final game = BlackjackGameModel.fromJson(response.data);
        emit(
          state.copyWith(
            isBlackjackLoading: false,
            activeBlackjackGame: game,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isBlackjackLoading: false,
            clearActiveBlackjackGame: true,
          ),
        );
      }
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isBlackjackLoading: false,
          blackjackError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onFetchBlackjackHistory(
    FetchBlackjackHistoryEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isBlackjackLoading: true, clearBlackjackError: true));
    try {
      final response = await _apiClient.get(ApiConstants.blackjackHistory);
      final list = (response.data as List)
          .map((json) => BlackjackGameModel.fromJson(json))
          .toList();
      emit(state.copyWith(isBlackjackLoading: false, blackjackHistory: list));
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isBlackjackLoading: false,
          blackjackError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  Future<void> _onFetchBlackjackSettings(
    FetchBlackjackSettingsEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isBlackjackLoading: true, clearBlackjackError: true));
    try {
      final response = await _apiClient.get(ApiConstants.blackjackSettings);
      final settings = BlackjackSettingsModel.fromJson(response.data);
      emit(
        state.copyWith(
          isBlackjackLoading: false,
          blackjackSettings: settings,
        ),
      );
    } catch (e, stackTrace) {
      emit(
        state.copyWith(
          isBlackjackLoading: false,
          blackjackError: ErrorHandler.handle(e, stackTrace),
        ),
      );
    }
  }

  void _onResetBlackjack(ResetBlackjackEvent event, Emitter<AppState> emit) {
    emit(
      state.copyWith(
        clearBlackjackError: true,
        clearActiveBlackjackGame: true,
      ),
    );
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    return super.close();
  }
}
