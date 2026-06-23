import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _baseUrlKey = 'admin_api_base_url';
  static const String _tokenKey = 'admin_auth_token';

  ApiClient() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Dynamically fetch and set Base URL
          final baseUrl = await getBaseUrl();
          options.baseUrl = baseUrl;

          // Attach auth token if available
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401 &&
              e.requestOptions.path != '/admin/login') {
            final username = await getUsername();
            final password = await getPassword();
            if (username != null && password != null) {
              try {
                // Spawn a clean temporary Dio instance to avoid interceptor recursion
                final dioForLogin = Dio();
                final baseUrl = await getBaseUrl();
                final loginResponse = await dioForLogin.post(
                  '$baseUrl/admin/login',
                  data: {'username': username, 'password': password},
                );

                final newToken = loginResponse.data['access_token'] as String;
                await setToken(newToken);

                // Clone the original request options and set the new auth header
                final options = e.requestOptions;
                options.headers['Authorization'] = 'Bearer $newToken';

                // Retry the request
                final cloneReq = await _dio.fetch(options);
                return handler.resolve(cloneReq);
              } catch (retryError) {
                // If silent authentication fails, forward the original error
                return handler.next(e);
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<String> getBaseUrl() async {
    final customUrl = await _storage.read(key: _baseUrlKey);
    if (customUrl != null && customUrl.isNotEmpty) {
      return customUrl;
    }
    return 'https://api.dailyearn99.in/api';
  }

  Future<void> setBaseUrl(String url) async {
    await _storage.write(key: _baseUrlKey, value: url);
  }

  static const String _usernameKey = 'admin_username';
  static const String _passwordKey = 'admin_password';
  static const String _fcmLastUpdateKey = 'admin_fcm_token_last_update';
  static const String _savedFcmTokenKey = 'admin_saved_fcm_token';

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  Future<void> setUsername(String username) async {
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<String?> getPassword() async {
    return await _storage.read(key: _passwordKey);
  }

  Future<void> setPassword(String password) async {
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<String?> getFcmLastUpdate() async {
    return await _storage.read(key: _fcmLastUpdateKey);
  }

  Future<void> setFcmLastUpdate(String timestamp) async {
    await _storage.write(key: _fcmLastUpdateKey, value: timestamp);
  }

  Future<String?> getSavedFcmToken() async {
    return await _storage.read(key: _savedFcmTokenKey);
  }

  Future<void> setSavedFcmToken(String token) async {
    await _storage.write(key: _savedFcmTokenKey, value: token);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _fcmLastUpdateKey);
    await _storage.delete(key: _savedFcmTokenKey);
  }
}
