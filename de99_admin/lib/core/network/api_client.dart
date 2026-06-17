import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  static const String _defaultLocalAndroidUrl = 'http://10.0.2.2:9900/api';
  static const String _defaultLocalIosUrl = 'http://localhost:9900/api';
  
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
        onError: (DioException e, handler) {
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
    // Fallbacks
    if (Platform.isAndroid) {
      return _defaultLocalAndroidUrl;
    }
    return _defaultLocalIosUrl;
  }

  Future<void> setBaseUrl(String url) async {
    await _storage.write(key: _baseUrlKey, value: url);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
  }
}
