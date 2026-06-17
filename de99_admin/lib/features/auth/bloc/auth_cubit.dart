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
      emit(AuthSuccess(token));
    } else {
      emit(AuthLoggedOut());
    }
  }

  Future<void> login(String username, String password, String customUrl) async {
    emit(AuthLoading());
    try {
      // Save base URL first before testing login
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
      
      // Subscribe to admin notifications topic
      await _notificationService.subscribeToAdminTopic();
      
      emit(AuthSuccess(token));
    } on DioException catch (e) {
      String errMsg = 'An unexpected error occurred';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      } else {
        errMsg = e.message ?? errMsg;
      }
      emit(AuthError(errMsg));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> logout() async {
    emit(AuthLoading());
    await _apiClient.clearSession();
    
    // Unsubscribe from topic
    await _notificationService.unsubscribeFromAdminTopic();
    
    emit(AuthLoggedOut());
  }
}
