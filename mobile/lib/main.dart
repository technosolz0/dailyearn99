import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:dailyearn99/features/auth/login_screen.dart';
import 'package:dailyearn99/features/home/home_screen.dart';
import 'package:dailyearn99/features/spin/spin_wheel_screen.dart';
import 'package:dailyearn99/features/wallet/wallet_screen.dart';
import 'package:dailyearn99/features/referral/referral_screen.dart';
import 'package:dailyearn99/features/profile/profile_screen.dart';
import 'package:dailyearn99/core/constants/app_constants.dart';
import 'package:dailyearn99/features/update/update_required_screen.dart';
import 'package:dailyearn99/features/splash/splash_screen.dart';
import 'package:safe_device/safe_device.dart';
import 'package:dailyearn99/firebase_options.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase on background message to handle background payloads
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DailyEarn99App());
}

class DailyEarn99App extends StatefulWidget {
  const DailyEarn99App({super.key});

  @override
  State<DailyEarn99App> createState() => _DailyEarn99AppState();
}

class _DailyEarn99AppState extends State<DailyEarn99App> {
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _performInitialization();
  }

  Future<void> _performInitialization() async {
    try {
      // 1. Initialize Firebase Core (must be first)
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Set up dependency injection container immediately (synchronous registration)
      setupDependencyInjection();

      // 3. Register notification listeners (non-blocking)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
        _setupForegroundNotificationListener();
      }

      // 4. Run secondary native channel check/config operations concurrently to optimize startup speed
      final results = await Future.wait([
        kIsWeb
            ? Future.value(false)
            : SafeDevice.isJailBroken.catchError((e) {
                print("Warning: SafeDevice check failed: $e");
                return false;
              }),
        kIsWeb
            ? Future.value(null)
            : FirebaseAppCheck.instance
                  .activate(
                    providerAndroid: kDebugMode
                        ? const AndroidDebugProvider()
                        : const AndroidPlayIntegrityProvider(),
                    providerApple: kDebugMode
                        ? const AppleDebugProvider()
                        : const AppleDeviceCheckProvider(),
                  )
                  .then((_) {
                    print("Firebase App Check: Activated successfully.");
                  })
                  .catchError((appCheckError) {
                    print(
                      "Firebase App Check Warning: Failed to activate: $appCheckError",
                    );
                  }),
        FirebaseAuth.instance
            .setSettings(appVerificationDisabledForTesting: false)
            .then((_) {
              print(
                "Firebase Auth: App verification settings set successfully.",
              );
            })
            .catchError((authSettingsError) {
              print(
                "Firebase Auth Warning: Failed to set auth settings: $authSettingsError",
              );
            }),
      ]);

      final bool isJailBroken = results[0] as bool;
      if (isJailBroken) {
        throw Exception(
          "Security Violation: Jailbroken or Rooted device detected.",
        );
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (errMsg.startsWith("Exception: ")) {
          errMsg = errMsg.substring("Exception: ".length);
        }
        setState(() {
          _error = errMsg;
        });
      }
    }
  }

  void _setupForegroundNotificationListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        scaffoldMessengerKey.currentState
          ?..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title ?? "Notification",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body ?? "",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: AppTheme.accentCyan.withOpacity(0.95),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        title: 'DailyEarn99',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: SplashScreen(
          error: _error,
          onRetry: () {
            setState(() {
              _error = null;
            });
            _performInitialization();
          },
        ),
      );
    }

    return BlocProvider<AppBloc>(
      create: (context) => AppBloc(getIt<ApiClient>())..add(AppStartedEvent()),
      child: BlocListener<AppBloc, AppState>(
        listenWhen: (previous, current) {
          return previous.token != null && current.token == null;
        },
        listener: (context, state) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
          );
        },
        child: MaterialApp(
          title: 'DailyEarn99',
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        if (state.updateRequired) {
          return UpdateRequiredScreen(
            updateUrl: state.updateUrl ?? '',
            currentVersion: AppConstants.currentAppVersion,
            requiredVersion: state.serverMinVersion ?? '1.0.0',
            isMandatory: true,
          );
        }
        if (state.isSplashLoading) {
          return const SplashScreen();
        }
        if (state.token != null && state.currentUser != null) {
          // Authenticated User
          return const MainNavigationLayout();
        }
        // Guest User
        return const LoginScreen();
      },
    );
  }
}

class MainNavigationLayout extends StatefulWidget {
  const MainNavigationLayout({super.key});

  @override
  State<MainNavigationLayout> createState() => _MainNavigationLayoutState();
}

class _MainNavigationLayoutState extends State<MainNavigationLayout> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Log initial screen view
    FirebaseAnalytics.instance.logScreenView(screenName: 'SpinWheelScreen');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppBloc>().state;
      if (state.updateOptional) {
        _showOptionalUpdateBottomSheet(
          context,
          state.updateUrl ?? '',
          state.serverLatestVersion ?? '',
        );
      }
    });
  }

  void _showOptionalUpdateBottomSheet(
    BuildContext context,
    String updateUrl,
    String latestVersion,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🎉 Update Available!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'A new version (v$latestVersion) of dailyearn99 is ready. Update now for new lobbies, faster spins, and updated security!',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      print(
                        "Redirecting user to Play Store/App Store update URL: $updateUrl",
                      );
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              'Navigating to update link:\n$updateUrl',
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: AppTheme.accentCyan,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('UPDATE NOW'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.borderCol),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'MAYBE LATER',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  final List<Widget> _screens = const [
    SpinWheelScreen(),
    HomeScreen(),
    WalletScreen(),
    ReferralScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.borderCol, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });

            // Log tab switch in Firebase Analytics
            final screenNames = [
              'SpinWheelScreen',
              'HomeScreen',
              'WalletScreen',
              'ReferralScreen',
              'ProfileScreen',
            ];
            FirebaseAnalytics.instance.logScreenView(
              screenName: screenNames[index],
            );

            // Fetch updates contextually on tab switch
            if (index == 0) {
              context.read<AppBloc>().add(FetchSpinHistoryEvent());
            } else if (index == 1) {
              context.read<AppBloc>().add(FetchContestsEvent());
              context.read<AppBloc>().add(LoadProfileEvent());
            } else if (index == 2) {
              context.read<AppBloc>().add(FetchTransactionsEvent());
            } else if (index == 3) {
              context.read<AppBloc>().add(FetchReferralDetailsEvent());
            } else if (index == 4) {
              context.read<AppBloc>().add(LoadProfileEvent());
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.darkBg,
          selectedItemColor: AppTheme.accentCyan,
          unselectedItemColor: AppTheme.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.casino_outlined),
              activeIcon: Icon(Icons.casino),
              label: 'Spin Wheel',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_esports_outlined),
              activeIcon: Icon(Icons.sports_esports),
              label: 'Lobbies',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Wallet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.card_giftcard_outlined),
              activeIcon: Icon(Icons.card_giftcard),
              label: 'Refer & Earn',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
