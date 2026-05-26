import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:target99/core/theme/app_theme.dart';
import 'package:target99/core/utils/dependency_injection.dart';
import 'package:target99/core/network/api_client.dart';
import 'package:target99/features/app_bloc.dart';
import 'package:target99/features/auth/login_screen.dart';
import 'package:target99/features/home/home_screen.dart';
import 'package:target99/features/wallet/wallet_screen.dart';
import 'package:target99/features/referral/referral_screen.dart';
import 'package:target99/features/profile/profile_screen.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase on background message to handle background payloads
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase Core
  await Firebase.initializeApp();

  // Set background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Set up dependency injection container
  setupDependencyInjection();

  // Listen for foreground push notifications
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
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

  runApp(const Target99App());
}

class Target99App extends StatelessWidget {
  const Target99App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppBloc>(
      create: (context) => AppBloc(getIt<ApiClient>())..add(AppStartedEvent()),
      child: MaterialApp(
        title: 'target99',
        scaffoldMessengerKey: scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        navigatorObservers: [
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
        ],
        home: const AuthWrapper(),
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
        if (state.isAuthLoading && state.currentUser == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            ),
          );
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
    FirebaseAnalytics.instance.logScreenView(screenName: 'HomeScreen');
  }

  final List<Widget> _screens = const [
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
            final screenNames = ['HomeScreen', 'WalletScreen', 'ReferralScreen', 'ProfileScreen'];
            FirebaseAnalytics.instance.logScreenView(screenName: screenNames[index]);

            // Fetch updates contextually on tab switch
            if (index == 1) {
              context.read<AppBloc>().add(FetchTransactionsEvent());
            } else if (index == 2) {
              context.read<AppBloc>().add(FetchReferralDetailsEvent());
            } else if (index == 3) {
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
