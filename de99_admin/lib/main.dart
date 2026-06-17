import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/services/notification_service.dart';
import 'package:de99_admin/features/auth/bloc/auth_cubit.dart';
import 'package:de99_admin/features/auth/views/login_view.dart';
import 'package:de99_admin/features/dashboard/bloc/stats_cubit.dart';
import 'package:de99_admin/features/dashboard/views/dashboard_view.dart';
import 'package:de99_admin/features/users/bloc/users_cubit.dart';
import 'package:de99_admin/features/requests/bloc/requests_cubit.dart';
import 'package:de99_admin/features/contests/bloc/contests_cubit.dart';
import 'package:de99_admin/features/notifications/bloc/notifications_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register singletons in GetIt for dependency injection
  final getIt = GetIt.instance;
  getIt.registerSingleton<ApiClient>(ApiClient());
  getIt.registerSingleton<NotificationService>(NotificationService());

  // Initialize Firebase and background messaging subscriptions
  await getIt<NotificationService>().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (context) => AuthCubit()..checkSession(),
        ),
        BlocProvider<StatsCubit>(
          create: (context) => StatsCubit(),
        ),
        BlocProvider<UsersCubit>(
          create: (context) => UsersCubit(),
        ),
        BlocProvider<RequestsCubit>(
          create: (context) => RequestsCubit(),
        ),
        BlocProvider<ContestsCubit>(
          create: (context) => ContestsCubit(),
        ),
        BlocProvider<NotificationsCubit>(
          create: (context) => NotificationsCubit(),
        ),
      ],
      child: MaterialApp(
        title: 'DE99 Admin Console',
        theme: AdminTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const SessionGateway(),
      ),
    );
  }
}

class SessionGateway extends StatelessWidget {
  const SessionGateway({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthSuccess) {
          return const DashboardView();
        } else if (state is AuthLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AdminTheme.primary),
              ),
            ),
          );
        }
        return const LoginView();
      },
    );
  }
}
