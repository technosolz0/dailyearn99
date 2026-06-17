import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/services/notification_service.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthSuccess extends AuthState {
  final String token;
  AuthSuccess(this.token);
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
class AuthLoggedOut extends AuthState {}

class AuthCubit extends Cubit<AuthState> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  final NotificationService _notificationService = GetIt.instance<NotificationService>();

  AuthCubit() : super(AuthInitial());

  Future<void> checkSession() async {
    final token = await _apiClient.getToken();
    if (token != null) {
      // Subscribe to admin notifications topic
      await _notificationService.subscribeToAdminTopic();
      
      // Auto-sync FCM token if needed
      await _registerFcmTokenIfNeeded();
      
      emit(AuthSuccess(token));
    } else {
      // Try to auto-login with stored credentials
      final username = await _apiClient.getUsername();
      final password = await _apiClient.getPassword();
      if (username != null && password != null) {
        developer.log('Attempting automatic credential login...');
        try {
          await login(username, password, '', isAutoLogin: true);
          return;
        } catch (e) {
          developer.log('Auto-login failed: $e');
        }
      }
      emit(AuthLoggedOut());
    }
  }

  Future<void> login(String username, String password, String customUrl, {bool isAutoLogin = false}) async {
    if (!isAutoLogin) emit(AuthLoading());
    try {
      // Save base URL first before testing login (skip if auto-logging in)
      if (customUrl.isNotEmpty) {
        String formattedUrl = customUrl.trim();
        if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
          formattedUrl = 'http://$formattedUrl';
        }
        if (formattedUrl.endsWith('/')) {
          formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
        }
        await _apiClient.setBaseUrl(formattedUrl);
      }

      final response = await _apiClient.dio.post(
        '/admin/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      final token = response.data['access_token'] as String;
      await _apiClient.setToken(token);
      
      // Save credentials for subsequent auto-logins
      await _apiClient.setUsername(username);
      await _apiClient.setPassword(password);
      
      // Subscribe to admin notifications topic
      await _notificationService.subscribeToAdminTopic();
      
      // Force sync FCM token on login success
      await _registerFcmTokenIfNeeded(force: true);
      
      emit(AuthSuccess(token));
    } on DioException catch (e) {
      String errMsg = 'An unexpected error occurred';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      } else {
        errMsg = e.message ?? errMsg;
      }
      if (!isAutoLogin) emit(AuthError(errMsg));
      if (isAutoLogin) rethrow;
    } catch (e) {
      if (!isAutoLogin) emit(AuthError(e.toString()));
      if (isAutoLogin) rethrow;
    }
  }

  Future<void> logout() async {
    emit(AuthLoading());
    
    // Unsubscribe from topic
    await _notificationService.unsubscribeFromAdminTopic();
    
    // Clear session & credentials from secure storage
    await _apiClient.clearSession();
    
    emit(AuthLoggedOut());
  }

  Future<void> _registerFcmTokenIfNeeded({bool force = false}) async {
    try {
      final fcmToken = _notificationService.fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        developer.log('Unable to sync FCM token to backend (token is null).');
        return;
      }

      final savedToken = await _apiClient.getSavedFcmToken();
      final lastUpdateStr = await _apiClient.getFcmLastUpdate();
      
      bool needUpdate = force;
      if (!needUpdate) {
        if (savedToken != fcmToken) {
          needUpdate = true;
        } else if (lastUpdateStr == null) {
          needUpdate = true;
        } else {
          final lastUpdate = DateTime.tryParse(lastUpdateStr);
          if (lastUpdate == null || DateTime.now().difference(lastUpdate).inDays >= 4) {
            needUpdate = true;
          }
        }
      }

      if (needUpdate) {
        await _apiClient.dio.post(
          '/admin/fcm-token',
          data: {
            'fcm_token': fcmToken,
          },
        );
        await _apiClient.setSavedFcmToken(fcmToken);
        await _apiClient.setFcmLastUpdate(DateTime.now().toIso8601String());
        developer.log('Admin FCM token successfully synced to backend database.');
      }
    } catch (e) {
      developer.log('Failed to register/sync FCM token to backend: $e');
    }
  }
}
